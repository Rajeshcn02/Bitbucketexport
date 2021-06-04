# frozen_string_literal: true

class BitbucketServer
  class Model
    attr_reader :path, :connection

    private

    def request(
      http_method, *additional_paths, base_path: path, query: nil, **keywords
    )
      full_path = File.join(base_path, *additional_paths)
      keywords[:query] = query.compact if query_present?(query)
      connection.send(http_method, full_path, **keywords)
    end

    def get(*additional_paths, base_path: path, query: nil, **keywords)
      request(
        :get, *additional_paths, base_path: base_path, query: query, **keywords
      )
    end

    def head(*additional_paths, base_path: path, query: nil, **keywords)
      request(
        :head, *additional_paths, base_path: base_path, query: query, **keywords
      )
    end

    def query_present?(query)
      query.to_h.compact.present?
    end
  end
end
