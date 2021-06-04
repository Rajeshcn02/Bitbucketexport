# frozen_string_literal: true

class BbsExporter
  class BadVersion < StandardError
    def initialize(version)
      @version = version
    end

    def message
      <<-EOF
This utility requires Bitbucket Server version #{MINIMUM_VERSION} or greater.
The version returned by Bitbucket Server was #{@version}.
      EOF
    end
  end

  class NotImplementedError < StandardError
    attr_accessor :object

    def initialize(object)
      @object = object
    end

    def message
      <<~EOF
        This utility encountered an error while trying to export #{object.inspect}
        because it does not support exporting #{object.class} in this context
      EOF
    end
  end
end
