# frozen_string_literal: true

class BbsExporter
  class AttachmentExporter
    class ContentType
      SUPPORTED_TYPES = %w(
        application/gzip
        application/octet-stream
        application/pdf
        application/vnd.openxmlformats-officedocument.presentationml.presentation
        application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
        application/vnd.openxmlformats-officedocument.wordprocessingml.document
        application/zip
        image/gif
        image/jpeg
        image/png
        text/plain
      )

      SUPPORTED_TYPES_MAP = {
        "application/octet-stream" => "text/x-log"
      }

      attr_accessor :repository_model, :path

      def initialize(repository_model:, path:)
        @repository_model = repository_model
        @path = path
      end

      def raw_content_type
        @raw_content_type ||= repository_model.attachment_content_type(path)
      end

      def parsed_content_type
        mime_type = MIME::Types[raw_content_type].first
        mime_type ? mime_type.content_type : raw_content_type
      end

      def content_type
        SUPPORTED_TYPES_MAP.fetch(parsed_content_type, parsed_content_type)
      end

      def supported?
        SUPPORTED_TYPES.include?(parsed_content_type)
      end
    end
  end
end
