# frozen_string_literal: true

class BbsExporter
  class AttachmentExporter
    class Attachment
      attr_accessor :link, :tooltip, :repository_model, :archiver

      delegate :repository, to: :repository_model
      delegate :current_export, to: :archiver
      delegate :log_with_url, to: :current_export

      def initialize(link:, tooltip: nil, repository_model:, archiver:)
        @link = link
        @tooltip = tooltip
        @repository_model = repository_model
        @archiver = archiver
      end

      def content_type
        @content_type ||= ContentType.new(
          repository_model: repository_model,
          path:             path
        )
      end

      def asset_content_type
        content_type.content_type
      end

      def repository_id
        repository["id"].to_s
      end

      def filename
        @filename ||= Digest::MD5.hexdigest(link) + File.extname(link)
      end

      def path
        return @path if @path

        sanitized_path = link.sub(/\A\s*attachment:\d+\//, "")
        sanitized_path.gsub!(/\+/, " ")

        sanitized_path = Addressable::URI.unencode(sanitized_path)
        @path = File.split(sanitized_path)
      end

      def encoded_path
        @encoded_path ||= path.map { |p| Addressable::URI.encode(p) }
      end

      def asset_name
        path.last
      end

      def model_url_service
        @model_url_service ||= ModelUrlService.new
      end

      def rewritten_link
        model_url_service.url_for_model(bbs_model, type: "attachment")
      end

      def asset_url
        uri_path = File.join("attachments", filename)

        uri = Addressable::URI.new(
          scheme: "tarball",
          host:   "root",
          path:   uri_path
        )

        uri.normalize.to_s
      end

      def archive!
        return content_type_error unless content_type.supported?

        attachment_data = repository_model.attachment(path)
        archiver.save_attachment(attachment_data, filename)
      end

      def markdown_link
        return original_markdown_link unless content_type.supported?
        rewritten_markdown_link
      end

      def rewritten_markdown_link
        "(#{rewritten_link}#{tooltip})"
      end

      def original_markdown_link
        "(#{link}#{tooltip})"
      end

      def bbs_model
        {
          repository: repository,
          path:       encoded_path
        }
      end

      def content_type_error
        log_with_url(
          severity:   :warn,
          message:    "was skipped because the content type is not supported",
          model:      bbs_model,
          model_name: "attachment",
          console:    true
        )
      end
    end
  end
end
