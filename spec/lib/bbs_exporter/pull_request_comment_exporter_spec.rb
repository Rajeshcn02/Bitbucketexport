# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::PullRequestCommentExporter, :pull_request_helpers do
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

  let(:pull_request_comment_reply) do
    pull_request_comment["comments"].first
  end

  let(:bbs_model) do
    {
      pull_request:         pull_request,
      pull_request_comment: pull_request_comment
    }
  end

  let(:repository_exporter) do
    BbsExporter::RepositoryExporter.new(
      repository_model,
      current_export: current_export
    )
  end

  let(:pull_request_comment_exporter) do
    BbsExporter::PullRequestCommentExporter.new(
      pull_request:         pull_request,
      pull_request_comment: pull_request_comment,
      repository_exporter:  repository_exporter
    )
  end

  describe "#export" do
    subject(:_export) { pull_request_comment_exporter.export }

    it { is_expected.to be_truthy }

    it "serializes base comment" do
      expect(pull_request_comment_exporter).to receive(:serialize).with(
        "issue_comment", bbs_model
      )

      pull_request_comment_exporter.export
    end

    it "serializes comment replies" do
      allow(pull_request_comment_exporter).to receive(:serialize).with(
        "issue_comment", bbs_model
      )

      expect(BbsExporter::PullRequestCommentExporter).to receive(:new).with(
        pull_request:         pull_request,
        pull_request_comment: pull_request_comment_reply,
        repository_exporter:  repository_exporter
      ).and_call_original

      pull_request_comment_exporter.export
    end

    context "with an invalid comment" do
      before { pull_request_comment.delete("author") }

      it { is_expected.to be_falsey }

      it "logs the validation exception" do
        expect(pull_request_comment_exporter).to receive(:log_exception).with(
          be_a(ActiveModel::ValidationError),
          message: "Unable to export comment, see logs for details",
          url: "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/1/overview?commentId=2",
          model: pull_request_comment_exporter.bbs_model
        )

        subject
      end
    end
  end

  describe "#attachment_exporter" do
    subject(:attachment_exporter) do
      pull_request_comment_exporter.attachment_exporter
    end

    it "sets current_export to the correct value" do
      expect(attachment_exporter.current_export).to eq(
        pull_request_comment_exporter.current_export
      )
    end

    it "sets repository_model to the correct value" do
      expect(attachment_exporter.repository_model).to eq(
        pull_request_comment_exporter.repository_model
      )
    end

    it "sets parent_type to the correct value" do
      expect(attachment_exporter.parent_type).to eq(
        "issue_comment"
      )
    end

    it "sets parent_model to the correct value" do
      expect(attachment_exporter.parent_model).to eq(
        pull_request_comment_exporter.bbs_model
      )
    end

    it "sets attachment_exporter to the correct value" do
      expect(attachment_exporter.user).to eq(
        pull_request_comment_exporter.author
      )
    end

    it "sets body to the correct value" do
      expect(attachment_exporter.body).to eq(
        pull_request_comment_exporter.text
      )
    end

    it "sets created_date to the correct value" do
      expect(attachment_exporter.created_date).to eq(
        pull_request_comment_exporter.created_date
      )
    end
  end
end
