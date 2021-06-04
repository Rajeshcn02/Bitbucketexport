# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::PullRequestHelpers, :pull_request_helpers do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:pull_request_model) do
    repository_model.pull_request_model(6)
  end

  let(:activities) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/pull_requests/6/activities") do
      pull_request_model.activities
    end
  end

  let(:commit_713644a) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/commit/713644a") do
      repository_model.commit("713644a829b9c2f724ae04b22285aa78b5c5616a")
    end
  end

  let(:regular_comment_activity) do
    comment_activity_start_with(activities, "Regular comment.")
  end

  let(:file_comment_activity) do
    comment_activity_start_with(activities, "File comment.")
  end

  let(:commit_diff_comment_activity) do
    comment_activity_start_with(activities, "COMMIT type comment on line 8.")
  end

  let(:effective_diff_comment_activity) do
    comment_activity_start_with(activities, "Comment on line 18.")
  end

  let(:opened_activity) do
    activities.detect { |a| a["action"] == "OPENED" }
  end

  describe "#commented?" do
    context "for an activity that contains a regular comment" do
      subject(:activity) { regular_comment_activity }

      it "returns true" do
        commented = commented?(activity)
        expect(commented).to eq(true)
      end
    end

    context "for an activity that contains a file comment" do
      subject(:activity) { file_comment_activity }

      it "returns true" do
        commented = commented?(activity)
        expect(commented).to eq(true)
      end
    end

    context "for an activity that contains a COMMIT diff comment" do
      subject(:activity) { commit_diff_comment_activity }

      it "returns true" do
        commented = commented?(activity)
        expect(commented).to eq(true)
      end
    end

    context "for an activity that contains an EFFECTIVE diff comment" do
      subject(:activity) { effective_diff_comment_activity }

      it "returns true" do
        commented = commented?(activity)
        expect(commented).to eq(true)
      end
    end

    context "for an activity that does not contain a comment" do
      subject(:activity) { opened_activity }

      it "returns false" do
        commented = commented?(activity)
        expect(commented).to eq(false)
      end
    end
  end

  describe "#comment?" do
    context "for an activity that contains a regular comment" do
      subject(:activity) { regular_comment_activity }

      it "returns true" do
        commented = comment?(activity)
        expect(commented).to eq(true)
      end
    end

    context "for an activity that contains a file comment" do
      subject(:activity) { file_comment_activity }

      it "returns false" do
        commented = comment?(activity)
        expect(commented).to eq(false)
      end
    end

    context "for an activity that contains a COMMIT diff comment" do
      subject(:activity) { commit_diff_comment_activity }

      it "returns false" do
        commented = comment?(activity)
        expect(commented).to eq(false)
      end
    end

    context "for an activity that contains an EFFECTIVE diff comment" do
      subject(:activity) { effective_diff_comment_activity }

      it "returns false" do
        commented = comment?(activity)
        expect(commented).to eq(false)
      end
    end

    context "for an activity that does not contain a comment" do
      subject(:activity) { opened_activity }

      it "returns false" do
        commented = comment?(activity)
        expect(commented).to eq(false)
      end
    end
  end

  describe "#file_comment?" do
    context "for an activity that contains a regular comment" do
      subject(:activity) { regular_comment_activity }

      it "returns false" do
        commented = file_comment?(activity)
        expect(commented).to eq(false)
      end
    end

    context "for an activity that contains a file comment" do
      subject(:activity) { file_comment_activity }

      it "returns true" do
        commented = file_comment?(activity)
        expect(commented).to eq(true)
      end
    end

    context "for an activity that contains a COMMIT diff comment" do
      subject(:activity) { commit_diff_comment_activity }

      it "returns false" do
        commented = file_comment?(activity)
        expect(commented).to eq(false)
      end
    end

    context "for an activity that contains an EFFECTIVE diff comment" do
      subject(:activity) { effective_diff_comment_activity }

      it "returns false" do
        commented = file_comment?(activity)
        expect(commented).to eq(false)
      end
    end

    context "for an activity that does not contain a comment" do
      subject(:activity) { opened_activity }

      it "returns false" do
        commented = file_comment?(activity)
        expect(commented).to eq(false)
      end
    end
  end

  describe "#diff_comment?" do
    context "for an activity that contains a regular comment" do
      subject(:activity) { regular_comment_activity }

      it "returns false" do
        commented = diff_comment?(activity)
        expect(commented).to eq(false)
      end
    end

    context "for an activity that contains a file comment" do
      subject(:activity) { file_comment_activity }

      it "returns false" do
        commented = diff_comment?(activity)
        expect(commented).to eq(false)
      end
    end

    context "for an activity that contains a COMMIT diff comment" do
      subject(:activity) { commit_diff_comment_activity }

      it "returns true" do
        commented = diff_comment?(activity)
        expect(commented).to eq(true)
      end
    end

    context "for an activity that contains an EFFECTIVE diff comment" do
      subject(:activity) { effective_diff_comment_activity }

      it "returns true" do
        commented = diff_comment?(activity)
        expect(commented).to eq(true)
      end
    end

    context "for an activity that does not contain a comment" do
      subject(:activity) { opened_activity }

      it "returns false" do
        commented = diff_comment?(activity)
        expect(commented).to eq(false)
      end
    end
  end

  describe "#last_commit_id", :vcr do
    context "for a commit ID of an EFFECTIVE type" do
      let(:activity) { effective_diff_comment_activity }

      it "returns a commit ID of the latest commit" do
        to_hash = activity["commentAnchor"]["toHash"]
        commit_id = last_commit_id(to_hash)

        expect(commit_id).to eq("112e299ef8f06f951dde8ce105aad0252180cde0")
      end

    end

    context "when the target commit doesn't exist" do
      let(:commit_id) { "invalidcommit123456789" }

      it "returns nil" do
        expect(last_commit_id(commit_id)).to be_nil
      end
    end
  end

  describe "#commit_id_from_activity" do
    context "for a commit ID of a COMMIT type" do
      subject(:activity) { commit_diff_comment_activity }

      it "returns the toHash commit ID from the comment anchor" do
        to_hash = activity["commentAnchor"]["toHash"]
        commit_id = commit_id_from_activity(activity)

        expect(commit_id).to eq(to_hash)
      end
    end

    context "for a commit ID of an EFFECTIVE type" do
      subject(:activity) { effective_diff_comment_activity }

      it "returns the last commit ID from #last_commit_id", :vcr do
        to_hash = activity["commentAnchor"]["toHash"]
        expected_commit_id = commit_id_from_activity(activity)

        commit_id = commit_id_from_activity(activity)

        expect(commit_id).to eq(expected_commit_id)
      end
    end
  end
end
