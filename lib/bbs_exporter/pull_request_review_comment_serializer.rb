# frozen_string_literal: true

class BbsExporter
  class PullRequestReviewCommentSerializer < BaseSerializer
    validates_presence_of :activity, :author, :body, :comment, :commit_id,
      :created_date, :path

    validate :has_position_or_diff_hunk

    def to_gh_hash
      {
        type:                type,
        url:                 url,
        pull_request:        pull_request_url,
        pull_request_review: pull_request_review,
        in_reply_to:         in_reply_to,
        user:                author_url,
        body:                body,
        formatter:           formatter,
        path:                path,
        commit_id:           commit_id,
        original_position:   original_position,
        position:            position,
        diff_hunk:           diff_hunk,
        state:               state,
        created_at:          created_date_formatted
      }
    end

    private

    def type
      "pull_request_review_comment"
    end

    def activity
      bbs_model[:activity]
    end

    def body
      bbs_model[:body]
    end

    def comment
      bbs_model[:comment]
    end

    def parent_comment
      bbs_model[:parent_comment]
    end

    def commit_id
      bbs_model[:commit_id]
    end

    def original_position
      bbs_model[:position]
    end

    def position
      bbs_model[:position]
    end

    def diff_hunk
      bbs_model[:diff_hunk]
    end

    def author
      comment["author"]
    end

    def created_date
      comment["createdDate"]
    end

    def path
      activity["commentAnchor"]["path"]
    end

    def url
      url_for_model(bbs_model, type: type)
    end

    def pull_request_url
      url_for_model(bbs_model[:pull_request])
    end

    def pull_request_review
      url_for_model(bbs_model, type: "pull_request_review")
    end

    def in_reply_to
      return unless parent_comment

      url_for_model(
        bbs_model,
        type:    type,
        comment: parent_comment
      )
    end

    def author_url
      url_for_model(author)
    end

    def formatter
      "markdown"
    end

    def state
      1  # "submitted" state.
    end

    def created_date_formatted
      format_long_timestamp(created_date)
    end

    def has_position_or_diff_hunk
      unless position || diff_hunk
        errors.add(:base, "must have either `position` or `diff_hunk`")
      end
    end
  end
end
