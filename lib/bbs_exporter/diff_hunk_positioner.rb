# frozen_string_literal: true

class BbsExporter
  class DiffHunkPositioner
    include PullRequestHelpers

    attr_reader :activity, :comment_id, :diff

    def initialize(diff:, activity: nil, comment_id: nil)
      @diff = diff
      @activity = activity
      @comment_id = comment_id
    end

    # Calculates the comment position for a GitHub diff hunk from Bitbucket
    # Server activity data.
    #
    # @return [Array<Boolean,Integer>] If the comment was moved to the closest
    #   appropriate location, and the location of comment in the GitHub diff
    #   hunk.
    def calculate!
      @hunk, @path = nil

      return if diff.nil?

      DiffItem.wrap(diff["diffs"]).detect do |diff_item|
        diff_item.hunks.detect do |hunk_item|
          hunk = Hunk.new(hunk: hunk_item, comment_line: comment_line)

          if hunk.has_comment?
            @hunk = hunk
            @path = diff_item.path

            return true
          end
        end
      end
    end

    def has_comment?
      @has_comment ||= calculate!
    end

    def moved?
      calculate! unless calculated?
      @hunk&.moved?
    end

    def position
      calculate! unless calculated?
      @hunk&.position
    end

    def path
      calculate! unless calculated?
      @path
    end

    private

    def comment_line
      @comment_line ||= if comment_id
        comment_line_from_diff
      elsif activity
        comment_line_from_activity
      end
    end

    def comment_line_from_diff
      DiffItem.wrap(diff["diffs"]).detect do |diff_item|
        line = diff_item.line_with_comment(comment_id: comment_id)
        return line.except("commentIds") if line
      end
    end

    def comment_line_from_activity
      line = DiffItem.new(activity["diff"]).line_with_comment
      line.except("commentIds") if line
    end

    def calculated?
      defined?(@has_comment)
    end
  end
end
