# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::TeamBuilder do
  let(:project_model_migr8) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:project_model_pub) do
    bitbucket_server.project_model("PUB")
  end

  let(:repository_model_migr8_hugo_pages) do
    project_model_migr8.repository_model("hugo-pages")
  end

  let(:repository_model_migr8_empty_repo) do
    project_model_migr8.repository_model("empty-repo")
  end

  let(:repository_model_pub_private_repo) do
    project_model_pub.repository_model("private-repo")
  end

  let(:project_migr8) do
    VCR.use_cassette("projects/MIGR8") do
      project_model_migr8.project
    end
  end

  let(:project_pub) do
    VCR.use_cassette("projects/PUB") do
      project_model_pub.project
    end
  end

  let(:repository_migr8_hugo_pages) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/repository") do
      repository_model_migr8_hugo_pages.repository
    end
  end

  let(:repository_migr8_empty_repo) do
    VCR.use_cassette("projects/MIGR8/empty-repo/repository") do
      repository_model_migr8_empty_repo.repository
    end
  end

  let(:repository_pub_private_repo) do
    VCR.use_cassette("projects/PUB/private-repo/repository") do
      repository_model_pub_private_repo.repository
    end
  end

  let(:user_synthead) do
    VCR.use_cassette("users/synthead") do
      bitbucket_server.user("synthead")
    end
  end

  let(:user_dpmex4527) do
    VCR.use_cassette("users/dpmex4527") do
      bitbucket_server.user("dpmex4527")
    end
  end

  let(:user_kylemacey) do
    VCR.use_cassette("users/kylemacey") do
      bitbucket_server.user("kylemacey")
    end
  end

  def create_member(user, permission = "PROJECT_READ")
    {
      "user"       => user,
      "permission" => permission
    }
  end

  subject(:team_builder) do
    described_class.new(current_export: current_export)
  end

  describe "#add_member" do
    it "stores data about the member added" do
      member_synthead = create_member(user_synthead)

      team_builder.add_member(
        project: project_migr8,
        member:  member_synthead
      )

      expect(team_builder.team_members).to eq(Set[{
        project: project_migr8,
        member:  member_synthead
      }])
    end

    it "will not duplicate information" do
      member_synthead = create_member(user_synthead)

      2.times do
        team_builder.add_member(
          project: project_migr8,
          member:  member_synthead
        )
      end

      expect(team_builder.team_members).to eq(Set[{
        project: project_migr8,
        member:  member_synthead
      }])
    end
  end

  describe "#add_repository" do
    it "stores the repository" do
      team_builder.add_repository(
        project:    project_migr8,
        repository: repository_migr8_hugo_pages
      )

      expect(team_builder.project_repositories).to eq(Set[{
        project:    project_migr8,
        repository: repository_migr8_hugo_pages
      }])
    end

    it "will not duplicate information" do
      2.times do
        team_builder.add_repository(
          project:    project_migr8,
          repository: repository_migr8_hugo_pages
        )
      end

      expect(team_builder.project_repositories).to eq(Set[{
        project:    project_migr8,
        repository: repository_migr8_hugo_pages
      }])
    end
  end

  describe "#teams", :time_helpers do
    it "builds team information from its member and repository data" do
      Timecop.freeze

      member_synthead = create_member(user_synthead)

      team_builder.add_member(
        project: project_migr8,
        member:  member_synthead
      )

      team_builder.add_repository(
        project:    project_migr8,
        repository: repository_migr8_hugo_pages
      )

      expect(team_builder.teams).to eq(
        [
          {
            "name"         => "project_read_access",
            "project"      => {
              "key"         => "MIGR8",
              "id"          => 2,
              "name"        => "Migrate Me",
              "description" => "Test project description",
              "public"      => false,
              "type"        => "NORMAL",
              "links"       => {
                "self" => [
                  { "href" => "https://example.com/projects/MIGR8" }
                ]
              }
            },
            "permission"   => "PROJECT_READ",
            "members"      => ["https://example.com/users/synthead"],
            "repositories" => [
              "https://example.com/projects/MIGR8/repos/hugo-pages/browse"
            ]
          }
        ]
      )
    end

    it "builds teams across multiple projects and access levels" do
      Timecop.freeze

      team_builder.add_member(
        project: project_migr8,
        member:  create_member(user_synthead, "PROJECT_WRITE")
      )

      team_builder.add_member(
        project: project_migr8,
        member:  create_member(user_dpmex4527, "PROJECT_WRITE")
      )

      team_builder.add_member(
        project: project_migr8,
        member:  create_member(user_kylemacey, "PROJECT_READ")
      )

      team_builder.add_repository(
        project:    project_migr8,
        repository: repository_migr8_hugo_pages
      )

      team_builder.add_repository(
        project:    project_migr8,
        repository: repository_migr8_empty_repo
      )

      team_builder.add_member(
        project: project_pub,
        member:  create_member(user_synthead, "PROJECT_ADMIN")
      )

      team_builder.add_repository(
        project:    project_pub,
        repository: repository_pub_private_repo
      )

      expect(team_builder.teams).to eq(
        [
          {
            "name"         => "project_write_access",
            "project"      => {
              "key"         => "MIGR8",
              "id"          => 2,
              "name"        => "Migrate Me",
              "description" => "Test project description",
              "public"      => false,
              "type"        => "NORMAL",
              "links"       => {
                "self" => [
                  { "href" => "https://example.com/projects/MIGR8" }
                ]
              }
            },
            "permission"   => "PROJECT_WRITE",
            "members"      => [
              "https://example.com/users/synthead",
              "https://example.com/users/dpmex4527"
            ],
            "repositories" => [
              "https://example.com/projects/MIGR8/repos/hugo-pages/browse",
              "https://example.com/projects/MIGR8/repos/empty-repo/browse"
            ]
          },
          {
            "name"         => "project_read_access",
            "project"      => {
              "key"         => "MIGR8",
              "id"          => 2,
              "name"        => "Migrate Me",
              "description" => "Test project description",
              "public"      => false,
              "type"        => "NORMAL",
              "links"       => {
                "self" => [
                  { "href" => "https://example.com/projects/MIGR8" }
                ]
              }
            },
            "permission"   => "PROJECT_READ",
            "members"      => ["https://example.com/users/kylemacey"],
            "repositories" => [
              "https://example.com/projects/MIGR8/repos/hugo-pages/browse",
              "https://example.com/projects/MIGR8/repos/empty-repo/browse"
            ]
          },
          {
            "name"         => "project_admin_access",
            "project"      => {
              "key"    => "PUB",
              "id"     => 43,
              "name"   => "public-project",
              "public" => true,
              "type"   => "NORMAL",
              "links"  => {
                "self" => [
                  { "href" => "https://example.com/projects/PUB" }
                ]
              }
            },
            "permission"   => "PROJECT_ADMIN",
            "members"      => ["https://example.com/users/synthead"],
            "repositories" => [
              "https://example.com/projects/PUB/repos/private-repo/browse"
            ]
          }
        ]
      )
    end
  end

  describe "#write!", :time_helpers do
    it "writes serialized data to the archive" do
      team_builder.add_member(
        project: project_migr8,
        member:  create_member(user_synthead, "PROJECT_WRITE")
      )

      Timecop.freeze

      expected_serialized_data = {
        model_name: "team",
        data: {
          "created_at"   => current_time,
          "members"      => [
            {
              "role" => "member",
              "user" => "https://example.com/users/synthead"
            }
          ],
          "name"         => "project_write_access",
          "organization" => "https://example.com/projects/MIGR8",
          "permissions"  => [],
          "type"         => "team",
          "url"          => "https://example.com/admin/groups/view?name=project_write_access#MIGR8"
        }
      }

      expect(team_builder.archiver).to receive(:write).with(
        expected_serialized_data
      )

      team_builder.write!
    end
  end
end
