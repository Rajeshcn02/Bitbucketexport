# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::PullRequestExporter do
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

  let(:commits) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/pull_requests/1/commits") do
      pull_request_model.commits
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

  let(:pull_request_exporter) do
    BbsExporter::PullRequestExporter.new(
      pull_request_model,
      repository_exporter: repository_exporter,
      project:             project
    )
  end

  let(:commit_1ed20cc) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/commit/1ed20cc") do
      repository_model.commit("1ed20cc335aa761425d8dd3543fd52f866f5d6a2")
    end
  end

  let(:diff_README_md_9b14a13_1ed20cc_params) do
    [
      "README.md",
      {
        src_path:  nil,
        diff_type: "COMMIT",
        since_id:  "9b14a132c4f6f27b1ef4bee034f79151d434756a",
        until_id:  "1ed20cc335aa761425d8dd3543fd52f866f5d6a2"
      }
    ]
  end

  let(:diff_README_md_9b14a13_1ed20cc) do
    VCR.use_cassette(
      "projects/MIGR8/hugo-pages/pull_requests/6/diff/README_md_9b14a13_1ed20cc"
    ) do
      pull_request_model.diff(*diff_README_md_9b14a13_1ed20cc_params)
    end
  end

  let(:diff_README_md_fc40f82_98bb793_params) do
    [
      "README.md",
      {
        src_path:  nil,
        diff_type: "COMMIT",
        since_id:  "fc40f8230aab1a10e16c70b2706e2d2a6164eea0",
        until_id:  "98bb7937d0bf95f194d52ac05352f3546b6240e8"
      }
    ]
  end

  let(:diff_README_md_fc40f82_98bb793) do
    VCR.use_cassette(
      "projects/MIGR8/hugo-pages/pull_requests/6/diff/README_md_fc40f82_98bb793"
    ) do
      pull_request_model.diff(*diff_README_md_fc40f82_98bb793_params)
    end
  end

  before(:each) do
    allow(repository_model).to receive(:repository).and_return(repository)
    allow(repository_model).to receive(:commit).with(
      "1ed20cc335aa761425d8dd3543fd52f866f5d6a2"
    ).and_return(commit_1ed20cc)

    allow(pull_request_model).to receive(:pull_request).and_return(pull_request)
    allow(pull_request_model).to receive(:commits).and_return(commits)
    allow(pull_request_model).to receive(:activities).and_return(activities)

    diffs = {
      diff_README_md_9b14a13_1ed20cc_params => diff_README_md_9b14a13_1ed20cc,
      diff_README_md_fc40f82_98bb793_params => diff_README_md_fc40f82_98bb793
    }

    allow(pull_request_model).to receive(:diff) { |f, p| diffs[[f, p]] }
  end

  describe "#initialize" do
    it "populates the commits for the pull request" do
      expect(pull_request_exporter.pull_request["commits"]).to_not be_empty
    end
  end

  describe "#model" do
    it "aliases to the pull_request" do
      expect(pull_request_exporter.model).to eq(
        pull_request_exporter.pull_request
      )
    end
  end

  describe "#repository" do
    it "returns the repository from the repository_exporter" do
      expect(pull_request_exporter.repository).to eq(repository)
    end
  end

  describe "#created_date" do
    it "returns the timestamp of when the pull_request was created" do
      expect(pull_request_exporter.created_date).to eq(1495567609873)
    end
  end

  describe "#grouped_diff_comment_activities" do
    context "from the activities in a pull request" do
      subject(:grouped_activities) do
        pull_request_exporter.grouped_diff_comment_activities
      end

      it "should return an array" do
        expect(grouped_activities).to be_an_instance_of(Array)
      end

      it "should group commit IDs and first activites correctly" do
        expect(grouped_activities.count).to eq(2)

        commit_id, activity = grouped_activities.first
        expect(commit_id).to eq("98bb7937d0bf95f194d52ac05352f3546b6240e8")
        expect(activity["id"]).to eq(209)

        commit_id, activity = grouped_activities.last
        expect(commit_id).to eq("98bb7937d0bf95f194d52ac05352f3546b6240e8")
        expect(activity["id"]).to eq(6)
      end
    end
  end

  describe "#export" do
    subject(:_export) { pull_request_exporter.export }

    it { is_expected.to be_truthy }

    it "should serialize the model" do
      expect(pull_request_exporter).to receive(:serialize).with(
        "pull_request", pull_request_exporter.pull_request
      )
      expect(pull_request_exporter).to receive(:serialize).with(
        "user", pull_request_exporter.pull_request["author"]["user"]
      )

      pull_request_exporter.export
    end

    it "should export all of the pull request comments" do
      expect(pull_request_exporter).to receive(
        :export_pull_request_comments
      ).once

      pull_request_exporter.export
    end

    it "should export pull request reviews" do
      expect(pull_request_exporter).to receive(
        :export_pull_request_reviews
      ).once

      pull_request_exporter.export
    end

    it "should export pull request review comments" do
      expect(pull_request_exporter).to receive(
        :export_pull_request_review_comments
      ).once

      pull_request_exporter.export
    end

    it "should export issue events" do
      expect(pull_request_exporter).to receive(
        :export_issue_events
      ).once

      pull_request_exporter.export
    end

    context "with an invalid Comment" do
      let(:comment) { pull_request_exporter.comment_activities.first }

      before { comment["comment"].delete("author") }

      it { is_expected.to be_truthy }
    end

    context "with an invalid Review Comment" do
      let(:review_comment) { pull_request_exporter.diff_comment_activities.first }

      before { review_comment.delete("user") }

      it { is_expected.to be_truthy }
    end

    context "with an invalid Review" do
      let(:review) { pull_request_exporter.review_activities.first }

      before { review.delete("user") }

      it { is_expected.to be_truthy }
    end
  end

  describe "#timestamped_commit_ids" do
    it "should use the author timestamp" do
      commits = [
        {
          "id"                 => "abcde",
          "authorTimestamp"    => 1000,
          "committerTimestamp" => 2000
        }
      ]

      allow(pull_request_model).to receive(:commits).and_return(commits)

      expected = { 1000 => "abcde" }
      expect(pull_request_exporter.timestamped_commit_ids).to eq(expected)
    end
  end

  describe "#commit_id_for_timestamp" do
    let(:timestamp) { 1555975351001 }

    it "returns the commit id previous to the provided timestamp" do
      expect(pull_request_exporter.commit_id_for_timestamp(timestamp))
        .to eq("b973fdcba0f85bf8556630d02ad9d6bef966a61e")
    end

    context "when no commit matches" do
      let(:timestamp) { 1495567557999 }

      it "returns nil" do
        expect(pull_request_exporter.commit_id_for_timestamp(timestamp)).to be_nil
      end
    end
  end

  describe "#attachment_exporter" do
    subject(:attachment_exporter) do
      pull_request_exporter.attachment_exporter
    end

    it "sets current_export to the correct value" do
      expect(attachment_exporter.current_export).to eq(
        pull_request_exporter.current_export
      )
    end

    it "sets repository_model to the correct value" do
      expect(attachment_exporter.repository_model).to eq(
        pull_request_exporter.repository_model
      )
    end

    it "sets parent_type to the correct value" do
      expect(attachment_exporter.parent_type).to eq(
        "pull_request"
      )
    end

    it "sets parent_model to the correct value" do
      expect(attachment_exporter.parent_model).to eq(
        pull_request_exporter.pull_request
      )
    end

    it "sets attachment_exporter to the correct value" do
      expect(attachment_exporter.user).to eq(
        pull_request_exporter.author
      )
    end

    it "sets body to the correct value" do
      expect(attachment_exporter.body).to eq(
        pull_request_exporter.description
      )
    end

    it "sets created_date to the correct value" do
      expect(attachment_exporter.created_date).to eq(
        pull_request_exporter.created_date
      )
    end
  end
end
