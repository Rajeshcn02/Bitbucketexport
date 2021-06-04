# frozen_string_literal: true

require "spec_helper"

# BranchPermissionsExporter casts the various Bitbucket Server branch
# permission types as individual GitHub protected branches.  This is fairly
# complicated, so we are doing very thorough tests to ensure nothing breaks.
# To DRY things up, we're including a variety of helpers to help with the
# tests.  See the comments in BranchPermissionsExporter for more information.

include BranchPermissionsExporterHelpers

describe BbsExporter::BranchPermissionsExporter do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:repository_exporter) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/repository") do
      exporter = BbsExporter::RepositoryExporter.new(
        repository_model,
        current_export: current_export
      )

      exporter.repository

      exporter
    end
  end

  let(:branch_permissions) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/branch_permissions") do
      repository_model.branch_permissions
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

  let(:repository) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/repository") do
      repository_model.repository
    end
  end

  let(:project) do
    VCR.use_cassette("projects/MIGR8") do
      project_model.project
    end
  end

  describe "#branch_names" do
    it "includes permissions by branch name" do
      branch_permissions = branch_permissions_from_matchers(
        "BRANCH" => "bugfix/that/cool/perm-test"
      )
      exporter = branch_permissions_exporter(
        branch_permissions: branch_permissions
      )

      expect(exporter).to receive(:serialize).exactly(:once)

      exporter.export
    end

    it "are not exported when inactive" do
      branch_permission = branch_permission_from_matcher(
        "BRANCH",
        "bugfix/that/cool/perm-test",
        active: false
      )
      exporter = branch_permissions_exporter(
        branch_permissions: [branch_permission]
      )

      expect(exporter).not_to receive(:serialize)

      exporter.export
    end
  end

  describe "#branch_patterns" do
    branch = "bugfix/that/cool/perm-test"
    branches = branches_from_branch_names(branch)

    expected_branch_pattern_results = {
      "*"                                     => true,
      "**"                                    => true,
      "**/perm-test"                          => true,
      "**cool**"                              => false,
      "**perm-test"                           => false,
      "**test"                                => false,
      "*test"                                 => true,
      "bug**"                                 => false,
      "bug***"                                => false,
      "bugfix"                                => false,
      "bugfix**"                              => false,
      "bugfix/**"                             => true,
      "bugfix/th**/perm-test"                 => false,
      "bugfix/th**ol/perm-test"               => false,
      "bugfix/that/c**/perm-test"             => true,
      "bugfix/that/c*/perm-test"              => true,
      "cool"                                  => false,
      "cool**"                                => false,
      "cool/perm-test"                        => true,
      "perm*"                                 => true,
      "perm**"                                => true,
      "perm-test**"                           => true,
      "refs"                                  => false,
      "refs/heads/*"                          => false,
      "refs/heads/**"                         => true,
      "refs/heads/**cool**"                   => false,
      "refs/heads/bug**"                      => false,
      "refs/heads/bugfix/that/cool/perm-test" => true,
      "that/cool/perm-test"                   => true,
      "perm-tes?"                             => true
    }

    expected_branch_pattern_results.each do |pattern, expected_result|
      expected_human = expected_result ? "matches" : "does not match"
      it %(#{expected_human} branch "#{branch}" with branch pattern "#{pattern}") do
        branch_permissions = branch_permissions_from_matchers("PATTERN" => pattern)
        exporter = branch_permissions_exporter(
          branches: branches,
          branching_models: [],
          branch_permissions: branch_permissions
        )

        expected_times = expected_result ? 1 : 0
        expect(exporter).to receive(:serialize).exactly(expected_times).times

        exporter.export
      end
    end
  end

  describe "#branching_model_categories" do
    expected_branching_model_results = {
      "bugfix/that/cool/perm-test"   => true,
      "bugfix//that/cool/perm-test"  => true,
      "bugfix//"                     => true,
      "/bugfix/that/cool/perm-test"  => false,
      "bugfixes/that/cool/perm-test" => false,
      "bugfi/that/cool/perm-test"    => false,
      "abugfix/that/cool/perm-test"  => false,
      "bugfix"                       => false,
      "BUGFIX/that/cool/perm-test"   => false
    }

    branching_model_category = {
      "id"          => "BUGFIX",
      "displayName" => "Bugfix",
      "prefix"      => "bugfix/"
    }
    branching_models = { "types" => [branching_model_category] }
    branch_permissions = branch_permissions_from_matchers(
      "MODEL_CATEGORY" => branching_model_category
    )

    expected_branching_model_results.each do |branch_name, expected_result|
      expected_human = expected_result ? "matches" : "does not match"
      it \
        "#{expected_human} branch \"#{branch_name}\" with branching model" \
        " prefix \"#{branching_model_category["prefix"]}\"" \
      do
        branches = branches_from_branch_names(branch_name)
        exporter = branch_permissions_exporter(
          branches: branches,
          branching_models: branching_models,
          branch_permissions: branch_permissions
        )

        expected_times = expected_result ? 1 : 0
        expect(exporter).to receive(:serialize).exactly(expected_times).times

        exporter.export
      end
    end
  end

  describe "#branching_model_branches" do
    it "resolves branching model branches" do
      branch_permissions_development = branch_permissions.select do |permission|
        permission["matcher"]["type"]["id"] == "MODEL_BRANCH" && \
          permission["matcher"]["id"] == "development"
      end

      exporter = branch_permissions_exporter(
        branches: branches,
        branching_models: branching_models,
        branch_permissions: branch_permissions_development
      )

      expect(exporter).to receive(:serialize).exactly(1).times

      exporter.export
    end
  end

  describe "#model" do
    it "aliases to the branch_permissions" do
      expect(branch_permissions_exporter.model).to eq(branch_permissions)
    end
  end

  describe "#repository" do
    it "returns the repository from the repository_exporter" do
      expect(branch_permissions_exporter.repository).to eq(repository)
    end
  end

  describe "#branches" do
    it "returns the branches" do
      expect(branch_permissions_exporter.branches).to eq(branches)
    end
  end

  describe "#branching_models" do
    it "returns the branching_models" do
      expect(branch_permissions_exporter.branching_models).to(
        eq(branching_models)
      )
    end
  end

  describe "#repository_exporter" do
    it "returns the repository_exporter" do
      expect(branch_permissions_exporter.repository_exporter).to(
        eq(repository_exporter)
      )
    end
  end
end
