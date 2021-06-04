# frozen_string_literal: true

class BbsExporter
  class IssueEventSerializer < BaseSerializer
    validates_presence_of :activity, :event, :pull_request, :user,
      :created_date

    def to_gh_hash
      {
        type:         type,
        url:          url,
        pull_request: pull_request_url,
        actor:        user_url,
        event:        event,
        created_at:   created_date_formatted
      }
    end

    private

    def type
      "issue_event"
    end

    def pull_request
      bbs_model[:pull_request]
    end

    def event
      bbs_model[:event]
    end

    def activity
      bbs_model[:activity]
    end

    def user
      activity["user"]
    end

    def created_date
      activity["createdDate"]
    end

    def url
      url_for_model(bbs_model, type: "issue_event")
    end

    def pull_request_url
      url_for_model(pull_request)
    end

    def user_url
      url_for_model(user, type: "user")
    end

    def created_date_formatted
      format_long_timestamp(created_date)
    end
  end
end
