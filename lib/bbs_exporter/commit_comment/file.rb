# frozen_string_literal: true

class BbsExporter
  class CommitComment
    class File < Base
      include PullRequestHelpers

      attr_reader :diff_item

      def initialize(
        repository:, commit_id:, diff_item:, comment:, parent_comment: nil
      )
        @repository = repository
        @commit_id = commit_id
        @diff_item = diff_item
        @comment = comment
        @parent_comment = parent_comment
      end

      def position
        1
      end

      def binary_file?
        diff_item["binary"]
      end

      def file?
        true
      end

      def path
        @path ||= DiffItem.new(diff_item).path
      end

      def body
        @body ||= if parent_comment
          comment_body_with_thread(parent_comment_url, comment["text"])
        else
          comment_body_for_file_comment(comment["text"])
        end
      end
    end
  end
end
