# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::ReleaseSerializer do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:pull_request_model) do
    repository_model.pull_request_model(1)
  end

  let(:tag) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/tags/end-of-sinatra") do
      repository_model.tag("end-of-sinatra")
    end
  end

  let(:repository) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/repository") do
      repository_model.repository
    end
  end

  let(:user) do
    VCR.use_cassette("users/unit-test") do
      bitbucket_server.user
    end
  end

  let(:commit) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/commit/1490680") do
      repository_model.commit("1490680b9a193ff188eb0dff7281b29869c62937")
    end
  end

  let(:tag_data) do
    tag.merge(
      "repository" => repository,
      "user"       => user,
      "commit"     => commit
    )
  end

  describe "#serialize" do
    subject { described_class.new.serialize(tag_data) }

    it "returns a serialized release hash" do
      expected = {
        type:              "release",
        url:               "https://example.com/projects/MIGR8/repos/hugo-pages/browse?at=refs/tags/end-of-sinatra",
        repository:        "https://example.com/projects/MIGR8/repos/hugo-pages",
        user:              "https://example.com/users/unit-test",
        name:              "end-of-sinatra",
        tag_name:          "end-of-sinatra",
        body:              "",
        state:             "published",
        pending_tag:       "end-of-sinatra",
        prerelease:        false,
        target_commitish:  "master",
        release_assets:    [],
        published_at:      "2016-05-10T13:06:10Z",
        created_at:        "2016-05-10T13:06:10Z"
      }

      expect(expected).to eq(subject)
    end
  end
end
