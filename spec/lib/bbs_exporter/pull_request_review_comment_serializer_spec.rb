# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::PullRequestReviewCommentSerializer, :pull_request_helpers do
  subject(:pull_request_review_comment_serializer) { described_class.new }

  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:pull_request_model) do
    repository_model.pull_request_model(6)
  end

  let(:pull_request) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/pull_requests/6") do
      pull_request_model.pull_request
    end
  end

  let(:activities) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/pull_requests/6/activities") do
      pull_request_model.activities
    end
  end

  let(:activity) do
    comment_activity_start_with(activities, "Comment on newline.")
  end

  let(:comment) do
    activity["comment"]
  end

  let(:pull_request_review_comment_data) do
    {
      pull_request:   pull_request,
      activity:       activity,
      comment:        comment,
      parent_comment: nil,
      commit_id:      "ace0ddae7cc4f2967e9cefafdafb1aa5c65f3ea0",
      position:       2,
      body:           comment["text"],
      diff_hunk:      nil
    }
  end

  describe "#serialize", :time_helpers do
    subject(:serialized_data) do
      pull_request_review_comment_serializer.serialize(pull_request_review_comment_data)
    end

    it "returns a serialized PullRequestReviewComment hash" do
      expected = {
        type:                "pull_request_review_comment",
        url:                 "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/6/overview?commentId=87#r87",
        pull_request:        "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/6",
        pull_request_review: "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/6#synthead-ace0ddae7cc4f2967e9cefafdafb1aa5c65f3ea0",
        in_reply_to:         nil,
        user:                "https://example.com/users/synthead",
        body:                "Comment on newline.",
        formatter:           "markdown",
        path:                "app/views/layouts/application.html.erb",
        commit_id:           "ace0ddae7cc4f2967e9cefafdafb1aa5c65f3ea0",
        original_position:   2,
        position:            2,
        diff_hunk:           nil,
        state:               1,
        created_at:          "2018-11-28T01:19:43Z",
      }

      expect(serialized_data).to eq(expected)
    end
  end

  describe "validations" do
    subject(:serialized_data) do
       -> { pull_request_review_comment_serializer.serialize(pull_request_review_comment_data) }
    end

    context "with a position" do
      before { pull_request_review_comment_data[:position] = 2 }

      context "with a diff hunk" do
        before { pull_request_review_comment_data[:diff_hunk] = "loremipsum" }

        it { is_expected.to_not raise_error }
      end

      context "without a diff hunk" do
        before { pull_request_review_comment_data.delete(:diff_hunk) }

        it { is_expected.to_not raise_error }
      end
    end

    context "without a position" do
      before { pull_request_review_comment_data.delete(:position) }

      context "with a diff hunk" do
        before { pull_request_review_comment_data[:diff_hunk] = "loremipsum" }

        it { is_expected.to_not raise_error }
      end

      context "without a diff hunk" do
        before { pull_request_review_comment_data.delete(:diff_hunk) }

        it { is_expected.to raise_error(ActiveModel::ValidationError) }
      end
    end
  end
end
