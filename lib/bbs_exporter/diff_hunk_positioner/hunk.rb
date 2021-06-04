# frozen_string_literal: true

class BbsExporter
  class DiffHunkPositioner
    class Hunk
      CONTEXT_LINES = 3

      attr_reader :comment_line, :hunk

      def initialize(hunk:, comment_line:)
        @hunk = hunk
        @comment_line = comment_line
      end

      # Calculates the comment position for a GitHub diff hunk from Bitbucket
      # Server activity data.
      #
      # @return [Array<Boolean,Integer>] If the comment was moved to the
      #   closest appropriate location, and the location of comment in the
      #   GitHub diff hunk.
      def calculate!
        self.calculated_moved, self.calculated_position = nil
        new_position = 1

        hunk["segments"].each_with_index do |segment, segment_index|
          lines = segment["lines"]
          line_index = find_line_index(lines)

          if line_index
            self.calculated_moved = false

            if segment["type"] == "CONTEXT"
              self.calculated_moved, line_index = position_in_context(
                segment_index, last_segment_index, line_index, lines
              )
            end

            self.calculated_position = new_position + line_index

            return true
          end

          new_position += lines_in_segment(
            segment, segment_index, last_segment_index, lines
          )
        end

        false
      end

      def has_comment?
        @has_comment ||= calculate!
      end

      def moved?
        calculate! unless calculated?
        calculated_moved
      end

      def position
        calculate! unless calculated?
        calculated_position
      end

      private

      attr_accessor :calculated_moved, :calculated_position

      def calculated?
        defined?(@has_comment)
      end

      def find_line_index(lines)
        lines.find_index do |line|
          line.except("commentIds") == comment_line
        end
      end

      def last_segment_index
        hunk["segments"].count - 1
      end

      # Inspects a CONTEXT segment between two ADDED or REMOVED segments from
      # Bitbucket Server that is longer than 6 lines to determine if the comment
      # will live in the upper "split" context in GitHub.
      #
      # Bitbucket Server has 10 lines of context where GitHub only has 3.  When
      # two context sections are next to each other, the contexts are combined,
      # so it is possible to see 20 consecutive lines of context with Bitbucket
      # Server and 6 consecutive lines of context in GitHub.
      #
      # Because of this, context segments longer than 6 lines from Bitbucket
      # Server are broken out into two 3-line context sections in GitHub.  When
      # this happens, the comment either needs to be put on the upper context
      # section or the lower context section.
      #
      # @return [TrueClass] The comment will live on the upper "split" context
      #   in GitHub.
      # @return [FalseClass] The comment will live on the lower "split" context
      #   in GitHub.
      def in_upper_segment?(line_index, lines)
        line_index <= lines.count / 2
      end

      # Inspects a CONTEXT segment between two ADDED or REMOVED segments from
      # Bitbucket Server and determines if the comment position can be used
      # verbatim in a GitHub diff hunk.
      #
      # Bitbucket Server has 10 lines of context where GitHub only has 3.  When
      # two context sections are next to each other, the contexts are combined,
      # so it is possible to see 20 consecutive lines of context with Bitbucket
      # Server and 6 consecutive lines of context in GitHub.
      #
      # Because of this, context segments longer than 6 lines from Bitbucket
      # Server are broken out into two 3-line context sections in GitHub.  This
      # means that it is possible to put a comment in Bitbucket Server that would
      # land between these "split" contexts.
      #
      # If the CONTEXT segment length is 6 or less, we can use the position from
      # Bitbucket Server as-is, and this method returns true.
      #
      # @return [TrueClass] The CONTEXT segment length is 6 or less and the
      #   comment position from Bitbucket Server can be used as-is.
      # @return [FalseClass] The CONTEXT segment length is greater than 6, which
      #   means that GitHub will "split" this context into two contexts, and an
      #   appropriate position will need to be calculated.
      def middle_context_lines_supported?(lines)
        lines.count <= CONTEXT_LINES * 2
      end

      # Inspects a CONTEXT segment from Bitbucket Server in any location and
      # calculates the length of the segment in the GitHub diff hunk.
      #
      # Bitbucket Server has 10 lines of context where GitHub only has 3.  To
      # account for this, a value is returned that fits one of these conditions:
      #
      # - If this CONTEXT segment is the first segment, return the line count
      #   from this section with a maximum value of 3.
      # - If this CONTEXT segment is the last segment, return the line count from
      #   this section with a maximum value of 3.
      # - If this CONTEXT segment is between two ADDED or REMOVED segments and
      #   the segment is 6 lines or less, return the line count from this section
      #   (adjacent contexts are combined).
      # - If this CONTEXT segment is between two ADDED or REMOVED segments and
      #   the segment is 7 lines or longer, we will need to "split" this context
      #   into two contexts, which will be 3 context lines, one line for range
      #   information, and another 3 context lines.  In this case, always return
      #   7.
      #
      # @param [Integer] segment_index Index of segment to inspect.
      # @param [Integer] last_segment_index Last index value of segments.
      # @param [Array] lines Lines of context from the segment where a comment
      #   lives.
      # @return [Integer] How many lines this segment will produce in a GitHub
      #   diff hunk.
      def lines_in_context_segment(segment_index, last_segment_index, lines)
        longest_valid_segment = if [0, last_segment_index].include?(segment_index)
          CONTEXT_LINES
        else
          CONTEXT_LINES * 2 + 1
        end

        [lines.count, longest_valid_segment].min
      end

      # Inspects any segment from Bitbucket Server in any location and
      # calculates the length of the segment in the GitHub diff hunk.
      #
      # If the segment is of a CONTEXT type, `lines_in_context_segment` gets
      # called.  Otherwise, for ADDED and REMOVED segments, the segment length is
      # simply returned.
      #
      # @param [Array] segment Segment to inspect.
      # @param [Integer] segment_index Index of segment to inspect.
      # @param [Integer] last_segment_index Last index value of segments.
      # @param [Array] lines Lines of context from the segment where a comment
      #   lives.
      # @return [Integer] How many lines this segment will produce in a GitHub
      #   diff hunk.
      def lines_in_segment(segment, segment_index, last_segment_index, lines)
        if segment["type"] == "CONTEXT"
          lines_in_context_segment(segment_index, last_segment_index, lines)
        else
          lines.count
        end
      end

      # Inspects the first CONTEXT segment from Bitbucket Server and calculates a
      # GitHub position along with if the comment was moved or not.
      #
      # Bitbucket Server has 10 lines of context where GitHub only has 3.  This
      # means that a comment can be placed above a line supported in GitHub.  If
      # this happens, the comment is moved to the top of the segment.  Otherwise,
      # place the comment on an equivalent position in GitHub.
      #
      # @param [Integer] line_index Index of line in segment where a comment
      #   lives.
      # @param [Array] lines Lines of context from the segment where a comment
      #   lives.
      # @return [Array<Boolean,Integer>] If the comment was moved to the closest
      #   appropriate location, and the location of comment in the GitHub diff
      #   hunk.
      def context_position_in_first_segment(line_index, lines)
        moved = false

        line_index -= lines.count - CONTEXT_LINES
        line_index, moved = 0, true if line_index < 0

        [moved, line_index]
      end

      # Inspects the last CONTEXT segment from Bitbucket Server and calculates a
      # GitHub position along with if the comment was moved or not.
      #
      # Bitbucket Server has 10 lines of context where GitHub only has 3.  This
      # means that a comment can be placed below a line supported in GitHub.  If
      # this happens, the comment is moved to the bottom of the segment.
      # Otherwise, place the comment on an equivalent position in GitHub.
      #
      # @param [Integer] line_index Index of line in segment where a comment
      #   lives.
      # @return [Array<Boolean,Integer>] If the comment was moved to the closest
      #   appropriate location, and the location of comment in the GitHub diff
      #   hunk.
      def context_position_in_last_segment(line_index)
        moved = line_index > (CONTEXT_LINES - 1)
        line_index = (CONTEXT_LINES - 1) if moved

        [moved, line_index]
      end

      # Inspects a CONTEXT segment and calculates a GitHub position along with if
      # the comment was moved or not when the segment fits all these
      # qualifications:
      #
      #  - It is between two ADDED or REMOVED segments.
      #  - Breaking up the context into two sections is necessary.
      #  - The comment will live on the upper "split" segment.
      #
      # @param [Integer] line_index Index of line in segment where a comment
      #   lives.
      # @return [Array<Boolean,Integer>] If the comment was moved to the closest
      #   appropriate location, and the location of comment in the GitHub diff
      #   hunk.
      def context_position_in_upper_segment(line_index)
        moved = line_index >= CONTEXT_LINES
        line_index = CONTEXT_LINES - 1 if moved

        [moved, line_index]
      end

      # Inspects a CONTEXT segment between two ADDED or REMOVED segments from
      # Bitbucket Server and calculates a GitHub position along with if the
      # comment was moved or not.
      #
      # Bitbucket Server has 10 lines of context where GitHub only has 3.  When
      # two context sections are next to each other, the contexts are combined,
      # so it is possible to see 20 consecutive lines of context with Bitbucket
      # Server and 6 consecutive lines of context in GitHub.
      #
      # Because of this, context segments longer than 6 lines from Bitbucket
      # Server are broken out into two 3-line context sections in GitHub.  This
      # means that it is possible to put a comment in Bitbucket Server that would
      # land between these "split" contexts.
      #
      # This means two things: diff hunk positions are going to differ (even if
      # the comment lands on a line supported in GitHub), and it's possible that
      # the comment will need to be moved to the nearest appropriate line to have
      # a valid position in GitHub.
      #
      # @param [Integer] line_index Index of line in segment where a comment
      #   lives.
      # @param [Array] lines Lines of context from the segment where a comment
      #   lives.
      # @return [Array<Boolean,Integer>] If the comment was moved to the closest
      #   appropriate location, and the location of comment in the GitHub diff
      #   hunk.
      def context_position_in_middle_segment(line_index, lines)
        if middle_context_lines_supported?(lines)
          [false, line_index]
        elsif in_upper_segment?(line_index, lines)
          context_position_in_upper_segment(line_index)
        else
          context_position_in_lower_segment(line_index, lines)
        end
      end

      # Inspects a CONTEXT segment and calculates a GitHub position along with if
      # the comment was moved or not when the segment fits all these
      # qualifications:
      #
      #  - It is between two ADDED or REMOVED segments.
      #  - Breaking up the context into two sections is necessary.
      #  - The comment will live on the lower "split" segment.
      #
      # @param [Integer] line_index Index of line in segment where a comment
      #   lives.
      # @param [Array] lines Lines of context from the segment where a comment
      #   lives.
      # @return [Array<Boolean,Integer>] If the comment was moved to the closest
      #   appropriate location, and the location of comment in the GitHub diff
      #   hunk.
      def context_position_in_lower_segment(line_index, lines)
        extra_lines = lines.count - CONTEXT_LINES
        moved = line_index < extra_lines

        line_index = moved ? 0 : line_index - extra_lines
        line_index += CONTEXT_LINES + 1

        [moved, line_index]
      end

      # Inspects a CONTEXT segment from Bitbucket Server in any location and
      # calculates a GitHub position along with if the comment was moved or not.
      #
      # This method detects whether the CONTEXT segment is the first part of a
      # diff, the last part of a diff, or between two ADDED or REMOVED segments,
      # then calls `context_position_in_first_segment`,
      # `context_position_in_last_segment`, or
      # `context_position_in_middle_segment` respectively.
      #
      # @param [Integer] segment_index Index of segment to inspect.
      # @param [Integer] last_segment_index Last index value of segments.
      # @param [Integer] line_index Index of line in segment where a comment
      #   lives.
      # @param [Array] lines Lines of context from the segment where a comment
      #   lives.
      # @return [Array<Boolean,Integer>] If the comment was moved to the closest
      #   appropriate location, and the location of comment in the GitHub diff
      #   hunk.
      def position_in_context(
        segment_index, last_segment_index, line_index, lines
      )
        case segment_index
        when 0
          context_position_in_first_segment(line_index, lines)
        when last_segment_index
          context_position_in_last_segment(line_index)
        else
          context_position_in_middle_segment(line_index, lines)
        end
      end
    end
  end
end
