# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::ArchiveBuilder, :archive_helpers do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
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

  let(:project_model_651) do
    bitbucket_server.project_model("BBS651")
  end

  let(:repository_model_651) do
    project_model_651.repository_model("empty-repo")
  end

  let(:repository_651) do
    VCR.use_cassette("projects/BBS651/empty-repo/repository") do
      repository_model_651.repository
    end
  end

  subject { described_class.new(current_export: current_export) }
  let(:tarball_path) { Tempfile.new("string").path }
  let(:files) { file_list_from_archive(tarball_path) }

  it "makes a tarball with a json file" do
    subject.write(model_name: "mouse", data: {"foo" => "bar"})
    subject.create_tar(tarball_path)

    expect(files).to include("mice_000001.json")
  end

  it "adds a schema.json" do
    subject.create_tar(tarball_path)

    expect(files).to include("schema.json")

    dir = Dir.mktmpdir "archive_builder"

    json_data = read_file_from_archive(tarball_path, "schema.json")
    expect(JSON.load(json_data)).to eq({"version" => "1.2.0"})
  end

  it "adds a urls.json" do
    subject.create_tar(tarball_path)

    expect(files).to include("urls.json")
  end

  describe "#clone_repo" do
    it "can create a clone url" do
      expect(subject.send(:git)).to receive(:clone).with(
        hash_including(
          url: "https://unit-test@example.com/scm/migr8/hugo-pages.git"
        )
      )

      subject.clone_repo(repository)
    end
  end

  describe "#repo_clone_url" do
    it "adds usernames to URLs" do
      link = subject.send(:repo_clone_url, repository_651)

      expect(link).to eq(
        "https://unit-test@example.com/scm/bbs651/empty-repo.git"
      )
    end

    it "allows a user to be passed explicitly" do
      link = subject.send(:repo_clone_url, repository_651, user: "synthead")

      expect(link).to eq(
        "https://synthead@example.com/scm/bbs651/empty-repo.git"
      )
    end
  end
end
