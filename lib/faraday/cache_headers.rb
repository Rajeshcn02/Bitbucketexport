# frozen_string_literal: true

module Faraday
  class CacheHeaders < Faraday::Response::Middleware
    # A little hack middleware to manually set cache headers. Bitbucket Server
    # by default does not allow caching of its API.
    def on_complete(env)
      env.response_headers["cache-control"] = "max-age=3600, public"
    end
  end
end
