# frozen_string_literal: true

class BbsExporter
  module Logging
    LOGGER_SEVERITY_MAP = {
      debug:   Logger::Severity::DEBUG,
      info:    Logger::Severity::INFO,
      warn:    Logger::Severity::WARN,
      error:   Logger::Severity::ERROR,
      fatal:   Logger::Severity::FATAL,
      unknown: Logger::Severity::UNKNOWN
    }

    LOGGER_SEVERITY_COLORS = {
      "DEBUG"   => :white,
      "INFO"    => :light_green,
      "WARN"    => :light_yellow,
      "ERROR"   => :light_red,
      "FATAL"   => :light_magenta,
      "UNKNOWN" => :light_white
    }

    FORMATTER = proc do |severity, datetime, progname, message|
      timestamp = datetime.strftime("%F %T").light_cyan
      message_color = message.send(LOGGER_SEVERITY_COLORS[severity])

      "[#{timestamp}] #{message_color}\n"
    end

    def model_url_service
      @model_url_service ||= ModelUrlService.new
    end

    def logger
      @logger ||= Logger.new(
        File.join(logs_dir, "bbs-exporter.log"),
        10,
        1024000
      )
    end

    def output_logger
      @output_logger ||= Logger.new(progress_bar_io).tap do |logger|
        logger.formatter = FORMATTER
      end
    end

    def log_with_url(
      severity:, message:, model: nil, model_name: nil, model_url: nil,
      console: false
    )
      model_url ||= model_url_service.url_for_model(model, type: model_name)
      output = "#{model_name}: #{model_url} #{message}"
      logger_severity = LOGGER_SEVERITY_MAP.fetch(severity)

      logger.add(logger_severity, output)
      output_logger.add(logger_severity, output) if console
    end


    def log_exception(exception, meta = {})
      message = [meta[:message], exception.message].compact.join(": ")

      output_logger.error(message)

      quietly_log_exception(exception, meta)
    end

    def quietly_log_exception(exception, meta = {})
      longform = Array.wrap(exception.full_message)
      longform << meta.map { |k, v| "#{k}:\n#{v}" }

      logger.error(longform.join("\n"))
    end

    def progress_bar_title(title, &block)
      progress_bar_io.title = title
      returned_from_block = block.call
      progress_bar_io.title = ""

      returned_from_block
    end

    def progress_bar_disable!
      progress_bar_io(enable: false)
    end

    private

    def progress_bar_io(enable: nil)
      @progress_bar_io ||= ProgressBarIO.new(enable: enable)
    end

    def logs_dir
      "./log/"
    end
  end
end
