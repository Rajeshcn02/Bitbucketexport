# frozen_string_literal: true

require "spec_helper"

describe BitbucketServer::Project do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:project) do
    VCR.use_cassette("projects/MIGR8") do
      project_model.project
    end
  end

  let(:project_members) do
    VCR.use_cassette("projects/MIGR8/members") do
      project_model.members
    end
  end

  let(:user_project_model) do
    bitbucket_server.project_model("~unit-test")
  end

  describe "#key" do
    it "returns the project key" do
      expect(project_model.key).to eq("MIGR8")
    end
  end

  describe "#project" do
    it "returns a BitbucketServer Project" do
      expect(project).to eq(
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
      )
    end
  end

  describe "#members" do
    it "returns BitbucketServer Project members" do
      expect(project_members).to be_a(Array)

      expect(project_members.first).to eq(
        "user" => {
          "name"         => "dpmex4527",
          "emailAddress" => "dpmex4527@github.com",
          "id"           => 4,
          "displayName"  => "Daniel Perez",
          "active"       => true,
          "slug"         => "dpmex4527",
          "type"         => "NORMAL",
          "links"        => {
            "self" => [
              { "href" => "https://example.com/users/dpmex4527" }
            ]
          }
        },
        "permission" => "PROJECT_READ"
      )
    end
  end

  describe "#user_project?" do
    it "returns true for a user project" do
      expect(user_project_model.user_project?).to eq(true)
    end

    it "returns false on a non-user project" do
      expect(project_model.user_project?).to eq(false)
    end
  end

  describe "#repository_model" do
    it "creates a Repository model" do
      repository_model = project_model.repository_model("hugo-pages")
      expect(repository_model).to be_a(BitbucketServer::Repository)
    end
  end
end
