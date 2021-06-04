# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::RepositorySerializer do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:project_repository) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/repository") do
      repository_model.repository
    end
  end

  let(:repository_team_members) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/collaborators") do
      repository_model.team_members
    end
  end

  let(:repository_access_keys) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/access_keys") do
      repository_model.access_keys
    end
  end

  let(:repository_data) do
    repository.merge(
      "collaborators" => repository_team_members,
      "access_keys"   => repository_access_keys
    )
  end

  subject { described_class.new }

  describe "#serialize" do
    subject { described_class.new.serialize(repository_data) }

    context "when owned by a project" do

      let(:repository) { project_repository }

      let(:project) do
        VCR.use_cassette("projects/MIGR8") do
          project_model.project
        end
      end

      context "when a project is provided" do
        before(:each) do
          repository_data["owner"] = project
        end

        it "returns a serialized Repository hash with an owner" do
          expected = {
            type:            "repository",
            url:             "https://example.com/projects/MIGR8/repos/hugo-pages",
            owner:           "https://example.com/projects/MIGR8",
            name:            "hugo-pages",
            description:     nil,
            website:         nil,
            private:         true,
            has_issues:      false,
            has_wiki:        false,
            has_downloads:   false,
            labels:          [],
            created_at:      "2017-05-26T05:01:08Z",
            git_url:         "tarball://root/repositories/MIGR8/hugo-pages.git",
            wiki_url:        nil,
            default_branch:  "master"
          }

          subject[:created_at] = "2017-05-26T05:01:08Z"

          expected.each do |key, value|
            expect(subject[key]).to eq(value), "`#{key}` does not match \n\n  expected: #{value.inspect}\n       got: #{subject[key].inspect}\n"
          end
        end
      end

      context "when a public project is provided" do
        let(:project_model) do
          bitbucket_server.project_model("PUB")
        end

        let(:repository_model) do
          project_model.repository_model("private-repo")
        end

        let(:project) do
          VCR.use_cassette("projects/PUB") do
            project_model.project
          end
        end

        let(:project_repository) do
          VCR.use_cassette("projects/PUB/private-repo/repository") do
            repository_model.repository
          end
        end

        let(:repository_data) do
          repository.merge(
            "collaborators" => {},
            "access_keys"   => {}
          )
        end

        before(:each) do
          repository_data["owner"] = project
        end

        it "returns a serialized Repository hash with overrided public setting" do
          expected = {
            type:            "repository",
            url:             "https://example.com/projects/PUB/repos/private-repo",
            owner:           "https://example.com/projects/PUB",
            name:            "private-repo",
            description:     nil,
            website:         nil,
            private:         false,
            has_issues:      false,
            has_wiki:        false,
            has_downloads:   false,
            created_at:      "2017-05-26T05:01:08Z",
            git_url:         "tarball://root/repositories/PUB/private-repo.git",
            wiki_url:        nil,
            default_branch:  "master"
          }

          subject[:created_at] = "2017-05-26T05:01:08Z"

          expected.each do |key, value|
            expect(subject[key]).to eq(value), "`#{key}` does not match \n\n  expected: #{value.inspect}\n       got: #{subject[key].inspect}\n"
          end
        end
      end

      context "when a project is not provided" do
        it "returns a serialized Repository hash without an owner" do
          expected = {
            type:            "repository",
            url:             "https://example.com/projects/MIGR8/repos/hugo-pages",
            name:            "hugo-pages",
            description:     nil,
            website:         nil,
            private:         true,
            has_issues:      false,
            has_wiki:        false,
            has_downloads:   false,
            created_at:      "2017-05-26T05:01:08Z",
            git_url:         "tarball://root/repositories/MIGR8/hugo-pages.git",
            wiki_url:        nil,
            default_branch:  "master"
          }

          subject[:created_at] = "2017-05-26T05:01:08Z"

          expected.each do |key, value|
            expect(subject[key]).to eq(value), "`#{key}` does not match \n\n  expected: #{value.inspect}\n       got: #{subject[key].inspect}\n"
          end
        end
      end
    end
  end
end
