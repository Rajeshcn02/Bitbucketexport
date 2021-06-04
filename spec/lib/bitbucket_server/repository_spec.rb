# frozen_string_literal: true

require "spec_helper"

describe BitbucketServer::Repository do
  let(:project_model) do
    bitbucket_server.project_model("BBS486")
  end

  let(:repository_model) do
    project_model.repository_model("empty-repo")
  end

  let(:commits_404) do
    VCR.use_cassette("projects/BBS486/empty-repo/commits") do
      repository_model.commits
    end
  end

  describe "#commits" do
    it "returns an empty array for 404s" do
      expect(commits_404).to eq([])
    end
  end
end
