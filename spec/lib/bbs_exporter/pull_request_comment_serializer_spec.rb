# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::PullRequestCommentSerializer, :pull_request_helpers do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:pull_request_model) do
    repository_model.pull_request_model(1)
  end

  let(:pull_request) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/pull_requests/1") do
      pull_request_model.pull_request
    end
  end

  let(:activities) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/pull_requests/1/activities") do
      pull_request_model.activities
    end
  end

  let(:pull_request_comment) do
    activity = comment_activity_start_with(activities, "test PR comment")
    activity["comment"]
  end

  let(:bbs_model) do
    {
      pull_request:         pull_request,
      pull_request_comment: pull_request_comment
    }
  end

  describe "#serialize", :time_helpers do
    let(:pull_request_comment_serializer) { described_class.new }

    subject(:serialized_data) do
      pull_request_comment_serializer.serialize(bbs_model)
    end

    it "returns a serialized Issue comment hash" do
      expected = {
        type:         "issue_comment",
        url:          "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/1/overview?commentId=2",
        pull_request: "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/1",
        user:         "https://example.com/users/dpmex4527",
        body:         "test PR comment",
        formatter:    "markdown",
        created_at:   "2017-05-23T19:26:59Z"
      }

      expect(serialized_data).to eq(expected)
    end
  end
end
