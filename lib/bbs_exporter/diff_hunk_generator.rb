# frozen_string_literal: true

class BbsExporter
  class DiffHunkGenerator
    attr_reader :activity

    def initialize(activity)
      @activity = activity
    end

    def output
      @output.to_s
    end

    def diff_hunk
      generate! if output.empty?
      output
    end

    def generate!
      @output = ""

      hunks.each do |hunk|
        @output += range_info(hunk)

        hunk["segments"].each do |segment|
          indicator = line_indicator(segment)

          segment["lines"].each do |line|
            @output += "\n#{indicator}#{line["line"]}"
            return if line["commentIds"]&.include?(comment_id)
          end
        end
      end
    end

    private

    def hunks
      Array.wrap(activity.dig("diff", "hunks"))
    end

    def comment_id
      activity["comment"]["id"]
    end

    def range_info(hunk)
      "@@ " \
      "-#{hunk["sourceLine"]},#{hunk["sourceSpan"]} " \
      "+#{hunk["destinationLine"]},#{hunk["destinationSpan"]} " \
      "@@"
    end

    def line_indicator(segment)
      case segment["type"]
      when "ADDED"
        "+"
      when "REMOVED"
        "-"
      when "CONTEXT"
        " "
      end
    end
  end
end
