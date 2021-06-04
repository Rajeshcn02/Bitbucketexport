# frozen_string_literal: true

require "active_model"
require "active_support/cache"
require "active_support/cache/file_store"
require "excon"
require "faraday"
require "faraday_middleware"
require "faraday-http-cache"
require "faraday/cache_headers"
require "fileutils"
require "bitbucket_server"
require "bitbucket_server/connection"
require "open-uri"
require "tmpdir"
require "csv"
require "climate_control"
require "posix-spawn"
require "rugged"
require "ssh-fingerprint"
require "git"
require "addressable"
require "mime/types"
require "active_support/core_ext/object/blank"
require "ruby-progressbar"
require "terminfo"
require "colorize"
require "zlib"
require "bbs_exporter/logging"
require "bbs_exporter/git"
require "bbs_exporter/logging/progress_bar_io"
require "rubygems/package"
require "bbs_exporter/errors"
require "bbs_exporter/archiver"
require "bbs_exporter/time_helpers"
require "bbs_exporter/pull_request_helpers"
require "bbs_exporter/diff_hunk_positioner"
require "bbs_exporter/diff_hunk_positioner/hunk"
require "bbs_exporter/diff_hunk_generator"
require "bbs_exporter/safe_transaction"
require "bbs_exporter/archive_builder"
require "bbs_exporter/base_serializer"
require "bbs_exporter/attachment_serializer"
require "bbs_exporter/collaborator_serializer"
require "bbs_exporter/organization_serializer"
require "bbs_exporter/user_serializer"
require "bbs_exporter/pull_request_serializer"
require "bbs_exporter/pull_request_review_serializer"
require "bbs_exporter/pull_request_review_comment_serializer"
require "bbs_exporter/pull_request_comment_serializer"
require "bbs_exporter/member_serializer"
require "bbs_exporter/repository_serializer"
require "bbs_exporter/team_serializer"
require "bbs_exporter/release_serializer"
require "bbs_exporter/protected_branch_serializer"
require "bbs_exporter/commit_comment_serializer"
require "bbs_exporter/issue_event_serializer"
require "bbs_exporter/writable"
require "bbs_exporter/storable"
require "bbs_exporter/model_url_service"
require "bbs_exporter/serialized_model_writer"
require "bbs_exporter/repository_exporter"
require "bbs_exporter/url_templates"
require "bbs_exporter/team_builder"
require "bbs_exporter/attachment_exporter"
require "bbs_exporter/attachment_exporter/attachment"
require "bbs_exporter/attachment_exporter/content_type"
require "bbs_exporter/pull_request_exporter"
require "bbs_exporter/pull_request_review_exporter"
require "bbs_exporter/pull_request_review_comment_exporter"
require "bbs_exporter/branch_permissions_exporter"
require "bbs_exporter/pull_request_comment_exporter"
require "bbs_exporter/commit_comment_exporter"
require "bbs_exporter/issue_event_exporter"
require "bbs_exporter/commit_comment/base"
require "bbs_exporter/commit_comment/line"
require "bbs_exporter/commit_comment/file"
require "bbs_exporter/diff_item"
require "forwardable"
require "logger"

