# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env.test")

ENV["BITBUCKET_SERVER_EXPORTER_ENV"] = "test"

require "fileutils"
require "bbs_exporter"
require "rspec"
require "vcr"
require "webmock/rspec"
require "addressable"
require "pry"
require "base64"
require "timecop"
require "open3"

# Require support files

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

include RequestMatcherHelpers

VCR.configure do |config|
  config.configure_rspec_metadata!

  config.default_cassette_options = {
    match_requests_on:      [:method, :uri],
    allow_playback_repeats: true
  }

  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock

  # Filter out the user's password
  config.filter_sensitive_data("<API_BASIC_AUTH>") do |interaction|
    interaction.request.headers["Authorization"].first
  end

  # Filter remaining URLs that match the host.
  config.filter_sensitive_data("example.com") do |interaction|
    Addressable::URI.parse(interaction.request.uri).host
  end

  # Filter URLs that match the origin.
  config.filter_sensitive_data("https://example.com") do |interaction|
    Addressable::URI.parse(interaction.request.uri).origin
  end

  # Only match requests by the URI and params.
  request_uri_matcher = lambda do |real, cassette|
    path_query_fragment(real.uri) == path_query_fragment(cassette.uri)
  end

  config.default_cassette_options[:match_requests_on] = [request_uri_matcher]
end

RSpec.configure do |config|
  config.include TimeHelpers, :time_helpers
  config.include PullRequestHelpers, :pull_request_helpers
  config.include CommitCommentHelpers, :commit_comment_helpers
  config.include ArchiveHelpers, :archive_helpers

  config.before(:each) do
    @_spec_log = StringIO.new
    @_spec_logger = Logger.new(@_spec_log)
    allow_any_instance_of(BbsExporter::Logging).to(
      receive(:logger).and_return(@_spec_logger)
    )

    @_spec_output_log = StringIO.new
    @_spec_output_logger = Logger.new(@_spec_output_log)
    allow_any_instance_of(BbsExporter::Logging).to(
      receive(:output_logger).and_return(@_spec_output_logger)
    )

    # We don't need to close this log in testing
    allow(@_spec_output_logger).to receive(:close)
  end

  config.after(:each) do
    cache_path = bitbucket_server.connection.http_cache_path

    if File.exist?(cache_path)
      FileUtils.remove_entry_secure(cache_path)
    end
  end

  config.include Helpers
end
