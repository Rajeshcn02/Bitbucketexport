# frozen_string_literal: true

class BbsExporter
  module Writable
    # A mapping of models to their serializers
    SERIALIZERS = {
      "user"                        => UserSerializer,
      "team"                        => TeamSerializer,
      "organization"                => OrganizationSerializer,
      "repository"                  => RepositorySerializer,
      "issue_comment"               => PullRequestCommentSerializer,
      "issue_event"                 => IssueEventSerializer,
      "pull_request"                => PullRequestSerializer,
      "pull_request_review"         => PullRequestReviewSerializer,
      "pull_request_review_comment" => PullRequestReviewCommentSerializer,
      "commit_comment"              => CommitCommentSerializer,
      "release"                     => ReleaseSerializer,
      "protected_branch"            => ProtectedBranchSerializer,
      "attachment"                  => AttachmentSerializer
    }

    def model_url_service
      @model_url_service ||= ModelUrlService.new
    end

    # Serialize a model with a given type
    #
    # @param [String] model_name the type of model to be serialized
    # @param [Hash] model the Bitbucket Server data to be serialized
    # @return [Boolean] when true, this is the first time this model has been
    #   serialized; when false, this model has been serialized before so it was
    #   not serialized again
    def serialize(model_name, model)
      serializer = SERIALIZERS[model_name].new(
        model_url_service: model_url_service
      )

      model_url = model_url_service.url_for_model(model, type: model_name)

      if archiver.seen?(model_name, model_url)
        current_export.log_with_url(
          severity:   :info,
          model_name: model_name,
          model_url:  model_url,
          message:    "already serialized"
        )

        false
      else
        current_export.log_with_url(
          severity:   :info,
          model_name: model_name,
          model_url:  model_url,
          message:    "serialized to json"
        )

        archiver.write(model_name: model_name, data: serializer.serialize(model))
        archiver.seen(model_name, model_url)

        true
      end
    end
  end
end
