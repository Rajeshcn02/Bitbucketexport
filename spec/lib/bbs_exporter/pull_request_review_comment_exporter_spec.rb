# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::PullRequestReviewCommentExporter do
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

  let(:commit_713644a) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/commit/713644a") do
      repository_model.commit("713644a829b9c2f724ae04b22285aa78b5c5616a")
    end
  end

  let(:commit_70fd676) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/commits/70fd676") do
      repository_model.commit("70fd67684a9315f90874a3f4514f00872362875f")
    end
  end

  let(:commits) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/pull_requests/6/commits") do
      pull_request_model.commits
    end
  end

  let(:diff_Gemfile_0633a65_713644a) do
    VCR.use_cassette(
      "projects/MIGR8/hugo-pages/pull_requests/6/diff/Gemfile_0633a65_713644a"
    ) do
      pull_request_model.diff(
        "Gemfile",
        src_path:  nil,
        diff_type: "COMMIT",
        since_id:  "0633a65a0d2865ebc045455d19c97602d7414120",
        until_id:  "713644a829b9c2f724ae04b22285aa78b5c5616a"
      )
    end
  end

  let(:pull_request_model_merge_conflict) do
    repository_model.pull_request_model(11)
  end

  let(:pull_request_merge_conflict) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/pull_requests/11") do
      pull_request_model_merge_conflict.pull_request
    end
  end

  let(:activities_merge_conflict) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/pull_requests/11/activities") do
      pull_request_model_merge_conflict.activities
    end
  end

  let(:commits_merge_conflict) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/pull_requests/11/commits") do
      pull_request_model_merge_conflict.commits
    end
  end

  before(:each) do
    allow(pull_request_model).to receive(:commits).and_return(commits)
    allow(pull_request_model_merge_conflict).to receive(:commits).and_return(
      commits_merge_conflict
    )
  end

  let(:repository_exporter) do
    BbsExporter::RepositoryExporter.new(
      repository_model,
      current_export: current_export
    )
  end

  let(:activity) do
    comment_activity_start_with(activities, "Comment on line 3.")
  end

  let(:pr_review_comment_exporter) do
    BbsExporter::PullRequestReviewCommentExporter.new(
      repository_exporter: repository_exporter,
      pull_request_model:  pull_request_model,
      activity:            activity
    )
  end

  let(:pr_review_comment_exporter_merge_conflict) do
    BbsExporter::PullRequestReviewCommentExporter.new(
      repository_exporter: repository_exporter,
      pull_request_model:  pull_request_model_merge_conflict,
      activity:            activity
    )
  end

  let(:diff_Gemfile_0633a65_713644a_params) do
    [
      "Gemfile",
      {
        src_path:  nil,
        diff_type: "COMMIT",
        since_id:  "0633a65a0d2865ebc045455d19c97602d7414120",
        until_id:  "713644a829b9c2f724ae04b22285aa78b5c5616a"
      }
    ]
  end

  let(:diff_Gemfile_0633a65_713644a) do
    VCR.use_cassette(
      "projects/MIGR8/hugo-pages/pull_requests/6/diff/Gemfile_0633a65_713644a"
    ) do
      pull_request_model.diff(*diff_Gemfile_0633a65_713644a_params)
    end
  end

  let(:diff_octocat_png_ace0dda_112e299_params) do
    [
      "octocat.png",
      {
        src_path:  nil,
        diff_type: "COMMIT",
        since_id:  "ace0ddae7cc4f2967e9cefafdafb1aa5c65f3ea0",
        until_id:  "112e299ef8f06f951dde8ce105aad0252180cde0"
      }
    ]
  end

  let(:diff_octocat_png_ace0dda_112e299) do
    VCR.use_cassette(
      "projects/MIGR8/hugo-pages/pull_requests/6/diff/" \
      "octocat_png_ace0dda_112e299"
    ) do
      pull_request_model.diff(*diff_octocat_png_ace0dda_112e299_params)
    end
  end

  let(:diff_README_md_0633a65_70fd676_params) do
    [
      "README.md",
      {
        src_path:  nil,
        diff_type: "COMMIT",
        since_id:  "0633a65a0d2865ebc045455d19c97602d7414120",
        until_id:  "70fd67684a9315f90874a3f4514f00872362875f"
      }
    ]
  end

  let(:diff_README_md_0633a65_70fd676) do
    VCR.use_cassette(
      "projects/MIGR8/hugo-pages/pull_requests/11/diff/" \
      "README_md_0633a65_70fd676"
    ) do
      pull_request_model_merge_conflict.diff(
        *diff_README_md_0633a65_70fd676_params
      )
    end
  end

  describe "#diff", :pull_request_helpers do
    subject(:activity) do
      comment_activity_start_with(activities, "Comment on newline.")
    end

    it "should call the model's #diff with a full path" do
      expect(pull_request_model).to receive(:diff).with(
        "app/views/layouts/application.html.erb",
        src_path:  nil,
        diff_type: "COMMIT",
        since_id:  "99ece937f497284e663b81fc1ad6ff9fcddd8a7c",
        until_id:  "ace0ddae7cc4f2967e9cefafdafb1aa5c65f3ea0"
      )

      pr_review_comment_exporter.send(:diff)
    end
  end

  describe "#binary_file?", :pull_request_helpers do
    before(:each) do
      diffs = {
        diff_Gemfile_0633a65_713644a_params     => diff_Gemfile_0633a65_713644a,
        diff_octocat_png_ace0dda_112e299_params => diff_octocat_png_ace0dda_112e299
      }

      allow(pull_request_model).to receive(:diff) { |f, p| diffs[[f, p]] }
    end

    context "for file comments on a non-binary file" do
      subject(:activity) do
        comment_activity_start_with(activities, "File comment.")
      end

      it "should be falsey" do
        expect(pr_review_comment_exporter.binary_file?).to be_falsey
      end
    end

    context "for file comments on a binary file" do
      subject(:activity) do
        comment_activity_start_with(activities, "File comment on binary file.")
      end

      it "should return true" do
        expect(pr_review_comment_exporter.binary_file?).to be(true)
      end
    end

    context "for diff comments" do
      subject(:activity) do
        comment_activity_start_with(activities, "Comment on line 3.")
      end

      it "should be falsey" do
        expect(pr_review_comment_exporter.binary_file?).to be_falsey
      end
    end
  end

  describe "#export", :pull_request_helpers, :vcr do
    subject(:_export) { pr_review_comment_exporter.export }
    let(:activity) do
      comment_activity_start_with(activities, "Comment on line 3.")
    end

    it { is_expected.to be_truthy }

    context "for file comments on a non-binary file" do
      let(:activity) do
        comment_activity_start_with(activities, "File comment.")
      end

      it "should call comment_body_for_file_comment" do
        expect(pr_review_comment_exporter).to receive(
          :comment_body_for_file_comment
        ).and_call_original

        pr_review_comment_exporter.export
      end
    end

    context "for file comments on a binary file" do
      let(:activity) do
        comment_activity_start_with(activities, "File comment on binary file.")
      end

      it "should call binary_file_warning" do
        expect(pr_review_comment_exporter).to receive(:binary_file_warning)

        pr_review_comment_exporter.export
      end

      it "should not serialize data" do
        expect(pr_review_comment_exporter).to_not receive(:serialize)

        pr_review_comment_exporter.export
      end
    end

    context "for file comments on a merge conflict" do
      let(:activity) do
        comment_activity_start_with(
          activities_merge_conflict,
          "PR review comment on a merge conflict."
        )
      end

      it "should call merge_conflict_warning" do
        expect(pr_review_comment_exporter_merge_conflict).to receive(
          :merge_conflict_warning
        )

        pr_review_comment_exporter_merge_conflict.export
      end

      it "should not serialize data" do
        expect(pr_review_comment_exporter_merge_conflict).to_not receive(
          :serialize
        )

        pr_review_comment_exporter_merge_conflict.export
      end
    end

    context "for diff comments outside of GitHub context" do
      let(:activity) do
        comment_activity_start_with(activities, "Comment on line 1.")
      end

      it "should call comment_body_with_original_line" do
        expect(pr_review_comment_exporter).to receive(
          :comment_body_with_original_line
        ).and_call_original

        pr_review_comment_exporter.export
      end

      it "should serialize data" do
        expect(pr_review_comment_exporter).to receive(:serialize)
        pr_review_comment_exporter.export
      end
    end

    context "for diff comments inside of GitHub context" do
      let(:activity) do
        comment_activity_start_with(activities, "Comment on line 3.")
      end

      it "should not call comment_body_with_line_number" do
        expect(pr_review_comment_exporter).to_not receive(
          :comment_body_with_line_number
        )

        pr_review_comment_exporter.export
      end
    end


    context "with an invalid review comment" do
      before { activity["comment"].delete("author") }

      it { is_expected.to be_falsey }

      it "logs the validation exception" do
        expect(pr_review_comment_exporter).to receive(:log_exception).with(
          be_a(ActiveModel::ValidationError),
          message: "Unable to export review comment, see logs for details",
          url: "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/6/overview?commentId=49#r49",
          model: include(commit_id: "112e299ef8f06f951dde8ce105aad0252180cde0")
        )

        subject
      end
    end

    context "with an activity with an unreachable commit", :vcr do
      before { activity["commentAnchor"]["toHash"] = "invalidcommit123456789" }

      it { is_expected.to be_falsey }

      it "logs the validation exception" do
        subject
        expect(@_spec_output_log.string).to include("Unable to export review comment, see logs for details")
      end
    end

    context "when #diff returns nil" do
      before(:each) do
        allow(pr_review_comment_exporter).to receive(:diff)
      end

      it { is_expected.to be_falsey }

      it "logs the validation exception" do
        subject
        expect(@_spec_output_log.string).to include("Unable to export review comment, see logs for details")
      end

      it "should not serialize data" do
        pr_review_comment_exporter.export

        url = current_export.model_url_service.url_for_model(
          pr_review_comment_exporter.bbs_model,
          type: "pull_request_review_comment"
        )

        seen = current_export.archiver.seen?("pull_request_review_comment", url)

        expect(seen).to be(false)
      end
    end
  end

  describe "#moved?", :pull_request_helpers do
    context "when #diff returns nil" do
      it "should be falsey" do
        allow(pr_review_comment_exporter).to receive(:diff)

        expect(pr_review_comment_exporter.moved?).to be_falsey
      end
    end
  end

  describe "#position", :pull_request_helpers do
    context "when #diff returns nil" do
      it "should return nil" do
        allow(repository_model).to receive(:commit).with(
          "713644a829b9c2f724ae04b22285aa78b5c5616a"
        ).and_return(commit_713644a)

        allow(pr_review_comment_exporter).to receive(:diff)

        expect(pr_review_comment_exporter.position).to be_nil
      end
    end
  end

  describe "#comment_body_with_original_line", :pull_request_helpers do
    context "for a given activity" do
      subject(:activity) do
        comment_activity_start_with(activities, "Comment on line 1.")
      end

      it "includes the original comment body" do
        body = pr_review_comment_exporter.comment_body_with_original_line(
          activity["commentAnchor"]["line"],
          activity["comment"]["text"]
        )
        original_body = activity["comment"]["text"]

        expect(body.end_with?(original_body)).to eq(true)
      end
    end
  end

  describe "#comment_body_for_file_comment", :pull_request_helpers do
    context "for a given activity" do
      subject(:activity) do
        comment_activity_start_with(activities, "File comment.")
      end

      it "includes the original comment body" do
        body = pr_review_comment_exporter.comment_body_for_file_comment(
          activity["comment"]["text"]
        )
        original_body = activity["comment"]["text"]

        expect(body.end_with?(original_body)).to eq(true)
      end
    end
  end

  describe "#attachment_exporter", :pull_request_helpers do
    before(:each) do
      allow(repository_model).to receive(:commit).with(
        "713644a829b9c2f724ae04b22285aa78b5c5616a"
      ).and_return(commit_713644a)

      allow(pull_request_model).to receive(:diff).with(
        "Gemfile",
        src_path:  nil,
        diff_type: "COMMIT",
        since_id:  "0633a65a0d2865ebc045455d19c97602d7414120",
        until_id:  "713644a829b9c2f724ae04b22285aa78b5c5616a"
      ).and_return(diff_Gemfile_0633a65_713644a)

      allow(pull_request_model).to receive(:pull_request).and_return(
        pull_request
      )
    end

    let (:activity) do
      comment_activity_start_with(activities, "Comment on line 1.")
    end

    subject(:attachment_exporter) do
      pr_review_comment_exporter.attachment_exporter
    end

    it "sets current_export to the correct value" do
      expect(attachment_exporter.current_export).to eq(
        pr_review_comment_exporter.current_export
      )
    end

    it "sets repository_model to the correct value" do
      expect(attachment_exporter.repository_model).to eq(
        pr_review_comment_exporter.repository_model
      )
    end

    it "sets parent_type to the correct value" do
      expect(attachment_exporter.parent_type).to eq(
        "pull_request_review_comment"
      )
    end

    it "sets parent_model to the correct value" do
      expect(attachment_exporter.parent_model).to eq(
        pr_review_comment_exporter.bbs_model
      )
    end

    it "sets attachment_exporter to the correct value" do
      expect(attachment_exporter.user).to eq(
        pr_review_comment_exporter.author
      )
    end

    it "sets body to the correct value" do
      expect(attachment_exporter.body).to eq(
        pr_review_comment_exporter.text
      )
    end

    it "sets created_date to the correct value" do
      expect(attachment_exporter.created_date).to eq(
        pr_review_comment_exporter.created_date
      )
    end
  end
end