class BbsExporter
  include Logging
  include SafeExecution

  log_handled_exceptions_to :logger

  attr_accessor :bitbucket_server, :options
  delegate :connection, to: :bitbucket_server

  OPTIONAL_MODELS = %w(
    commit_comments
    pull_requests
    teams
  )
  MINIMUM_VERSION = "5.0.0"
  RESCUED_EXCEPTIONS = [
    ActiveModel::ValidationError,
    BadVersion,
    Faraday::ClientError,
    Faraday::ResourceNotFound
  ]

  def initialize(bitbucket_server:, options: {})
    @bitbucket_server = bitbucket_server
    @options = options

    connection.around_request = proc do |faraday_method, url, &request|
      progress = "#{faraday_method.upcase} #{url}"
      progress_bar_title(progress) { request.call }
    end

    String.disable_colorization = !options.fetch(:color, STDOUT.tty?)
    progress_bar_disable! if options[:progress_bar] == false

    output_logger.info "Creating working directory in #{staging_dir}"

    # Clear cache on exit
    do_at_exit(output_logger, bitbucket_server)
  end

  # Begins the export process for a single repository or a manifest of
  # repositories.
  def export
    report_exporter_version
    check_version!

    repo_paths = repo_paths_from_options(options)
    export_repositories(repo_paths)

    team_builder.write! if models_to_export.include?("teams")
    raise "Nothing was exported!" unless archiver.used?
    archiver.create_tar(options[:output_path])
  rescue *RESCUED_EXCEPTIONS => exception
    output_logger.error(exception.message)

    backtrace = exception.backtrace.join("\n")
    output_logger.error("Backtrace:\n#{backtrace}")

    return false
  end

  def models_to_export
    options[:models].to_a
  end

  def archiver
    @archiver ||= ArchiveBuilder.new(current_export: self)
  end

  def team_builder
    @team_builder ||= TeamBuilder.new(current_export: self)
  end

  # Determines the path on disk for bbs-exporter
  #
  # @param [String] rel_path relative path to be appended to the repository path
  # @return [String] If rel_path is provided, it will return the repository path
  #   with rel_path appended. Otherwise, returns the repository path
  def self.path(rel_path = nil)
    repository_path = File.expand_path("../../", __FILE__)
    if rel_path
      File.join(repository_path, rel_path)
    else
      repository_path
    end
  end

  # Determines if the library is being run in a test environment
  #
  # @return [Boolean]
  def self.test?
    ENV["BITBUCKET_SERVER_EXPORTER_ENV"] == "test"
  end

  # A tmpdir where the archive's contents are staged
  def staging_dir
    @staging_dir ||= Dir.mktmpdir "bbs-exporter"
  end

  def logs_dir
    @logs_dir ||= FileUtils.mkdir_p(File.join(staging_dir, "log/")).first
  end

  # Checks if the BitbucketServer instance has a version greater than MINIMUM_VERSION. It
  # will raise an error if it does not
  def check_version!
    api_version = bitbucket_server.version
    version = api_version["version"]

    output_logger.info("Bitbucket Server version is #{version}.")

    if Gem::Version.new(version) < Gem::Version.new(MINIMUM_VERSION)
      if options[:ignore_version_check]
        output_logger.warn(
          "Ignoring unsupported server version #{version} (minimum supported" \
          " version is #{MINIMUM_VERSION})!"
        )
      else
        raise BbsExporter::BadVersion.new(version)
      end
    end
  end

  def report_exporter_version
    output_logger.info(
      "Bitbucket Server Exporter version is #{BbsExporter::VERSION}."
    )
  end

  private

  def repo_paths_from_repository_options(repository_options)
    repository_options.map { |p| p.split("/") }
  end

  def repo_paths_from_file(file_path)
    CSV.read(file_path)
  end

  def repo_paths_from_options(options)
    Set.new.tap do |repo_paths|
      repo_paths.merge(
        repo_paths_from_repository_options(options[:repositories])
      ) if options.key?(:repositories)

      repo_paths.merge(
        repo_paths_from_file(options[:manifest])
      ) if options.key?(:manifest)
    end
  end

  def repository_model(project_key, repository_slug)
    project = bitbucket_server.project_model(project_key)
    project.repository_model(repository_slug)
  end

  def repository_exists?(repository_model)
    repository_model.repository
    true
  rescue Faraday::ResourceNotFound => exception
    output_logger.error(exception.message)
    output_logger.error(
      "Unable to export repository #{repository_model.project_and_repo}"
    )

    false
  end

  def export_repository(repository_model)
    repository_exporter = RepositoryExporter.new(
      repository_model,
      current_export: self
    )

    repository_exporter.export
  end

  def export_repositories(repo_paths)
    [].tap do |exported_repositories|
      repo_paths.each do |repo_path|
        repository = repository_model(*repo_path)

        if repository_exists?(repository)
          export_repository(repository)
          exported_repositories << repository
        end
      end
    end
  end

  def do_at_exit(output_logger, bitbucket_server)
    at_exit do
      output_logger.info("Cleaning up HTTP cache...")
      bitbucket_server.clear_cache
      output_logger.close
    end
  end
end
