# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::IssueEventExporter do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:pull_request_model) do
    repository_model.pull_request_model(1)
  end

  let(:project) do
    VCR.use_cassette("projects/MIGR8") do
      project_model.project
    end
  end

  let(:repository) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/repository") do
      repository_model.repository
    end
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

  let(:repository_exporter) do
    BbsExporter::RepositoryExporter.new(
      repository_model,
      current_export: current_export
    )
  end

  let(:issue_event_exporter) do
    BbsExporter::IssueEventExporter.new(
      repository_exporter: repository_exporter,
      pull_request_model:  pull_request_model,
      activity:            activity
    )
  end

  describe "#export" do
    before(:each) do
      allow(pull_request_model).to receive(:pull_request).and_return(
        pull_request
      )
    end

    context "for DECLINED actions" do
      subject(:activity) do
        activities.detect { |a| a["action"] == "DECLINED" }
      end

      it "should export a closed issue event" do
        expect(issue_event_exporter).to receive(:serialize).with(
          "issue_event", hash_including(event: "closed")
        )

        issue_event_exporter.export
      end
    end

    context "for REOPENED actions" do
      subject(:activity) do
        activities.detect { |a| a["action"] == "REOPENED" }
      end

      it "should export a closed issue event" do
        expect(issue_event_exporter).to receive(:serialize).with(
          "issue_event", hash_including(event: "reopened")
        )

        issue_event_exporter.export
      end
    end
  end
end
