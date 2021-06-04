# frozen_string_literal: true

class BbsExporter
  class CommitCommentExporter
    include Writable
    include SafeExecution
    include Logging

    log_handled_exceptions_to :logger

    attr_reader :repository_exporter, :commit_comment

    delegate :logger, :archiver, :log_with_url, to: :current_export
    delegate :repository_model, :repository, :current_export,
      to: :repository_exporter
    delegate :body, :comment, :commit_id, :diff, :path, :position,
      :parent_comment, :binary_file?, :file?, to: :commit_comment
    delegate :rewritten_body, to: :attachment_exporter

    def initialize(repository_exporter:, commit_comment:)
      @repository_exporter = repository_exporter
      @commit_comment = commit_comment
    end

    def author
      comment["author"]
    end

    def created_date
      comment["createdDate"]
    end

    def author_model
      {
        user:       author,
        repository: repository
      }
    end

    def bbs_model
      {
        repository: repository,
        comment:    comment,
        position:   position,
        body:       body,
        author:     author_model,
        commit_id:  commit_id,
        path:       path
      }
    end

    def log_warning(message)
      log_with_url(
        severity:   :warn,
        message:    message,
        model:      bbs_model,
        model_name: "commit_comment",
        console:    true
      )
    end

    def binary_file_warning
      log_warning(
        "was skipped because comments on binary files are not supported"
      )
    end

    def export_comment
      return binary_file_warning if binary_file?

      attachment_exporter.export
      bbs_model[:body] = attachment_exporter.rewritten_body

      serialize("commit_comment", bbs_model)
    end

    def export_child_comments
      comment["comments"].each do |child_comment|
        child_commit_comment = commit_comment.create_child(child_comment)

        self.class.new(
          repository_exporter: repository_exporter,
          commit_comment:      child_commit_comment,
        ).export
      end
    end

    def attachment_exporter
      @attachment_exporter ||= AttachmentExporter.new(
        current_export:   current_export,
        repository_model: repository_model,
        parent_type:      "commit_comment",
        parent_model:     bbs_model,
        user:             author_model,
        body:             body,
        created_date:     created_date
      )
    end

    def export
      export_comment
      export_child_comments
      true
    rescue ActiveModel::ValidationError => e
      log_exception(e,
        message: "Unable to export commit comment, see logs for details",
        url: model_url_service.url_for_model(bbs_model, type: "commit_comment"),
        model: bbs_model
      )
      false
    end

    private

    def model_url_service
      @model_url_service ||= ModelUrlService.new
    end
  end
end
