# frozen_string_literal: true

class BbsExporter
  class TeamBuilder
    include Writable

    attr_reader :current_export, :archiver, :project_repositories, :team_members

    delegate :log_with_url, to: :current_export

    def initialize(current_export: BbsExporter.new)
      @current_export = current_export
      @archiver = current_export.archiver
      @project_repositories = Set.new
      @team_members = Set.new
    end

    def add_member(project:, member:)
      team_members.add(
        project: project,
        member:  member
      )
    end

    def add_repository(project:, repository:)
      project_repositories.add(
        project:    project,
        repository: repository
      )
    end

    def group_access=(group_access)
      @groups = group_access.map { |g| g["group"]["name"].downcase.strip }
    end

    # Serialize and return a flat array of all the team permutations
    #
    # @return [Array]
    def teams
      members_by_project.flat_map do |project, members|
        members_by_permission(members).flat_map do |permission, members|
          build_team(
            project,
            permission,
            members,
            repositories_for_project(project)
          )
        end
      end
    end

    def write!
      teams.each do |team|
        serialize("team", team)
      end
    end

    private

    def member_permission(member)
      member[:member]["permission"]
    end

    def members_by_project
      team_members.group_by { |m| m[:project] }
    end

    def members_by_permission(members)
      members.group_by { |m| member_permission(m) }
    end

    def repositories_for_project(project)
      project_repositories.select { |r| r[:project] == project }
    end

    def build_team(project, permission, members, repositories)
      faux_team_model(project, permission, members, repositories)
    end

    def faux_team_model_name(permission)
      "#{permission.downcase}_access"
    end

    def unused_faux_team_model_name(permission)
      original_name = faux_team_model_name(permission)
      return original_name if @groups.nil?

      # It's possible that our generated team name could be the same as an
      # existing group in a case-insensitive match.  This generated group name
      # would conflict with the real group, so we try adding "(2)", "(3)", etc.
      # until we land on a group name that doesn't exist (in a case-insensitive
      # way).

      numeric = 2
      name = original_name

      until !@groups.include?(name.downcase.chomp)
        name = "#{original_name} (#{numeric})"
        numeric += 1
      end

      name
    end

    def faux_team_model(project, permission, members, repositories)
      {
        "name"         => unused_faux_team_model_name(permission),
        "project"      => project,
        "permission"   => permission,
        "members"      => member_urls(members),
        "repositories" => repository_urls(repositories)
      }
    end

    def repository_urls(repositories)
      repositories.map do |repository|
        model_url_service.url_for_model(repository[:repository])
      end
    end

    def member_urls(members)
      members.map do |member|
        model_url_service.url_for_model(member[:member], type: "member")
      end
    end

    def model_url_service
      @model_url_service ||= ModelUrlService.new
    end
  end
end
