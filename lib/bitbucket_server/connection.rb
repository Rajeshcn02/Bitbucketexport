# frozen_string_literal: true

class BitbucketServer
  class Connection
    class InvalidBaseUrl < StandardError; end

    attr_reader :base_url, :user, :password, :token, :read_timeout,
      :open_timeout, :retries, :ssl_verify

    attr_accessor :around_request

    def initialize(
      base_url:, user: nil, password: nil, token: nil, read_timeout: nil,
      open_timeout: nil, retries: nil, ssl_verify: nil, around_request: nil
    )
      @base_url = base_url

      @user = user
      @password = password
      @token = token

      @read_timeout = read_timeout
      @open_timeout = open_timeout
      @retries = retries
      @ssl_verify = ssl_verify

      @around_request = around_request || proc { |&r| r.call }

      validate_base_url!
    end

    # Sanitizes creds on .inspect
    def inspect
      inspected = super

      inspected.gsub! @password, "*******" if @password
      inspected.gsub! @token, "*******" if @token

      inspected
    end

    def base_url_valid?
      @base_url =~ URI::regexp(%w(http https))
    end

    def validate_base_url!
      unless base_url_valid?
        raise(InvalidBaseUrl, "#{base_url} is not a valid URL!")
      end
    end

    def basic_authenticated?
      !!(user && password)
    end

    def token_authenticated?
      !!token
    end

    # The path to the http cache on disk.
    #
    # @return [String]
    def http_cache_path
      Dir.mktmpdir("bbs_exporter_http_cache")
    end

    # Faraday's cache store.
    #
    # @return [ActiveSupport::Cache::FileStore]
    def http_cache
      @http_cache ||= ActiveSupport::Cache::FileStore.new(http_cache_path)
    end

    # The Faraday object for making requests to Bitbucket Server API
    #
    # @return [Faraday::Connection]
    def faraday
      @faraday ||= Faraday.new ssl: { verify: ssl_verify } do |faraday|
        authenticate!(faraday)

        faraday.request(:retry, max: retries) if retries
        faraday.options.timeout = read_timeout if read_timeout
        faraday.options.open_timeout = open_timeout if open_timeout

        faraday.request  :url_encoded  # Form-encode POST params
        faraday.response :raise_error
        faraday.use      :http_cache, store: http_cache, serializer: Marshal
        faraday.use      Faraday::CacheHeaders
        faraday.response :json, content_type: /\bjson$/
        faraday.adapter  :excon
      end
    end

    def encode_url(path: [], query: nil, api_v1: true)
      path = path.flatten.map { |p| Addressable::URI.encode(p) }

      path = File.join("rest", "api", "1.0", path) if api_v1
      url = File.join(base_url, path)
      uri = URI(url)
      uri.query = query.to_param

      uri.to_s
    end

    # A wrapper for calling `faraday` that includes better errors in
    # exceptions.
    #
    # @param [String] url URL to make GET request for.
    # @return [Faraday::Response] Response data.
    def faraday_safe(faraday_method, url)
      around_request.call(faraday_method, url) do
        faraday.send(faraday_method, url)
      end
    rescue Faraday::ConnectionFailed => exception
      raise($!, exception.message)
    rescue Faraday::TimeoutError => exception
      timeout_error_with_message(exception, url)
    rescue Faraday::ClientError => exception
      client_error_with_message(exception, url)
    end

    # Get a single record or not paginated collection of records.
    #
    # @param [Array<String>] path The URL path to send the GET request to.
    # @option query Hash Optionally include query parameters with the request.
    # @option api_v1 true Prefix `path` with "api/1.0".
    # @option api_v1 false Do not prefix `path` with "api/1.0".
    # @return [Array,Hash] The response body.
    def get_one(*path, query: nil, api_v1: true)
      url = encode_url(path: path, query: query, api_v1: api_v1)
      faraday_safe(:get, url).body
    end

    # Fetch records and auto paginate using Bitbucket Server's documented API
    # pagination.
    #
    # @param [Array<String>] path The URL path to send the GET request to.
    # @option query Hash Optionally include query parameters with the request.
    # @option api_v1 true Prefix `path` with "api/1.0".
    # @option api_v1 false Do not prefix `path` with "api/1.0".
    # @return [Array] Aggregated data from paginated responses.
    def get_all(*path, query: nil, api_v1: true)
      query = {} if query.nil?
      query[:limit] = 250
      body = {}

      [].tap do |body_values|
        until body["isLastPage"] == true do
          url = encode_url(
            path:   path,
            query:  query,
            api_v1: api_v1
          )

          body = faraday_safe(:get, url).body
          body_values.concat(body["values"])

          query[:start] = body["nextPageStart"]
        end
      end
    end

    # Make a GET request to Bitbucket Server's API.
    #
    # @param [Array<String>] path The URL path to send the GET request to.
    # @option auto_paginate true Aggregate paginated results.
    # @option auto_paginate false Do not paginate results.
    # @option query Hash Optionally include query parameters with the request.
    # @option api_v1 true Prefix `path` with "api/1.0".
    # @option api_v1 false Do not prefix `path` with "api/1.0".
    # @return The response body.
    def get(*path, auto_paginate: false, query: nil, api_v1: true)
      get_method = auto_paginate ? :get_all : :get_one
      send(get_method, path, query: query, api_v1: api_v1)
    end

    def head(*path, query: nil, api_v1: true)
      url = encode_url(path: path, query: query, api_v1: api_v1)
      faraday_safe(:head, url)
    end

    private

    def authenticate!(faraday)
      if token_authenticated?
        faraday.authorization(:Bearer, token)
      elsif basic_authenticated?
        faraday.basic_auth(user, password)
      else
        raise MissingCredentialsError
      end
    end

    def client_error_with_message(exception, url)
      raise($!) if exception.is_a?(Faraday::SSLError)

      message = bbs_error_message(exception, url)
      raise(exception, message)
    end

    def bbs_error_message(exception, url)
      response = exception.response
      message = "#{response[:status]} on GET to #{url}"

      if response[:body].is_a?(Hash) && response[:body].key?("errors")
        errors = response[:body]["errors"].map { |e| e["message"] }.join(" ")
        message += ": #{errors}"
      end

      message
    end

    def timeout_error_with_message(exception, url)
      if retries
        message = "Timed out #{retries} times during GETs to #{url}"
      else
        message = "Timed out during GET to #{url}"
      end

      raise(exception, message)
    end

    class MissingCredentialsError < StandardError
      def message
        "Must define `BITBUCKET_SERVER_API_TOKEN` or `BITBUCKET_SERVER_API_USERNAME` AND `BITBUCKET_SERVER_API_PASSWORD`"
      end
    end
  end
end
