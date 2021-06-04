# frozen_string_literal: true

class BbsExporter
  class Git
    include Logging

    ASKPASS_WRAPPER_PATH = Bundler.root.join(
      "exe", "bbs-exporter-askpass"
    ).to_s

    attr_accessor :ssl_verify

    def initialize(ssl_verify: true)
      @ssl_verify = ssl_verify
    end

    # Create a copy of a repository for archiving.
    #
    # @param url [String] URL for cloning a repository.
    # @param target [String] Local directory to clone repository to.
    def clone(url:, target:)
      # Kill the last attempt to export.
      FileUtils.rm_rf(target)

      # Start with a normal git clone, so that we get objects stored in a
      # network repo, if it exists.
      progress_bar_title("git clone #{url}") do
        ClimateControl.modify(env) do
          ::Git.clone(url, target, mirror: true)
        end
      end
    end

    private

    def env
      {}.tap do |env|
        env[:GIT_ASKPASS] = ASKPASS_WRAPPER_PATH
        env[:GIT_SSL_NO_VERIFY] = (!ssl_verify).to_s
      end
    end
  end
end
