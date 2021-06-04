# frozen_string_literal: true

class BbsExporter
  module PullRequestHelpers
    include Logging

    REVIEWED_ACTIONS = %w(APPROVED UNAPPROVED)
    ISSUE_EVENT_ACTIONS = %w(DECLINED MERGED REOPENED)

    # Check if activity contains any type of PR comment.
    #
    # @param [Hash] activity Bitbucket Server activity data.
    # @return [TrueClass] Activity contains a PR comment of any type.
    # @return [FalseClass] Activity does not contain a PR comment of any type.
    def commented?(activity)
      activity["action"] == "COMMENTED"
    end

    # Check if activity contains a PR comment.
    #
    # @param [Hash] activity Bitbucket Server activity data.
    # @return [TrueClass] Activity contains a PR comment.
    # @return [FalseClass] Activity does not contain a PR comment.
    def comment?(activity)
      commented?(activity) && \
        !activity.key?("commentAnchor") && \
        !activity.key?("diff")
    end

    # Check if activity contains a PR file comment.
    #
    # @param [Hash] activity Bitbucket Server activity data.
    # @return [TrueClass] Activity contains a PR file comment.
    # @return [FalseClass] Activity does not contain a PR file comment.
    def file_comment?(activity)
      commented?(activity) && \
        activity.key?("commentAnchor") && \
        !activity.key?("diff")
    end

    # Check if activity contains a PR diff comment.
    #
    # @param [Hash] activity Bitbucket Server activity data.
    # @return [TrueClass] Activity contains a PR diff comment.
    # @return [FalseClass] Activity does not contain a PR diff comment.
    def diff_comment?(activity)
      commented?(activity) && \
        activity.key?("commentAnchor") && \
        activity.key?("diff")
    end

    # Check if activity contains a PR issue event.
    #
    # @param [Hash] activity Bitbucket Server activity data.
    # @return [TrueClass] Activity contains a PR issue event.
    # @return [FalseClass] Activity does not contain a PR issue event.
    def issue_event?(activity)
      ISSUE_EVENT_ACTIONS.include?(activity["action"])
    end

    # Get the last commit ID that is still relevant for an activity.  For
    # "effective" diffs, the commit ID is fetched from Bitbucket Server's API.
    #
    # @param [Hash] activity Activity to get last commit ID for.
    # @return [String] The last relevant commit ID,
    def commit_id_from_activity(activity)
      anchor = activity["commentAnchor"]
      to_hash = anchor["toHash"]

      anchor["diffType"] == "EFFECTIVE" ? last_commit_id(to_hash) : to_hash
    end

    # Get the last relevant commit ID from a commit ID.  This is intended to be
    # used with Bitbucket Servers' "effective" commit IDs, which are generated
    # from a dry run of merging master into a branch without committing.
    #
    # @param [String] to_hash Commit ID to get last relevant commit ID from.
    # @return [String] The last relevant commit ID,
    def last_commit_id(to_hash)
      commit = pull_request_model.repository_model.commit(to_hash)
      commit["parents"].last["id"]
    rescue Faraday::ResourceNotFound => e
      quietly_log_exception(e, hash: to_hash)
      nil
    end

    # Prepends text to a comment body that indicates what line in Bitbucket
    # Server the comment was originally made on.  This is used when a comment
    # is moved to indicate the applicable line the comment is for.
    #
    # @param [Integer] line Line number where comment originally was.
    # @param [String] body Comment body.
    # @return [String] Comment body with text about original comment location
    #   prepended.
    def comment_body_with_original_line(line, body)
      ":twisted_rightwards_arrows: *Originally on **line #{line}** " \
        "in Bitbucket Server:*\n\n#{body}"
    end

    # Prepends text to a comment body that indicates that the comment was
    # originally a file comment.  These comments are moved to the first
    # available position in a diff hunk for a file.
    #
    # @param [String] body Comment body.
    # @return [String] Comment body with prepended text about how the comment
    #   was originally a file comment.
    def comment_body_for_file_comment(body)
      ":twisted_rightwards_arrows: *Originally a **file comment** in " +
        "Bitbucket Server:*\n\n#{body}"
    end

    def comment_body_with_thread(prent_comment_url, body)
      ":arrow_right_hook: *Originally a reply to " \
        "[this comment](#{parent_comment_url}) " \
        "from a comment thread in Bitbucket Server:*\n\n#{body}"
    end

    def comment_in_thread?(parent_comment, comment)
      parent_comment.present? && parent_comment["id"] != comment["id"]
    end

    def moved_base_comment?(parent_comment, moved)
      parent_comment.nil? && moved
    end

    def reviewed?(activity)
      REVIEWED_ACTIONS.include?(activity["action"])
    end

    def removed_commit?(activity)
      commit_id = commit_id_from_activity(activity)

      pull_request_model.commits.each do |commit|
        return false if commit["id"] == commit_id
      end

      true
    end
  end
end
