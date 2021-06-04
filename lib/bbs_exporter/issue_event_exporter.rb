# frozen_string_literal: true

class BbsExporter
  class IssueEventExporter
    include Writable
    include SafeExecution

    ACTION_MAP = {
      "DECLINED" => "closed",
      "MERGED"   => "merged",
      "REOPENED" => "reopened"
    }

    log_handled_exceptions_to :logger

    attr_reader :pull_request_model, :repository_exporter, :activity, :archiver

    delegate :logger, :archiver, to: :current_export
    delegate :repository, :current_export, to: :repository_exporter

    def initialize(
      repository_exporter:, pull_request_model:, activity:
    )
      @repository_exporter = repository_exporter
      @pull_request_model = pull_request_model
      @activity = activity
    end

    def event
      @event ||= ACTION_MAP.fetch(activity["action"])
    end

    def bbs_model
      @bbs_model ||= {
        pull_request: pull_request_model.pull_request,
        event:        event,
        activity:     activity,
        activity_id:  activity_id
      }
    end

    def activity_id
      # Extra issue events need to be generated to provide parity between BBS
      # and GitHub.  Mutiplying the BBS issue events by 10 gives us an extra
      # digit of generated issue events to work with.

      activity["id"] * 10
    end

    def bbs_model_closed
      # Additional closed issue events are necessary to make GitHub PRs appear
      # as merged.  There is no equivalent BBS action for this closed event, so
      # we have to make one up.  All the BBS activity IDs have been multiplied
      # by 10, so we can add 1 to the activity ID for the "MERGED" action in
      # BBS for a unique GitHub issue event ID.

      closed_activity_id = activity_id + 1

      bbs_model.merge(
        event:       "closed",
        activity_id: closed_activity_id
      )
    end

    def merged?
      event == "merged"
    end

    def export
      serialize("issue_event", bbs_model)

      # When a PR is merged in BBS, a "MERGED" action is created.  This is
      # synonymous to a "merged" issue event in GitHub, but an additional
      # "closed" event must be created for PRs to appear as merged.

      serialize("issue_event", bbs_model_closed) if merged?
    end
  end
end
