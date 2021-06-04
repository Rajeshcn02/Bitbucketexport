# frozen_string_literal: true

module RequestMatcherHelpers
  def path_query_fragment(uri)
    uri = URI(uri)
    [uri.request_uri, uri.fragment].compact.join("#")
  end
end
