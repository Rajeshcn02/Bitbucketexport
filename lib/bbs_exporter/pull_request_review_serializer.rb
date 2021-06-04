# frozen_string_literal: true

class BbsExporter
  class PullRequestReviewSerializer < BaseSerializer
    validates_presence_of :activity, :commit_id, :created_date, :pull_request,
      :state, :user

    def to_gh_hash
      {
        type:               type,
        url:                url,
        pull_request:       pull_request_url,
        user:               user_url,
        formatter:          formatter,
        head_sha:           commit_id,
        state:              state,
        created_at:         created_date_formatted,
        submitted_at:       created_date_formatted
      }
    end

    private

    def type
      "pull_request_review"
    end

    def activity
      bbs_model[:activity]
    end

    def commit_id
      bbs_model[:commit_id]
    end

    def state
      bbs_model[:state]
    end

    def pull_request
      bbs_model[:pull_request]
    end

    def created_date
      activity["createdDate"]
    end

    def user
      activity["user"]
    end

    def url
      url_for_model(bbs_model, type: type)
    end

    def pull_request_url
      url_for_model(pull_request)
    end

    def user_url
      url_for_model(user, type: "user")
    end

    def formatter
      "markdown"
    end

    def created_date_formatted
      format_long_timestamp(created_date)
    end
  end
end
