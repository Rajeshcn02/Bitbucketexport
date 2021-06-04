# frozen_string_literal: true

require "spec_helper"

describe BbsExporter do
  let(:archiver) { double(BbsExporter::ArchiveBuilder) }

  let(:repositories_from_list) do
    VCR.use_cassette("repositories-from-list") do
      repo_paths = current_export.send(
        :repo_paths_from_file,
        "spec/fixtures/export_list.csv"
      )

      current_export.send(:export_repositories, repo_paths)
    end
  end

  let(:repositories_from_list_faulty) do
    VCR.use_cassette("repositories-from-list-faulty") do
      repo_paths = current_export.send(
        :repo_paths_from_file,
        "spec/fixtures/export_list_faulty.csv"
      )

      current_export.send(:export_repositories, repo_paths)
    end
  end

  before(:each) do
    allow(current_export.archiver).to receive(:clone_repo)

    allow_any_instance_of(BitbucketServer::Repository).to receive(
      :attachment
    ).and_return(StringIO.new)
  end

  describe "#export_from_list" do
    subject { repositories_from_list }

    before(:each) do
      allow(current_export).to receive(:export_repository).and_call_original
    end

    it "fetches all repositories for the project" do
      expect(current_export).to_not receive(:repositories_for_user).with("personal-repo")

      subject
    end

    it "exports all specified repositories" do
      repository_paths = [
        "MIGR8/hugo-pages",
        "MIGR8/many-commits",
        "~unit-test/personal-repo"
      ]

      subject.zip(repository_paths).each do |repository_model, project_and_repo|
        expect(repository_model.project_and_repo).to eq(project_and_repo)
      end
    end
  end

  describe "#repositories_from_file" do
    subject { repositories_from_list }

    it "returns an array" do
      expect(subject).to be_an(Array)
    end

    it "contains an array of repositories" do
      subject.each do |repository|
        expect(repository).to be_a(BitbucketServer::Repository)
      end
    end

    it "returns all specified repositories" do
      expect(subject.length).to eq(3)
    end

    context "with a repository the current_export cannot find" do
      subject { repositories_from_list_faulty }

      it "returns an array" do
        expect(subject).to be_an(Array)
      end

      it "contains an array of repositories" do
        subject.each do |repository|
          expect(repository).to be_a(BitbucketServer::Repository)
        end
      end

      it "returns all valid repositories" do
        expect(subject.length).to eq(3)
      end

      it "does not raise an unhandled error" do
        expect { subject }.to_not raise_error
      end

      it "logs a message to the output" do
        expect(current_export.output_logger).to receive(:error).exactly(4).times
        subject
      end
    end
  end

  describe "#export" do
    let(:exporter) do
      described_class.new(
        bitbucket_server: bitbucket_server,
        options: {
          repositories: ["MIGR8/hugo-pages"],
          output_path:  "/tmp/test_export.tar.gz",
          progress_bar: false
        }
      )
    end

    before(:each) do
      allow(exporter.archiver).to receive(:clone_repo)
    end

    subject(:export) do
      VCR.use_cassette("complete_export") do
        exporter.export
      end
    end

    it "completes an export without error" do
      expect { subject }.to_not raise_error
    end

    context "--except teams" do
      before(:each) do
        allow(exporter).to receive(:models_to_export).and_return([])
      end

      it "does not export teams" do
        expect(exporter.team_builder).to_not receive(:write!)
        export
      end
    end
  end

  describe "#check_version!" do
    %w(5.0.0 5.0.1).each do |version|
      it "returns true for version #{version}" do
        allow(bitbucket_server).to receive(:version).and_return(
          "version" => version
        )

        expect {
          current_export.check_version!
        }.to_not raise_error
      end
    end

    %w(4.12 4.10 4.0).each do |version|
      it "raises an error for bad version #{version}" do
        allow(bitbucket_server).to receive(:version).and_return(
          "version" => version
        )

        expect {
          current_export.check_version!
        }.to raise_error(BbsExporter::BadVersion)
      end
    end
  end
end
