# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::DiffHunkPositioner, :pull_request_helpers do
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

  let(:repository_exporter) do
    BbsExporter::RepositoryExporter.new(
      repository_model,
      current_export: current_export
    )
  end

  def diff_from_activity(activity)
    exporter = BbsExporter::PullRequestReviewCommentExporter.new(
      repository_exporter: repository_exporter,
      pull_request_model:  pull_request_model,
      activity:            activity
    )

    exporter.diff
  end

  def positioner_for_comment(comment_text)
    activity = comment_activity_start_with(activities, comment_text)
    diff = diff_from_activity(activity)

    described_class.new(
      diff:     diff,
      activity: activity
    )
  end

  describe "#comment_position" do
    # This is the GitHub diff hunk being used for these tests.
    #
    # Pos | Context line
    # ----|-------------------------------------------------------
    # n/a | @@ -2,7 +2,6 @@ source 'https://rubygems.org'
    # 1   |
    # 2   |  gem "rails",                 "4.2.6"
    # 3   |
    # 4   | -gem "coffee-rails",          "~> 4.1.0"
    # 5   |  gem "jbuilder",              "~> 2.0"
    # 6   |  gem "sass-rails",            "~> 5.0"
    # 7   |  gem "uglifier",              ">= 1.3.0"
    # n/a | @@ -12,7 +11,6 @@ gem "omniauth-github",       "1.1.2"
    # 9   |  gem "puma",                  "3.4.0"
    # 10  |
    # 11  |  group :development, :test do
    # 12  | -  gem "byebug"
    # 13  |    gem "dotenv-rails"
    # 14  |    gem "rspec-rails"
    # 15  |    gem "sqlite3"

    subject(:diff_hunk_positioner) do
      described_class.new(
        diff:       diff,
        activity:   activity,
        comment_id: comment_id
      )
    end

    let(:diff) { diff_Gemfile_0633a65_713644a }
    let(:activity) { comment_activity_start_with(activities, "Comment on line 3.") }
    let(:comment_id) { nil }

    before(:each) do
      allow(pull_request_model).to receive(:diff).with(
        "Gemfile",
        src_path:  nil,
        diff_type: "COMMIT",
        since_id:  "0633a65a0d2865ebc045455d19c97602d7414120",
        until_id:  "713644a829b9c2f724ae04b22285aa78b5c5616a"
      ).and_return(diff_Gemfile_0633a65_713644a)
    end

    context "when a comment is above the first context" do
      subject(:diff_hunk_positioner) do
        positioner_for_comment("Comment on line 1.")
      end

      it "#position should be the first position" do
        expect(diff_hunk_positioner.position).to eq(1)
      end

      it "#moved? should be true" do
        expect(diff_hunk_positioner.moved?).to be_truthy
      end

      it "#path should be Gemfile" do
        expect(diff_hunk_positioner.path).to eq("Gemfile")
      end
    end

    context "when a comment is on the first line of the first context" do
      it "#position should be an equivalent position" do
        expect(diff_hunk_positioner.position).to eq(2)
      end

      it "#moved? should be false" do
        expect(diff_hunk_positioner.moved?).to be_falsey
      end

      it "#path should be Gemfile" do
        expect(diff_hunk_positioner.path).to eq("Gemfile")
      end
    end

    context "when a comment is on a removed line" do
      subject(:diff_hunk_positioner) do
        positioner_for_comment("Comment on (removed) line 5.")
      end

      it "#position should be an equivalent position" do
        expect(diff_hunk_positioner.position).to eq(4)
      end

      it "#moved? should be false" do
        expect(diff_hunk_positioner.moved?).to be_falsey
      end

      it "#path should be Gemfile" do
        expect(diff_hunk_positioner.path).to eq("Gemfile")
      end
    end

    context "when a comment is on the last line of an upper context segment" do
      subject(:diff_hunk_positioner) do
        positioner_for_comment("Comment on line 8.")
      end

      it "#position should be an equivalent position" do
        expect(diff_hunk_positioner.position).to eq(7)
      end

      it "#moved? should be false" do
        expect(diff_hunk_positioner.moved?).to be_falsey
      end

      it "#path should be Gemfile" do
        expect(diff_hunk_positioner.path).to eq("Gemfile")
      end
    end

    context "when a comment is between contexts and closer to the top" do
      subject(:diff_hunk_positioner) do
        positioner_for_comment("Comment on line 9.")
      end

      it "#position should be the last position on the context above" do
        expect(diff_hunk_positioner.position).to eq(7)
      end

      it "#moved? should be true" do
        expect(diff_hunk_positioner.moved?).to be_truthy
      end

      it "#path should be Gemfile" do
        expect(diff_hunk_positioner.path).to eq("Gemfile")
      end
    end

    context "when a comment is between contexts and closer to the bottom" do
      subject(:diff_hunk_positioner) do
        positioner_for_comment("Comment on line 11.")
      end

      it "#position to the first position on the context below" do
        expect(diff_hunk_positioner.position).to eq(9)
      end

      it "#moved? should be true" do
        expect(diff_hunk_positioner.moved?).to be_truthy
      end

      it "#path should be Gemfile" do
        expect(diff_hunk_positioner.path).to eq("Gemfile")
      end
    end

    context "when a comment is on the first line of a lower context segment" do
      subject(:diff_hunk_positioner) do
        positioner_for_comment("Comment on line 12.")
      end

      it "#position should be an equivalent position" do
        expect(diff_hunk_positioner.position).to eq(9)
      end

      it "#moved? should be false" do
        expect(diff_hunk_positioner.moved?).to be_falsey
      end

      it "#path should be Gemfile" do
        expect(diff_hunk_positioner.path).to eq("Gemfile")
      end
    end

    context "when a comment is on the last line of the last context" do
      subject(:diff_hunk_positioner) do
        positioner_for_comment("Comment on line 18.")
      end

      it "#position should be an equivalent position" do
        expect(diff_hunk_positioner.position).to eq(15)
      end

      it "#moved? should be false" do
        expect(diff_hunk_positioner.moved?).to be_falsey
      end

      it "#path should be Gemfile" do
        expect(diff_hunk_positioner.path).to eq("Gemfile")
      end
    end

    context "when a comment is below the last context" do
      subject(:diff_hunk_positioner) do
        positioner_for_comment("Comment on line 25.")
      end

      it "#position should be the last position" do
        expect(diff_hunk_positioner.position).to eq(15)
      end

      it "#moved? should be true" do
        expect(diff_hunk_positioner.moved?).to be_truthy
      end

      it "#path should be Gemfile" do
        expect(diff_hunk_positioner.path).to eq("Gemfile")
      end
    end

    context "when provided a nil diff" do
      let(:diff) { nil }

      it "is not moved" do
        expect(subject.moved?).to be_falsey
      end

      it "returns a nil position" do
        expect(subject.position).to be_nil
      end

      it "returns a nil path" do
        expect(subject.path).to be_nil
      end
    end

    context "when a diff item has no \"hunks\" key" do
      let(:diff) { { "diffs" => [{}] } }

      it "is not moved" do
        expect(subject.moved?).to be_falsey
      end

      it "returns a nil position" do
        expect(subject.position).to be_nil
      end

      it "returns a nil path" do
        expect(subject.path).to be_nil
      end
    end
  end
end
