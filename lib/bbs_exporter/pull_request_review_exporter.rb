# frozen_string_literal: true

class BbsExporter
  class PullRequestReviewExporter
    include Writable
    include SafeExecution
    include PullRequestHelpers
    include Logging

    ACTION_MAP = {
      "COMMENTED"  => 1,   # Commented
      "APPROVED"   => 40,  # Approved
      "UNAPPROVED" => 30   # Changes requested
    }

    log_handled_exceptions_to :logger

    attr_reader :pull_request_model, :repository_exporter, :commit_id,
      :activity, :archiver

    delegate :logger, :archiver, to: :current_export
    delegate :repository, :current_export, to: :repository_exporter

    def initialize(
      repository_exporter:, pull_request_model:, commit_id:, activity:
    )
      @repository_exporter = repository_exporter
      @pull_request_model = pull_request_model
      @commit_id = commit_id
      @activity = activity
    end

    def state
      ACTION_MAP.fetch(activity["action"])
    end

    def export
      review_bbs_model = {
        pull_request: pull_request_model.pull_request,
        commit_id:    commit_id,
        state:        state,
        activity:     activity
      }

      begin
        serialize("pull_request_review", review_bbs_model)
        true
      rescue ActiveModel::ValidationError => e
        log_exception(e,
          message: "Unable to export review, see logs for details",
          url: model_url_service.url_for_model(review_bbs_model, type: "pull_request_review"),
          model: review_bbs_model
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
