# frozen_string_literal: true

class BbsExporter
  class CommitComment
    class Base
      include PullRequestHelpers

      attr_reader :repository, :commit_id, :path
      attr_accessor :comment, :parent_comment

      def parent_comment_url
        # FIXME: This doesn't seem to translate correctly in comment bodies.

        model = {
          repository: repository,
          commit_id:  commit_id,
          comment:    parent_comment
        }

        ModelUrlService.new.url_for_model(model, type: "commit_comment")
      end

      def binary_file?
        false
      end

      def file?
        false
      end

      def create_child(child_comment)
        child_commit_comment = self.dup
        child_commit_comment.parent_comment = comment
        child_commit_comment.comment = child_comment

        child_commit_comment
      end
    end
  end
end
