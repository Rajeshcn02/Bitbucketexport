# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::CommitCommentExporter do
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

  let(:diff_octocat_png_6150ca7_0633a65) do
    VCR.use_cassette(
      "projects/MIGR8/hugo-pages/diff/octocat_png_6150ca7_0633a65"
    ) do
      repository_model.diff(
        "0633a65a0d2865ebc045455d19c97602d7414120",
        since: "6150ca7e1fd18c96e2907a4ba31880e8b2329459"
      )
    end
  end

  let(:repository_exporter) do
    BbsExporter::RepositoryExporter.new(
      repository_model,
      current_export: current_export
    )
  end

  let(:line_comment) do
    find_line_comment(diff, "Commit comment on line 5.")
  end

  let(:commit_comment_diff) do
    BbsExporter::CommitComment::Line.new(
      repository: repository,
      commit_id:  "87fabe1ef09821868e789b5bde5b5cfb20c901fa",
      diff:       diff_README_md_fc40f82_87fabe1,
      comment:    line_comment
    )
  end

  let(:file_comment) do
    find_file_comment(diff, "File-level commit comment on README.md.")
  end

  let(:file_comment_binary) do
    find_file_comment(diff_binary, "Commit comment on binary file.")
  end

  let(:commit_comment_file) do
    BbsExporter::CommitComment::File.new(
      repository: repository,
      commit_id:  "87fabe1ef09821868e789b5bde5b5cfb20c901fa",
      diff_item:  diff,
      comment:    file_comment
    )
  end

  let(:commit_comment_file_binary) do
    BbsExporter::CommitComment::File.new(
      repository: repository,
      commit_id:  "0633a65a0d2865ebc045455d19c97602d7414120",
      diff_item:  diff_binary,
      comment:    file_comment_binary
    )
  end

  let(:commit_comment_exporter) do
    described_class.new(
      repository_exporter: repository_exporter,
      commit_comment:      commit_comment
    )
  end

  let(:diff) do
    diff_README_md_fc40f82_87fabe1["diffs"].first
  end

  let(:diff_binary) do
    diff_octocat_png_6150ca7_0633a65["diffs"].first
  end

  before(:each) do
    allow(repository_model).to receive(:repository).and_return(repository)
  end

  describe "#binary_file?", :commit_comment_helpers do
    context "for diff comments" do
      subject(:commit_comment) { commit_comment_diff }

      it "should be falsey" do
        expect(commit_comment_exporter.binary_file?).to be_falsey
      end
    end

    context "for file comments on a non-binary file" do
      subject(:commit_comment) { commit_comment_file }

      it "should be falsey" do
        expect(commit_comment_exporter.binary_file?).to be_falsey
      end
    end

    context "for file comments on a binary file" do
      subject(:commit_comment) { commit_comment_file_binary }

      it "should be truthy" do
        expect(commit_comment_exporter.binary_file?).to be_truthy
      end
    end
  end

  describe "#export", :commit_comment_helpers do
    subject(:_export) { commit_comment_exporter.export }

    context "for diff comments" do
      subject(:commit_comment) { commit_comment_diff }

      it "should serialize data" do
        expect(commit_comment_exporter).to receive(:serialize)
        commit_comment_exporter.export
      end

      context "for comments that should be moved" do
        subject(:commit_comment) { commit_comment_diff }

        it "should call comment_body_with_original_line" do
          expect(commit_comment_exporter.commit_comment).to receive(
            :comment_body_with_original_line
          ).with(4, "Commit comment on line 5.").and_call_original

          commit_comment_exporter.export
        end
      end
    end

    context "for file comments on a non-binary file" do
      subject(:commit_comment) { commit_comment_file }

      it "should serialize data" do
        expect(commit_comment_exporter).to receive(:serialize)
        commit_comment_exporter.export
      end

      it "should call comment_body_for_file_comment" do
        expect(commit_comment_exporter.commit_comment).to receive(
          :comment_body_for_file_comment
        ).and_call_original

        commit_comment_exporter.export
      end
    end

    context "for file comments on a binary file" do
      subject(:commit_comment) { commit_comment_file_binary }

      it "should call binary_file_warning" do
        expect(commit_comment_exporter).to receive(:binary_file_warning)
        commit_comment_exporter.export
      end

      it "should not serialize data" do
        expect(commit_comment_exporter).to_not receive(:serialize)
        commit_comment_exporter.export
      end
    end

    context "for diff commit comments with nil diff" do
      let(:commit_comment) do
        BbsExporter::CommitComment::Line.new(
          repository: repository,
          commit_id:  "87fabe1ef09821868e789b5bde5b5cfb20c901fa",
          diff:       nil,
          comment:    line_comment
        )
      end

      it { is_expected.to be_falsey }

      it "logs the validation exception" do
        expect(commit_comment_exporter).to receive(:log_exception).with(
          be_a(ActiveModel::ValidationError),
          message: "Unable to export commit comment, see logs for details",
          url: "https://example.com/projects/MIGR8/repos/hugo-pages/commits/87fabe1ef09821868e789b5bde5b5cfb20c901fa?commentId=97#commitcomment-97",
          model: include(commit_id: "87fabe1ef09821868e789b5bde5b5cfb20c901fa")
        )

        subject
      end

      it "should not serialize data" do
        commit_comment_exporter.export

        url = current_export.model_url_service.url_for_model(
          commit_comment_exporter.bbs_model,
          type: "commit_comment"
        )

        seen = current_export.archiver.seen?("commit_comment", url)

        expect(seen).to be_falsey
      end
    end

    context "for diff comments where a diff item has no \"hunks\" key" do
      let(:commit_comment) do
        BbsExporter::CommitComment::Line.new(
          repository: repository,
          commit_id:  "87fabe1ef09821868e789b5bde5b5cfb20c901fa",
          diff:       { "diffs" => [{}] },
          comment:    line_comment
        )
      end

      it { is_expected.to be_falsey }

      it "logs the validation exception" do
        expect(commit_comment_exporter).to receive(:log_exception).with(
          be_a(ActiveModel::ValidationError),
          message: "Unable to export commit comment, see logs for details",
          url: "https://example.com/projects/MIGR8/repos/hugo-pages/commits/87fabe1ef09821868e789b5bde5b5cfb20c901fa?commentId=97#commitcomment-97",
          model: include(commit_id: "87fabe1ef09821868e789b5bde5b5cfb20c901fa")
        )

        subject
      end
    end
  end

  describe "#attachment_exporter", :commit_comment_helpers do
    let(:commit_comment) { commit_comment_diff }

    subject(:attachment_exporter) do
      commit_comment_exporter.attachment_exporter
    end

    it "sets current_export to the correct value" do
      expect(attachment_exporter.current_export).to eq(
        commit_comment_exporter.current_export
      )
    end

    it "sets repository_model to the correct value" do
      expect(attachment_exporter.repository_model).to eq(
        commit_comment_exporter.repository_model
      )
    end

    it "sets parent_type to the correct value" do
      expect(attachment_exporter.parent_type).to eq(
        "commit_comment"
      )
    end

    it "sets parent_model to the correct value" do
      expect(attachment_exporter.parent_model).to eq(
        commit_comment_exporter.bbs_model
      )
    end

    it "sets attachment_exporter to the correct value" do
      expect(attachment_exporter.user).to eq(
        commit_comment_exporter.author_model
      )
    end

    it "sets body to the correct value" do
      expect(attachment_exporter.body).to eq(
        commit_comment_exporter.body
      )
    end

    it "sets created_date to the correct value" do
      expect(attachment_exporter.created_date).to eq(
        commit_comment_exporter.created_date
      )
    end
  end
end
