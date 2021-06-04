# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::RepositoryExporter do
  subject(:repository_exporter) do
    described_class.new(
      repository_model,
      current_export: current_export
    )
  end

  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:empty_repository_model) do
    project_model.repository_model("empty-repo")
  end

  let(:pull_request_model) do
    repository_model.pull_request_model(6)
  end

  let(:repository) do
    VCR.use_cassette("projects/MIGR8/hugo-pages") do
      repository_model.repository
    end
  end

  let(:pull_request) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/pull_requests/6") do
      pull_request_model.pull_request
    end
  end

  let(:branch_permissions) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/branch_permissions") do
      repository_model.branch_permissions
    end
  end

  let(:empty_repository_exporter) do
    BbsExporter::RepositoryExporter.new(
      empty_repository_model,
      current_export: current_export
    )
  end

  let(:empty_branching_models) do
    VCR.use_cassette("projects/MIGR8/empty-repo/branching_models") do
      empty_repository_model.branching_models
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

  let(:groups) do
    VCR.use_cassette("admin/groups") do
      bitbucket_server.groups
    end
  end

  let(:group_access) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/group_access") do
      repository_model.group_access
    end
  end

  let(:more_members_project_read_access) do
    VCR.use_cassette("admin/groups/more-members/project_read_access") do
      bitbucket_server.group_members("project_read access")
    end
  end

  let(:more_members_stash_users) do
    VCR.use_cassette("admin/groups/more-members/stash-users") do
      bitbucket_server.group_members("stash-users")
    end
  end

  let(:more_members_test_group) do
    VCR.use_cassette("admin/groups/more-members/test_group") do
      bitbucket_server.group_members("test_group")
    end
  end

  let(:branches) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/branches") do
      repository_model.branches
    end
  end

  commit_ids = {
    "0633a65a0d2865ebc045455d19c97602d7414120" => "0633a65",
    "112e299ef8f06f951dde8ce105aad0252180cde0" => "112e299",
    "268576529491c67f19db1af0fd2906cee0abb1f2" => "2685765",
    "2b912a8ca196cd92cd351ef4fba52e5cedbfb734" => "2b912a8",
    "2d26b4300e6b7d2047690d67ffca167222b41b31" => "2d26b43",
    "3cb7e5514a330fca5fc3b1c8b32883fe2ff813a9" => "3cb7e55",
    "3f196110a84594a89c87864a1a93acc49db8db94" => "3f19611",
    "542aed8ddc52388ce24212a74ecba6a511a9a763" => "542aed8",
    "59777e035d3371027513b0e483d53bb7d9143627" => "59777e0",
    "6150ca7e1fd18c96e2907a4ba31880e8b2329459" => "6150ca7",
    "717a584bff1380749b360b362db8c04ae194aaca" => "717a584",
    "87fabe1ef09821868e789b5bde5b5cfb20c901fa" => "87fabe1",
    "95ae6d5909d44a22b3df82040f1bf0c8387aad51" => "95ae6d5",
    "99349343681b819fc4ce962796be202c0a19d8c4" => "9934934",
    "9c464a04ae939523f8a88122a09dadeaee2b5606" => "9c464a0",
    "a0b4cc70a65dadcad4e15e29638679b958107e5a" => "a0b4cc7",
    "a7c109c372ca8869b22350f2977cf75334d6bf57" => "a7c109c",
    "ace0ddae7cc4f2967e9cefafdafb1aa5c65f3ea0" => "ace0dda",
    "c222af415ecc78c644c139cbf5eb44a25205cbad" => "c222af4",
    "cab4b7ed6e2355d7dae94c94609f482f842e20b4" => "cab4b7e",
    "e11596878774727839c640881b028ca5c0a96841" => "e115968",
    "f6dafe7e502222499c285e24c20c01ad5789be12" => "f6dafe7"
  }

  commit_ids.each do |long_id, short_id|
    let(:"commit_#{short_id}") do
      VCR.use_cassette("projects/MIGR8/hugo-pages/commits/#{short_id}") do
        repository_model.commits(until_id: long_id)
      end
    end
  end

  describe "#export" do
    it "should not export branch permissions for empty repos" do
      empty_branching_models_results = empty_branching_models

      allow(empty_repository_model).to receive(:branching_models) do
        empty_branching_models_results
      end

      expect(
        BbsExporter::BranchPermissionsExporter
      ).to_not receive(:export)

      empty_repository_exporter.export_protected_branches
    end
  end

  describe "#export_optional_models" do
    subject(:export_optional_models) do
      repository_exporter.export_optional_models
    end

    context "with teams included in optional models" do
      before do
        current_export.options[:models] = %w(teams)
      end

      it "exports teams" do
        expect(repository_exporter).to receive(:export_teams)
        export_optional_models
      end
    end

    context "with commit comments included in optional models" do
      before do
        current_export.options[:models] = %w(commit_comments)
      end

      it "exports commit comments" do
        expect(repository_exporter).to receive(:export_commit_comments)
        export_optional_models
      end
    end

    context "with models omitted from optional models" do
      before do
        current_export.options[:models] = %w()
      end

      it "does not export teams" do
        expect(repository_exporter).to_not receive(:export_teams)
        export_optional_models
      end

      it "does not export commit comments" do
        expect(repository_exporter).to_not receive(:export_commit_comments)
        export_optional_models
      end
    end
  end

  describe "#export_teams" do
    before(:each) do
      allow(bitbucket_server).to receive(:groups).and_return(groups)

      groups = {
        "project_read access" => more_members_project_read_access,
        "stash-users"         => more_members_stash_users,
        "test_group"          => more_members_test_group
      }

      allow(repository_model).to receive(:branch_permissions).and_return(
        branch_permissions
      )

      allow(bitbucket_server).to receive(:group_members) do |group|
        groups.fetch(group)
      end

      allow(repository_exporter).to receive(:repository).and_return(repository)
      allow(repository_exporter).to receive(:group_access).and_return(
        group_access
      )
      allow(repository_exporter).to receive(:serialize).and_call_original
    end

    it "serializes teams correctly" do
      team_model_project_read_access = {
        "name"         => "project_read access",
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
        "permission"   => "REPO_WRITE",
        "members"      => ["https://example.com/users/synthead"],
        "repositories" => [
          "https://example.com/projects/MIGR8/repos/hugo-pages"
        ]
      }

      team_model_stash_users = {
        "name"         => "stash-users",
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
        "permission"   => "REPO_READ",
        "members"      => [
          "https://example.com/users/dpmex4527",
          "https://example.com/users/has_weird%F0%9F%8C%ADcharacters",
          "https://example.com/users/has_weird%F0%9F%8C%ADcharacters0",
          "https://example.com/users/kylemacey",
          "https://example.com/users/larsxschneider",
          "https://example.com/users/mattcantstop",
          "https://example.com/users/michaelsainz",
          "https://example.com/users/migarjo",
          "https://example.com/users/primetheus",
          "https://example.com/users/synthead",
          "https://example.com/users/tambling",
          "https://example.com/users/test123",
          "https://example.com/users/testuser1",
          "https://example.com/users/testuser10",
          "https://example.com/users/testuser11",
          "https://example.com/users/testuser12",
          "https://example.com/users/testuser2",
          "https://example.com/users/testuser3",
          "https://example.com/users/testuser4",
          "https://example.com/users/testuser5",
          "https://example.com/users/testuser6",
          "https://example.com/users/testuser7",
          "https://example.com/users/testuser8",
          "https://example.com/users/testuser9",
          "https://example.com/users/unit-test"
        ],
        "repositories" => [
          "https://example.com/projects/MIGR8/repos/hugo-pages"
        ]
      }

      expect(repository_exporter).to receive(:serialize).with(
        "team", team_model_project_read_access
      )
      expect(repository_exporter).to receive(:serialize).with(
        "team", team_model_stash_users
      )

      repository_exporter.export_teams
    end
  end

  describe "#export_repository_project" do
    context "with a user repository" do
      let(:repository_model) do
        bitbucket_server.project_model("~kylemacey").repository_model("personal-repo")
      end

      subject(:export_repository_project) do
        VCR.use_cassette("projects/~kylemacey/personal-repo/export-user-repo-owner") do
          repository_exporter.export_repository_project
        end
      end

      it "exports the owning user" do
        expect(repository_exporter).to(
          receive(:serialize).with("user", hash_including("name" => "kylemacey"))
        )
        export_repository_project
      end
    end
  end

  describe "#export_pull_request" do
    context "with a pull request with no commits" do
      subject(:export_pull_request) do
        repository_exporter.export_pull_request(pull_request_model)
      end

      it "does not export the pull request" do
        expect(pull_request_model).to receive(:commits).and_return([])
        expect(pull_request_model).to receive(:pull_request).and_return(
          pull_request
        )

        expect {
          export_pull_request
        }.to_not change { repository_exporter.pull_requests.length }
      end
    end
  end

  describe "#commits_with_comments" do
    before(:each) do
      allow(repository_model).to receive(:branches).and_return(branches)

      commits_by_id = commit_ids.map do |long_id, short_id|
        commit = send(:"commit_#{short_id}")
        [long_id, commit]
      end.to_h

      allow(repository_model).to receive(:commits) do |params|
        id = params[:until_id]
        commits_by_id[id]
      end
    end

    it "contains a unique commit from the commit-comments-not-master branch" do
      commit = repository_exporter.commits_with_comments.detect do |commit|
        commit["id"] == "2b912a8ca196cd92cd351ef4fba52e5cedbfb734"
      end

      expect(commit).to_not eq(nil)
    end
  end
end
