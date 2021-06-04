# frozen_string_literal: true

class BbsExporter
  # @!attribute [r] repository
  #   @return [Hash] the repository to be exported
  # @!attribute [r] archiver
  #   @return [BbsExporter::ArchiveBuilder] the instance of the archiver for
  #   this export job
  # @!attribute [r] models
  #   @return [Array] the optional model types to be exported
  # @!attribute [r] team_builder
  #   @return [BbsExporter::TeamBuilder] the instance of the team builder for
  #   this export job
  # @!attribute [r] current_export
  #   @return [BbsExporter] the instance of this export job
  # @!attribute [rw] pull_requests
  #   @return [Array] the child pull requests of the repository being exported
  class RepositoryExporter
    include Storable
    include Writable
    include PullRequestHelpers

    attr_reader :archiver, :bitbucket_server, :current_export, :models,
      :repository_model, :team_builder

    attr_accessor :pull_requests

    delegate :log_with_url, to: :current_export

    # Create a new instance of RepositoryExporter.
    #
    # @param [BitbucketServer::Repository] repository_model Repository model
    #   for repository to export.
    # @param current_export [BbsExporter] Instance for the current export.
    def initialize(repository_model, current_export:)
      @repository_model = repository_model
      @current_export = current_export
      @bitbucket_server = current_export.bitbucket_server
      @archiver = current_export.archiver
      @models = current_export.models_to_export & OPTIONAL_MODELS
      @team_builder = current_export.team_builder

      @pull_requests = []
    end

    # Alias for `repository`
    #
    # @return [Hash]
    def model
      repository
    end

    def repository
      @repository ||= repository_model.repository
    end

    def export
      current_export.output_logger.info(
        "Exporting repository #{repository_model.project_and_repo}..."
      )

      serialize("user", current_export.bitbucket_server.user)
      team_builder.group_access = group_access

      # BitbucketServer is inconsistent with their API where project-owned
      # repositories don't have an "owner" attribute.

      repository.merge!(
        "owner"         => project,
        "collaborators" => export_collaborators,
        "access_keys"   => export_access_keys
      )

      current_export.output_logger.info "Cloning repository..."

      archiver.clone_repo(repository)

      export_optional_models
      export_tags
      export_protected_branches

      serialize "repository", repository

      export_stored_repository_data
    end

    # Serializes and exports data for MigratableResources pertaining to
    # `repository`.
    def export_stored_repository_data
      current_export.output_logger.info "Exporting pull requests..."
      pull_requests.sort_by(&:created_date).each(&:export)
    end

    # Caches `#export_repository_project` in memory.
    #
    # @return [Hash] BitbucketServer Project.
    def project
      @project ||= export_repository_project
    end

    # Exports the project that owns `@repository`.
    #
    # @return [Hash] BitbucketServer Project.
    def export_repository_project
      if project_model.user_project?
        serialize("user", project_model.project["owner"])
      else
        export_project(project_model)
      end

      project_model.project
    end

    def project_model
      repository_model.project_model
    end

    def group_access
      return @group_access if @group_access

      # Bitbucket Server returns downcased group names when fetching
      # group permissions for a repository, but it returns properly-cased group
      # names when fetching all of the groups from a separate API call.  In
      # addition, Bitbucket Server is case insensitive when matching and
      # validating group names (like GitHub).  Therefore, we can safely compare
      # downcased group names between the two API calls to find the properly-
      # cased names for the group access data.

      group_names = bitbucket_server.groups.map { |g| g["name"] }
      @group_access = repository_model.group_access

      @group_access.each do |access|
        access["group"]["name"] = group_names.detect do |name|
          name.downcase == access["group"]["name"]
        end
      end

      @group_access
    end

    # Serialize and export a BitbucketServer Project as a GitHub Organization.
    # Also exports the project members and their project memberships.
    #
    # @param [BitbucketServer::Project] project_model
    #   `BitbucketServer::Project` model to export project from.
    def export_project(project_model)
      project = project_model.project.merge(
        "members" => repository_model.project_model.members
      )

      serialize "organization", project

      team_builder.add_repository(
        project:    project,
        repository: repository
      )

      serialized_users = project["members"].map do |member|
        # Since we're already looping here, we sneak in the addition to TeamBuilder
        team_builder.add_member(
          project: project,
          member:  member
        )
        # Each org member needs an associated user created
        serialize("user", member["user"])
      end
    end

    # Serialize and export the repository collaborators
    #
    # @return [Array] the BitbucketServer repository collaborators
    def export_collaborators
      repository_model.team_members.each do |collaborator|
        serialize("user", collaborator["user"])
      end
    end

    def export_optional_models
      models.each do |model|
        send("export_#{model}")
      end
    end

    # Serialize and export groups as teams
    def export_teams
      export_group_access_teams
      export_branch_permission_teams
    end

    def export_branch_permission_teams
      repository_model.branch_permissions.each do |branch_permission|
        branch_permission["groups"].each do |group_name|
          members = export_group_members(group_name)

          serialize_team(
            name:    group_name,
            members: members
          )
        end
      end
    end

    def export_group_access_teams
      group_access.each do |group|
        members = export_group_members(group["group"]["name"])
        repositories = [
          model_url_service.url_for_model(repository, type: "repository")
        ]

        serialize_team(
          name:         group["group"]["name"],
          permission:   group["permission"],
          members:      members,
          repositories: repositories
        )
      end
    end

    def export_group_members(group_name)
      members = bitbucket_server.group_members(group_name)

      members.map do |member|
        serialize("user", member)
        model_url_service.url_for_model(member)
      end
    end

    def serialize_team(name:, members:, permission: nil, repositories: [])
      team_model = {
        "name"         => name,
        "project"      => repository["project"],
        "permission"   => permission,
        "members"      => members,
        "repositories" => repositories
      }

      serialize("team", team_model)
    end

    # Prepare Branch Permissions for @repository to be exported
    def export_protected_branches
      current_export.output_logger.info "Exporting branch permissions..."

      branching_models = repository_model.branching_models
      return unless branching_models

      permissions = repository_model.branch_permissions
      branches = repository_model.branches

      branch_permission_exporter = BranchPermissionsExporter.new(
        repository_exporter: self,
        project:             project,
        branches:            branches,
        branch_permissions:  permissions,
        branching_models:    branching_models
      )

      branch_permission_exporter.export
    end

    # Prepare the Pull Requests for @repository to be exported
    def export_pull_requests
      current_export.output_logger.info "Preparing pull requests..."
      pull_request_models.each(&method(:export_pull_request))
    end

    def pull_request_models
      @pull_request_models = (
        repository_model.pull_requests.map do |pull_request|
          repository_model.pull_request_model(pull_request["id"])
        end
      )
    end

    # Prepare a BitbucketServer Pull Request to be exported
    #
    # @param [BitbucketServer::PullRequest] pull_request_model The PullRequest
    #   model to export.
    def export_pull_request(pull_request_model)
      if pull_request_model.commits.empty?
        return log_with_url(
          severity:   :warn,
          message:    "was skipped because the PR has no diff",
          model:      pull_request_model.pull_request,
          model_name: "pull_request",
          console:    true
        )
      end

      pull_requests.push(
        PullRequestExporter.new(
          pull_request_model,
          repository_exporter: self,
          project:             project
        )
      )
    end

    # Serialize and export the Bitbucket Server tags for @project as GitHub
    # Releases.
    def export_tags
      current_export.output_logger.info "Exporting tags..."
      repository_model.tags.each do |tag|
        export_tag(tag)
      end
    end

    # Serialize and export a Bitbucket Server tag
    #
    # @param [Hash] tag the Bitbucket Server tag to be exported
    def export_tag(tag)
      tag["repository"] = repository
      tag["user"] = bitbucket_server.user # attribute all tags to export user
      tag["commit"] = repository_model.commit(tag["latestCommit"])
      serialize("release", tag)
    end

    def export_access_keys
      current_export.output_logger.info "Exporting access keys..."
      repository_model.access_keys
    end

    def commits_with_comments
      [].tap do |commits|
        latest_branch_ids.each do |id|
          repository_model.commits(until_id: id).each do |commit|
            commits << commit if commit["properties"]&.include?("commentCount")
          end
        end
      end
    end

    def latest_branch_ids
      repository_model.branches.map { |b| b["latestCommit"] }.uniq
    end

    def first_parent_commit(commit)
      commit["parents"].first&.fetch("id")
    end

    def export_commit_comment_line_comments(diff_item, diff, commit_id)
      diff_item["lineComments"]&.each do |comment|
        commit_comment = CommitComment::Line.new(
          repository: repository,
          commit_id:  commit_id,
          diff:       diff,
          comment:    comment
        )

        CommitCommentExporter.new(
          repository_exporter: self,
          commit_comment:      commit_comment
        ).export
      end
    end

    def export_commit_comment_file_comments(diff_item, commit_id)
      diff_item["fileComments"]&.each do |comment|
        commit_comment = CommitComment::File.new(
          repository: repository,
          commit_id:  commit_id,
          diff_item:  diff_item,
          comment:    comment
        )

        CommitCommentExporter.new(
          repository_exporter: self,
          commit_comment:      commit_comment
        ).export
      end
    end

    def comment_ids_from_diff_item(diff_item)
      [].tap do |comment_ids|
        ["fileComments", "lineComments"].each do |key|
          diff_item[key]&.each do |comment|
            comment_ids << comment["id"]
          end
        end
      end
    end

    def export_diff_comments(diff, commit_id)
      diff["diffs"].each do |diff_item|
        export_commit_comment_line_comments(diff_item, diff, commit_id)
        export_commit_comment_file_comments(diff_item, commit_id)
      end
    end

    def export_commit_comments
      current_export.output_logger.info("Exporting commit comments...")

      commits_with_comments.each do |commit|
        parent_commit_id = first_parent_commit(commit)
        diff = repository_model.diff(commit["id"], since: parent_commit_id)

        export_individual_diffs(diff: diff, since: parent_commit_id)
      end
    end

    def export_individual_diffs(diff:, since:)
      diff["diffs"].each do |individual_diff|
        commit_id = diff["toHash"]
        path = DiffItem.new(individual_diff).path

        diff = repository_model.diff(
          commit_id,
          file_path: path,
          since:     since
        )

        export_diff_comments(diff, commit_id)
      end
    end
  end
end
