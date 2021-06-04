# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::IssueEventSerializer do
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

  let(:activity) do
    activities.detect { |a| a["action"] == "DECLINED" }
  end

  let(:issue_event_model) do
    {
      pull_request: pull_request,
      event:        "closed",
      activity:     activity,
      activity_id:  284
    }
  end

  let(:issue_event_serializer) { described_class.new }

  describe "#serialize", :time_helpers do
    subject(:serialized_data) do
      issue_event_serializer.serialize(issue_event_model)
    end

    it "returns serialized issue event data" do
      expected = {
        type:         "issue_event",
        url:          "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/1#event-284",
        pull_request: "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/1",
        actor:        "https://example.com/users/synthead",
        event:        "closed",
        created_at:   "2018-11-29T23:39:37Z"
      }

      expect(serialized_data).to eq(expected)
    end
  end
end
