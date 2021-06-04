# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::CommitCommentSerializer do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:repository) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/repository") do
      repository_model.repository
    end
  end

  let(:diff_README_md_fc40f82_87fabe1) do
    VCR.use_cassette(
      "projects/MIGR8/hugo-pages/diff/README_md_fc40f82_87fabe1"
    ) do
      repository_model.diff(
        "87fabe1ef09821868e789b5bde5b5cfb20c901fa",
        since: "fc40f8230aab1a10e16c70b2706e2d2a6164eea0"
      )
    end
  end

  let(:repository_exporter) do
    BbsExporter::RepositoryExporter.new(
      repository_model,
      current_export: current_export
    )
  end

  let(:commit_comment_exporter) do
    BbsExporter::CommitCommentExporter.new(
      repository_exporter: repository_exporter,
      commit_id:           "87fabe1ef09821868e789b5bde5b5cfb20c901fa",
      diff:                diff_README_md_fc40f82_87fabe1,
      comment:             comment,
      file_comment:        false,
      path:                path
    )
  end

  let(:diff) do
    diff_README_md_fc40f82_87fabe1["diffs"].first
  end

  let(:path) { "README.md" }

  let(:comment) { find_line_comment(diff, "Commit comment on merge commit.") }

  let(:author_model) do
    {
      "links" => {
        "self" => [{ "href" => "https://example.com/users/synthead" }]
      }
    }
  end

  let(:commit_comment_data) do
    {
      repository: repository,
      comment:    comment,
      position:   4,
      body:       comment["text"],
      author:     author_model,
      commit_id:  "87fabe1ef09821868e789b5bde5b5cfb20c901fa",
      path:       path
    }
  end

  describe "#serialize", :time_helpers, :commit_comment_helpers do
    let(:commit_comment_serializer) { described_class.new }

    subject(:serialized_data) do
      commit_comment_serializer.serialize(commit_comment_data)
    end

    it "returns a serialized CommitComment hash" do
      expected = {
        body:              "Commit comment on merge commit.",
        commit_id:         "87fabe1ef09821868e789b5bde5b5cfb20c901fa",
        created_at:        "2018-11-30T20:19:59Z",
        formatter:         "markdown",
        path:              "README.md",
        position:          4,
        repository:        "https://example.com/projects/MIGR8/repos/hugo-pages",
        type:              "commit_comment",
        url:               "https://example.com/projects/MIGR8/repos/hugo-pages/commits/87fabe1ef09821868e789b5bde5b5cfb20c901fa?commentId=94#commitcomment-94",
        user:              "https://example.com/users/synthead",
      }

      expect(serialized_data).to eq(expected)
    end
  end
end
