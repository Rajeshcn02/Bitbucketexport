# frozen_string_literal: true

module TimeHelpers
  def current_time
    Time.now.utc.iso8601
  end

  # Bitbucket Server returns timestamps with milliseconds since epoch.
  # @param [Integer] timestamp timestamp in epoch milliseconds
  def format_long_timestamp(timestamp)
    Time.at(timestamp/1000).utc.iso8601
  end
end
