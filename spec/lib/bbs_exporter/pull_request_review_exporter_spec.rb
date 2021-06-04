# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::PullRequestReviewExporter do
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

  let(:commits) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/pull_requests/1/commits") do
      pull_request_model.commits
    end
  end

  let(:commit_1ed20cc) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/commit/1ed20cc") do
      repository_model.commit("1ed20cc335aa761425d8dd3543fd52f866f5d6a2")
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

  describe "#export", :pull_request_helpers do
    subject(:_export) { pr_review_exporter.export }

    let(:pr_review_exporter) do
      BbsExporter::PullRequestReviewExporter.new(
        repository_exporter: repository_exporter,
        pull_request_model:  pull_request_model,
        commit_id:           commit_id,
        activity:            activity
      )
    end

    let(:commit_id_and_activity) do
      grouped_activities = pull_request_exporter.grouped_diff_comment_activities
      grouped_activities.first
    end

    # TODO: Remove dependency on connascence of order
    let(:commit_id) { commit_id_and_activity[0] }
    let(:activity) { commit_id_and_activity[1] }


    before(:each) do
      allow(repository_model).to receive(:repository).and_return(
        repository
      )
      allow(repository_model).to receive(:commit).with(
        "1ed20cc335aa761425d8dd3543fd52f866f5d6a2"
      ).and_return(commit_1ed20cc)

      allow(pull_request_model).to receive(:pull_request).and_return(
        pull_request
      )
      allow(pull_request_model).to receive(:commits).and_return(commits)
      allow(pull_request_model).to receive(:activities).and_return(activities)
    end

    it { is_expected.to be_truthy }

    context "for grouped COMMENT actions" do
      it "should serialize grouped diff comment activities" do
        expected_model = {
          state:     1,
          commit_id: "98bb7937d0bf95f194d52ac05352f3546b6240e8"
        }

        expect(pr_review_exporter).to receive(:serialize).with(
          "pull_request_review", hash_including(expected_model)
        )

        subject
      end
    end

    context "for an APPROVED action" do
      let(:activity) do
        pull_request_exporter.review_activities.detect do |activity|
          activity["action"] == "APPROVED"
        end
      end

      it "should serialize review with state 1 and correct commit ID" do
        commit_id = pull_request_exporter.commit_id_for_timestamp(
          activity["createdDate"]
        )

        pr_review_exporter = BbsExporter::PullRequestReviewExporter.new(
          repository_exporter: repository_exporter,
          pull_request_model:  pull_request_model,
          commit_id:           commit_id,
          activity:            activity
        )

        expected_model = {
          state:     40,
          commit_id: "98bb7937d0bf95f194d52ac05352f3546b6240e8"
        }

        expect(pr_review_exporter).to receive(:serialize).with(
          "pull_request_review", hash_including(expected_model)
        )

        pr_review_exporter.export
      end
    end

    context "for an UNAPPROVED action" do
      let(:activity) do
        pull_request_exporter.review_activities.detect do |activity|
          activity["action"] == "UNAPPROVED"
        end
      end

      it "should serialize review with state 30 and correct commit ID" do
        commit_id = pull_request_exporter.commit_id_for_timestamp(
          activity["createdDate"]
        )

        pr_review_exporter = BbsExporter::PullRequestReviewExporter.new(
          repository_exporter: repository_exporter,
          pull_request_model:  pull_request_model,
          commit_id:           commit_id,
          activity:            activity
        )

        expected_model = {
          state:     30,
          commit_id: "98bb7937d0bf95f194d52ac05352f3546b6240e8"
        }

        expect(pr_review_exporter).to receive(:serialize).with(
          "pull_request_review", hash_including(expected_model)
        )

        pr_review_exporter.export
      end
    end

    context "with an invalid review" do
      before { activity.delete("createdDate") }

      it { is_expected.to be_falsey }

      it "logs the validation exception" do
        expect(pr_review_exporter).to receive(:log_exception).with(
          be_a(ActiveModel::ValidationError),
          message: "Unable to export review, see logs for details",
          url: "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/1#synthead-98bb7937d0bf95f194d52ac05352f3546b6240e8",
          model: include(commit_id: "98bb7937d0bf95f194d52ac05352f3546b6240e8")
        )

        subject
      end
    end
  end
end
