# frozen_string_literal: true

class BbsExporter
  module TimeHelpers
    # Bitbucket Server does not include created_at info on their models so we will
    # fake it with this method
    def generate_created_at
      Time.now.utc.iso8601
    end

    # Bitbucket Server returns timestamps with milliseconds since epoch.
    # @param [Integer] timestamp timestamp in epoch milliseconds
    def format_long_timestamp(timestamp)
      Time.at(timestamp/1000).utc.iso8601
    end
  end
end
