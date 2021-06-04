# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::ProtectedBranchSerializer do
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

  let(:branching_models) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/branching_models") do
      repository_model.branching_models
    end
  end

  let(:branches) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/branches") do
      repository_model.branches
    end
  end

  let(:branch_permissions) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/branch_permissions") do
      repository_model.branch_permissions
    end
  end

  let(:project) do
    VCR.use_cassette("projects/MIGR8") do
      project_model.project
    end
  end

  let(:repository_exporter) do
    BbsExporter::RepositoryExporter.new(
      repository_model,
      current_export: current_export
    )
  end

  let(:branch_permissions_exporter) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/repository") do
      BbsExporter::BranchPermissionsExporter.new(
        branch_permissions:  branch_permissions,
        branches:            branches,
        branching_models:    branching_models,
        repository_exporter: repository_exporter,
        project:             project
      )
    end
  end

  describe "#protected_branch_for_bugfix/branch-permissions-test" do
    subject(:serialized_data) do
      branch_name = "bugfix/branch-permissions-test"
      permissions = branch_permissions_exporter.branch_permissions_by_branch[
        branch_name
      ]

      described_class.new.serialize(
        "branch_name"        => branch_name,
        "branch_permissions" => permissions,
        "owner"              => project,
        "repository"         => repository
      )
    end

    it "has valid team URLs" do
      team_url = serialized_data[:authorized_team_urls].first

      expect(team_url).to eq(
        "https://example.com/admin/groups/view?name=test_group#MIGR8"
      )
    end

    it "combines branch permissions for users" do
      expect(serialized_data[:dismissal_restricted_user_urls].length).to eq(2)
    end

    it "combines branch permissions for teams" do
      expect(serialized_data[:dismissal_restricted_team_urls].length).to eq(1)
    end

    it "does not create duplicate users in permission type" do
      expect(serialized_data[:authorized_user_urls].length).to eq(1)
    end

    it "does not create duplicate teams in permission type" do
      expect(serialized_data[:authorized_team_urls].length).to eq(1)
    end

    it 'sets pull_request_reviews_enforcement_level to "everyone"' do
      expect(
        serialized_data[:pull_request_reviews_enforcement_level]
      ).to eq("everyone")
    end
  end

  describe "#protected_branch_for_bugfix/branch-permissions-test2" do
    subject(:serialized_data) do
      branch_name = "bugfix/branch-permissions-test2"
      permissions = branch_permissions_exporter.branch_permissions_by_branch[
        branch_name
      ]

      described_class.new.serialize(
        "branch_name"        => branch_name,
        "branch_permissions" => permissions,
        "owner"              => project,
        "repository"         => repository
      )
    end

    it 'sets pull_request_reviews_enforcement_level to "off"' do
      expect(
        serialized_data[:pull_request_reviews_enforcement_level]
      ).to eq("off")
    end
  end

  describe "#serialize" do
    subject(:protected_branch) do
      branch_permission = branch_permissions.detect do |permission|
        permission["matcher"]["type"]["id"] == "BRANCH"
      end

      branch_name = branch_permission["matcher"]["displayId"]

      {
        "branch_name"        => branch_name,
        "branch_permissions" => branch_permissions,
        "repository"         => repository
      }
    end

    it do
      serialized_data = described_class.new.serialize(protected_branch)

      expected = {
        type:                                     "protected_branch",
        name:                                     "bugfix/branch-permissions-test",
        url:                                      "https://example.com/plugins/servlet/branch-permissions/MIGR8/hugo-pages#bugfix/branch-permissions-test",
        repository_url:                           "https://example.com/projects/MIGR8/repos/hugo-pages",
        admin_enforced:                           true,
        block_deletions_enforcement_level:        2,
        block_force_pushes_enforcement_level:     2,
        dismiss_stale_reviews_on_push:            true,
        pull_request_reviews_enforcement_level:   "everyone",
        require_code_owner_review:                false,
        required_status_checks_enforcement_level: "off",
        strict_required_status_checks_policy:     false,
        authorized_actors_only:                   true,
        authorized_user_urls:                     ["https://example.com/users/synthead"],
        authorized_team_urls:                     ["https://example.com/admin/groups/view?name=test_group#MIGR8"],
        dismissal_restricted_user_urls:           ["https://example.com/users/synthead", "https://example.com/users/kylemacey"],
        dismissal_restricted_team_urls:           ["https://example.com/admin/groups/view?name=test_group#MIGR8"],
        required_status_checks:                   []
      }

      expect(expected).to eq(serialized_data)
    end
  end
end
