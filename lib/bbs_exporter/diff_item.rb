# frozen_string_literal: true

class BbsExporter
  class DiffItem
    include Enumerable

    attr_reader :diff

    def self.wrap(diff)
      diff.map(&method(:new))
    end

    def initialize(diff)
      @diff = diff
    end

    def each
      hunks.each do |hunk|
        hunk["segments"].each do |segment|
          segment["lines"].each do |line|
            yield(hunk, segment, line)
          end
        end
      end
    end

    def hunks
      Array.wrap(diff["hunks"])
    end

    def source
      diff["source"]&.fetch("toString")
    end

    def destination
      diff["destination"]&.fetch("toString")
    end

    def path
      destination || source
    end

    def binary?
      diff["binary"]
    end

    def line_with_comment(comment_id: nil)
      detect do |hunk, segment, line|
        if line["commentIds"]
          if comment_id.nil? || line["commentIds"]&.include?(comment_id)
            return line
          end
        end
      end
    end

    def conflict_marker?
      detect do |hunk, segment, line|
        line.key?("conflictMarker")
      end
    end
  end
end
