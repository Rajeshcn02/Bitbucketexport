# frozen_string_literal: true

class BbsExporter
  class PullRequestReviewCommentExporter
    include Writable
    include SafeExecution
    include PullRequestHelpers
    include Logging

    log_handled_exceptions_to :logger

    attr_reader :pull_request_model, :repository_exporter, :activity,
      :parent_comment, :comment

    delegate :logger, :log_with_url, :archiver, to: :current_export
    delegate :repository, :repository_model, :current_export,
      to: :repository_exporter
    delegate :moved?, :path, to: :diff_hunk_positioner

    def initialize(
      repository_exporter:, pull_request_model:, activity:,
      parent_comment: nil, commit_id: nil, position: nil, comment: nil,
      diff_hunk: nil, commit_removed: nil
    )
      @repository_exporter = repository_exporter
      @pull_request_model = pull_request_model
      @activity = activity
      @parent_comment = parent_comment
      @commit_id = commit_id
      @position = position
      @comment = comment || activity["comment"]
      @diff_hunk = diff_hunk
      @commit_removed = commit_removed
    end

    def text
      comment["text"]
    end

    def created_date
      comment["createdDate"]
    end

    def author
      comment["author"]
    end

    def comment_anchor
      activity["commentAnchor"]
    end

    def pull_request
      @pull_request ||= pull_request_model.pull_request
    end

    def merge_conflict?
      diff["diffs"].detect do |diff_item|
        DiffItem.new(diff_item).conflict_marker?
      end
    end

    def commit_removed
      @commit_removed = removed_commit?(activity) if @commit_removed.nil?
      @commit_removed
    end

    def position
      @position ||= case
      when file_comment?(activity)
        1
      when commit_removed
        nil
      else
        diff_position
      end
    end

    def diff_position
      diff_hunk_positioner.position
    end

    def commit_id
      @commit_id ||= commit_id_from_activity(activity)
    end

    def diff_hunk
      return unless commit_removed
      @diff_hunk ||= DiffHunkGenerator.new(activity).diff_hunk
    end

    # Fetches the entire diff metadata from Bitbucket Server that applies to an
    # activity.
    #
    # Sometimes, but not always, Bitbucket Server truncates segments in diff
    # data returned from the "activities" API endpoint.  In order to calculate
    # a correct comment position for diff hunk data in GitHub, we always need
    # the complete diff data because we start from the top and work down until
    # a valid position is found.
    #
    # @return [Hash] Diff data from Bitbucket Server
    def diff
      @diff ||= begin
        pull_request_model.diff(
          comment_anchor["path"],
          src_path:  comment_anchor["srcPath"],
          diff_type: "COMMIT",
          since_id:  comment_anchor["fromHash"],
          until_id:  comment_anchor["toHash"]
        )
      rescue Faraday::ResourceNotFound => e
        quietly_log_exception(e,
          src_path:  comment_anchor["srcPath"],
          since_id: comment_anchor["fromHash"],
          until_id: comment_anchor["toHash"]
        )
        nil
      end
    end

    def binary_file?
      return false unless diff
      DiffItem.new(diff["diffs"].first).binary?
    end

    def diff_hunk_positioner
      @diff_hunk_positioner ||= DiffHunkPositioner.new(
        diff:     diff,
        activity: activity
      )
    end

    def parent_comment_url
      ModelUrlService.new.url_for_model(
        { pull_request: pull_request },
        type:    "pull_request_review_comment",
        comment: parent_comment
      )
    end

    def attachment_exporter
      @attachment_exporter ||= AttachmentExporter.new(
        current_export:   current_export,
        repository_model: repository_model,
        parent_type:      "pull_request_review_comment",
        parent_model:     bbs_model,
        user:             author,
        body:             text,
        created_date:     created_date
      )
    end

    def comment_body
      @comment_body ||= if file_comment?(activity)
        comment_body_for_file_comment(text)
      elsif moved?
        comment_body_with_original_line(comment_anchor["line"], text)
      elsif comment_in_thread?(parent_comment, activity["comment"])
        comment_body_with_thread(parent_comment_url, text)
      else
        text
      end
    end

    def bbs_model
      {
        pull_request:   pull_request,
        activity:       activity,
        comment:        comment,
        parent_comment: parent_comment,
        commit_id:      commit_id,
        position:       position,
        body:           comment_body,
        diff_hunk:      diff_hunk
      }
    end

    def log_warning(message)
      log_with_url(
        severity:   :warn,
        message:    message,
        model:      bbs_model,
        model_name: "pull_request_review_comment",
        console:    true
      )
    end

    def merge_conflict_warning
      log_warning(
        "was skipped because comments on merge conflicts are not supported"
      )
    end

    def binary_file_warning
      log_warning(
        "was skipped because comments on binary files are not supported"
      )
    end

    def no_diff_warning
      log_warning(
        "was skipped because a diff for this PR could not be fetched"
      )
    end

    def export_comment
      if diff.present?
        return binary_file_warning if binary_file?
        return merge_conflict_warning if merge_conflict?
      end

      attachment_exporter.export
      text.replace(attachment_exporter.rewritten_body)

      serialize("pull_request_review_comment", bbs_model)
    end

    def export_child_comments
      comment["comments"].each do |child_comment|
        self.class.new(
          repository_exporter: repository_exporter,
          pull_request_model:  pull_request_model,
          comment:             child_comment,
          parent_comment:      comment,
          activity:            activity,
          commit_id:           commit_id,
          position:            position,
          diff_hunk:           diff_hunk,
          commit_removed:      commit_removed
        ).export
      end
    end

    def export
      begin
        export_comment
        export_child_comments
        true
      rescue ActiveModel::ValidationError => e
        log_exception(e,
          message: "Unable to export review comment, see logs for details",
          url: model_url_service.url_for_model(bbs_model, type: "pull_request_review_comment"),
          model: bbs_model
        )
        false
      end
    end

    private

    def model_url_service
      @model_url_service ||= ModelUrlService.new
    end
  end
end
