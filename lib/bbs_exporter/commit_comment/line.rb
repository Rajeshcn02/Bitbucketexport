# frozen_string_literal: true

class BbsExporter
  class CommitComment
    class Line < Base
      include PullRequestHelpers

      attr_reader :diff

      delegate :moved?, :path, :position, to: :diff_hunk_positioner

      def initialize(
        repository:, commit_id:, diff:, comment:, position: nil,
        parent_comment: nil
      )
        @repository = repository
        @commit_id = commit_id
        @diff = diff
        @comment = comment
        @position = position
        @parent_comment = parent_comment
      end

      def diff_hunk_positioner
        @diff_hunk_positioner ||= DiffHunkPositioner.new(
          diff:       diff,
          comment_id: comment["id"]
        )
      end

      def body
        @body ||= case
        when parent_comment
          comment_body_with_thread(parent_comment_url, comment["text"])
        when moved?
          comment_body_with_original_line(comment_position, comment["text"])
        else
          comment["text"]
        end
      end

      private

      def comment_position
        diff["diffs"].detect do |diff_item|
          line = DiffItem.new(diff_item).line_with_comment(comment_id: comment["id"])
          return line["destination"] if line
        end
      end
    end
  end
end
