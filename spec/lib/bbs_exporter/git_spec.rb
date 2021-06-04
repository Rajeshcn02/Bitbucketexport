# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::Git do
  let(:askpass_wrapper_path) { described_class::ASKPASS_WRAPPER_PATH }

  subject(:git) { described_class.new }

  describe "#clone" do
    before(:each) do
      allow(FileUtils).to receive(:rm_rf)
      git.progress_bar_disable!
    end

    it "passes GIT_ASKPASS environment variable to ::Git" do
      expect(::Git).to receive(:clone) do
        expect(ENV["GIT_ASKPASS"]).to eq(askpass_wrapper_path)
      end

      git.clone(url: nil, target: nil)
    end

    it "passes GIT_SSL_NO_VERIFY=false to ::Git by default" do
      expect(::Git).to receive(:clone) do
        expect(ENV["GIT_SSL_NO_VERIFY"]).to eq("false")
      end

      git.clone(url: nil, target: nil)
    end

    context "when #ssl_verify is true" do
      subject(:git) do
        described_class.new(ssl_verify: true)
      end

      it "passes GIT_SSL_NO_VERIFY=false to ::Git" do
        expect(::Git).to receive(:clone) do
          expect(ENV["GIT_SSL_NO_VERIFY"]).to eq("false")
        end

        git.clone(url: nil, target: nil)
      end
    end

    context "when #ssl_verify is false" do
      subject(:git) do
        described_class.new(ssl_verify: false)
      end

      it "passes GIT_SSL_NO_VERIFY=true to ::Git" do
        expect(::Git).to receive(:clone) do
          expect(ENV["GIT_SSL_NO_VERIFY"]).to eq("true")
        end

        git.clone(url: nil, target: nil)
      end
    end
  end

  describe "exe/askpass-wrapper" do
    it "includes #!/bin/sh in the first line of the script" do
      askpass_wrapper_contents = File.read(askpass_wrapper_path)
      includes_bin_sh = askpass_wrapper_contents.start_with?("#!/bin/sh\n")

      expect(includes_bin_sh).to be(true)
    end

    it "writes token to stdout when token is present" do
      env_vars = {
        "BITBUCKET_SERVER_API_PASSWORD" => "password",
        "BITBUCKET_SERVER_API_TOKEN"    => "token"
      }

      Open3.popen3(env_vars, askpass_wrapper_path) do |stdin, stdout, stderr|
        expect(stdout.read).to eq("token")
      end
    end

    it "writes password to stdout when token is not present" do
      env_vars = {
        "BITBUCKET_SERVER_API_PASSWORD" => "password",
        "BITBUCKET_SERVER_API_TOKEN"    => nil
      }

      Open3.popen3(env_vars, askpass_wrapper_path) do |stdin, stdout, stderr|
        expect(stdout.read).to eq("password")
      end
    end
  end
end
