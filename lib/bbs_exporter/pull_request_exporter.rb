# frozen_string_literal: true

class BbsExporter
  class PullRequestExporter
    include Writable
    include SafeExecution
    include TimeHelpers
    include PullRequestHelpers

    log_handled_exceptions_to :logger

    attr_reader :pull_request, :repository_exporter, :archiver,
      :pull_request_model, :project

    delegate :repository_model, to: :pull_request_model

    def initialize(pull_request_model, repository_exporter:, project:)
      @pull_request_model = pull_request_model
      @repository_exporter = repository_exporter
      @project = project
      @archiver = current_export.archiver
      @pull_request = pull_request_model.pull_request.merge(
        "repository" => repository,
        "owner"      => project,
        "commits"    => pull_request_model.commits,
        "repo_path"  => archiver.repo_path(repository)
      )
    end

    # Alias for `pull_request`
    #
    # @return [Hash]
    def model
      pull_request
    end

    # References the repository for the export
    #
    # @return [Hash]
    def repository
      repository_exporter.repository
    end

    # References the current export
    #
    # @return [BbsExporter]
    def current_export
      repository_exporter.current_export
    end

    # References the BitbucketServer instance
    #
    # @return [BitbucketServer]
    def bitbucket_server
      current_export.bitbucket_server
    end

    def logger
      current_export.logger
    end

    def created_date
      pull_request["createdDate"]
    end

    def author
      pull_request["author"]["user"]
    end

    def description
      pull_request["description"].to_s
    end

    def attachment_exporter
      @attachment_exporter ||= AttachmentExporter.new(
        current_export:   current_export,
        repository_model: repository_model,
        parent_type:      "pull_request",
        parent_model:     pull_request,
        user:             author,
        body:             description,
        created_date:     created_date
      )
    end

    # Instruct the exporter to export the `pull_request`. Also extracts any
    # inline attachments from the `pull_request`'s body content.
    #
    # @return [Boolean] whether or not the pull_request successfully exported
    def export
      serialize("user", author) if author

      attachment_exporter.export
      description.replace(attachment_exporter.rewritten_body)

      serialize("pull_request", pull_request)

      export_pull_request_comments
      export_pull_request_review_groups
      export_pull_request_review_comments
      export_pull_request_reviews
      export_issue_events

      true
    rescue StandardError => e
      current_export.logger.error <<~EOF
        Error while exporting Pull Request (#{e.message}):
        #{pull_request.inspect}
        #{e.backtrace.join("\n")}
      EOF

      current_export.output_logger.error(
        "Unable to export Pull Request #{pull_request["id"]} from repository " +
        model_url_service.url_for_model(repository)
      )

      false
    end

    def comment_activities
      pull_request_model.activities.select { |a| comment?(a) }
    end

    # Get PR activities for diff comments (including file comments).
    #
    # @return [Array<Hash>] Pull request activities for diff comments
    #   (including file comments).
    def diff_comment_activities
      pull_request_model.activities.select do |activity|
        diff_comment?(activity) || file_comment?(activity)
      end
    end

    # Get PR activities for issue events.
    #
    # @return [Array<Hash>] Pull request activities for issue events.
    def issue_event_activities
      pull_request_model.activities.select { |a| issue_event?(a) }
    end

    # Get the first PR activity for diff comments grouped by user slug and
    # commit ID.
    #
    # @return [Array] Commit ID and first PR activity.
    def grouped_diff_comment_activities
      grouped_activities = diff_comment_activities.group_by do |activity|
        user_slug = activity.dig("user", "slug")
        commit_id = commit_id_from_activity(activity)

        [user_slug, commit_id]
      end

      grouped_activities.map do |user_slug_commit_id, activities|
        user_slug, commit_id = user_slug_commit_id
        first_activity = activities.min { |a| a["createdDate"] }

        [commit_id, first_activity]
      end
    end

    def review_activities
      pull_request_model.activities.select { |a| reviewed?(a) }
    end

    # Returns a hash of commit sha1s sorted by timestamp
    #
    # @return [Hash{Integer => String}]
    def timestamped_commit_ids
      @timestamped_commit_ids ||= begin
        timestamped_commits = pull_request_model.commits.map do |commit|
          [commit["authorTimestamp"], commit["id"]]
        end
        sorted_desc_timestamped_commits = timestamped_commits.sort.reverse
        sorted_desc_timestamped_commits.to_h
      end
    end

    # Searches #timestamped_commit_ids for a timestamp that immediately precedes the
    # provided activity_timestamp and returns the associated commit sha1
    #
    # @param [Integer] activity_timestamp the timestamp to search by
    #
    # @return [String, nil] the returned sha1 or nil if none is found
    def commit_id_for_timestamp(activity_timestamp)
      timestamped_commit_ids.detect do |timestamp, commit_id|
        activity_timestamp >= timestamp
      end&.last
    end

    # Export pull request comments.
    def export_pull_request_comments
      comment_activities.each do |comment_activity|
        PullRequestCommentExporter.new(
          pull_request_comment: comment_activity["comment"],
          pull_request:         pull_request,
          repository_exporter:  repository_exporter
        ).export
      end
    end

    # Export pull request review groups for review comments.
    def export_pull_request_review_groups
      grouped_diff_comment_activities.each do |commit_id, activity|
        PullRequestReviewExporter.new(
          repository_exporter: repository_exporter,
          pull_request_model:  pull_request_model,
          commit_id:           commit_id,
          activity:            activity
        ).export
      end
    end

    # Export pull request review comments.
    def export_pull_request_review_comments
      diff_comment_activities.each do |activity|
        PullRequestReviewCommentExporter.new(
          repository_exporter: repository_exporter,
          pull_request_model:  pull_request_model,
          activity:            activity
        ).export
      end
    end

    # Export pull request reviews.
    def export_pull_request_reviews
      review_activities.each do |activity|
        commit_id = commit_id_for_timestamp(activity["createdDate"])

        PullRequestReviewExporter.new(
          repository_exporter: repository_exporter,
          pull_request_model:  pull_request_model,
          commit_id:           commit_id,
          activity:            activity
        ).export
      end
    end

    # Export issue events.
    def export_issue_events
      issue_event_activities.each do |activity|
        IssueEventExporter.new(
          repository_exporter: repository_exporter,
          pull_request_model:  pull_request_model,
          activity:            activity
        ).export
      end
    end
  end
end
