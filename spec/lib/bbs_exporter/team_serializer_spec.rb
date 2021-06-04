# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::TeamSerializer do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:project) do
    VCR.use_cassette("projects/MIGR8") do
      project_model.project
    end
  end

  let(:user) do
    VCR.use_cassette("users/unit-test") do
      bitbucket_server.user
    end
  end

  let(:repository) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/repository") do
      repository_model.repository
    end
  end

  let(:model_url_service) do
    BbsExporter::ModelUrlService.new
  end

  let(:repository_url) do
    model_url_service.url_for_model(repository, type: "repository")
  end

  let(:user_url) do
    model_url_service.url_for_model(user)
  end

  let(:team) do
    {
      "name"         => "Project read access",
      "project"      => project,
      "permission"   => "REPO_READ",
      "members"      => [user_url],
      "repositories" => [repository_url]
    }
  end

  subject(:serializer) { described_class.new }

  describe "#serialize", :time_helpers do
    subject { serializer.serialize(team) }

    it "returns a serialized Team hash" do
      expected = {
        "type" => "team",
        "url" => "https://example.com/admin/groups/view?name=Project%2520read%2520access#MIGR8",
        "organization" => "https://example.com/projects/MIGR8",
        "name" => "Project read access",
        "permissions" => [
          {
            "repository" => "https://example.com/projects/MIGR8/repos/hugo-pages",
            "access" => "pull"
          }
        ],
        "members" => [
          {
            "user" => "https://example.com/users/unit-test",
            "role" => "member",
          },
        ],
        "created_at" => current_time
      }

      expect(subject).to eq(expected)
    end
  end
end
