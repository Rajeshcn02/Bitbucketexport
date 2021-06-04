# frozen_string_literal: true

class BbsExporter
  module Logging
    class ProgressBarIO
      PROGRESS_BAR_OPTIONS = {
        title:         "",
        format:        "%t%i",
        throttle_rate: 0
      }

      attr_reader :progress_bar, :enabled

      def initialize(enable: nil)
        @enabled = enable.nil? ? STDOUT.tty? : enable
        @progress_bar = ProgressBar.create(PROGRESS_BAR_OPTIONS) if enabled
      end

      def write(text)
        return progress_bar.log(text) if enabled

        STDOUT.write(text)
        STDOUT.flush
      end

      def title=(title)
        progress_bar.title = truncate(title) if enabled
      end

      def close
        progress_bar.title = "" if enabled
      end

      private

      def truncate(text)
        text.truncate(TermInfo.screen_width)
      end
    end
  end
end
