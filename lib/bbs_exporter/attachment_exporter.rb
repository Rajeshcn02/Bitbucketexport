# frozen_string_literal: true

class BbsExporter
  class AttachmentExporter
    include Writable

    ATTACHMENT_REGEX = /\((?<link>\s*attachment:\d+\/.+?)(?<tooltip>\s+['"].*?['"])?\s*\)/m

    attr_reader :current_export, :repository_model, :parent_type, :parent_model,
      :user, :body, :created_date

    delegate :archiver, :bitbucket_server, to: :current_export
    delegate :repository, to: :repository_model

    def initialize(
      current_export:, repository_model:, parent_type:, parent_model:, user:,
      body:, created_date:
    )
      @current_export = current_export
      @repository_model = repository_model
      @parent_type = parent_type
      @parent_model = parent_model
      @user = user
      @body = body
      @created_date = created_date
    end

    def bbs_model(attachment)
      {
        parent_type:        parent_type,
        parent_model:       parent_model,
        user:               user,
        created_date:       created_date,
        url:                attachment.rewritten_link,
        asset_name:         attachment.asset_name,
        asset_content_type: attachment.asset_content_type,
        asset_url:          attachment.asset_url
      }
    end

    def rewritten_body
      @attachments ||= []

      @rewritten_body ||= body.gsub(ATTACHMENT_REGEX) do
        @attachments << attachment = Attachment.new(
          link:             $~[:link],
          tooltip:          $~[:tooltip],
          archiver:         archiver,
          repository_model: repository_model
        )

        attachment.markdown_link
      end
    end

    def attachments
      rewritten_body unless @attachments
      @attachments
    end

    def export
      attachments.each do |attachment|
        attachment.archive!
        serialize("attachment", bbs_model(attachment))
      end
    end
  end
end
