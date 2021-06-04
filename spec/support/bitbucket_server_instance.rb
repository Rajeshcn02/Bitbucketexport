# frozen_string_literal: true

module Helpers
  def bitbucket_server
    return @bitbucket_server if @bitbucket_server

    options = {
      base_url: ENV.fetch("BITBUCKET_SERVER_URL", "https://example.com")
    }

    if ENV.key?("BITBUCKET_SERVER_API_TOKEN")
      options[:token] = ENV["BITBUCKET_SERVER_API_TOKEN"]
    else
      options.merge!(
        user:     ENV.fetch("BITBUCKET_SERVER_API_USERNAME", "unit-test"),
        password: ENV.fetch("BITBUCKET_SERVER_API_PASSWORD", "examplepassword")
      )
    end

    @bitbucket_server = BitbucketServer.new(**options)
  end

  def current_export
    @exporter ||= BbsExporter.new(
      bitbucket_server: bitbucket_server,
      options:          { progress_bar: false }
    )
  end
end
