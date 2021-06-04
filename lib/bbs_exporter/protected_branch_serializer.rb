# frozen_string_literal: true

class BbsExporter
  # Serializes Protected Branches from Bitbucket Server's Branch Permissions.
  class ProtectedBranchSerializer < BaseSerializer
    validates_presence_of :branch_name

    def to_gh_hash
      {
        type:                                     type,
        name:                                     branch_name,
        url:                                      url,
        repository_url:                           repository_url,
        admin_enforced:                           admin_enforced,
        block_deletions_enforcement_level:        block_deletions_enforcement_level,
        block_force_pushes_enforcement_level:     block_force_pushes_enforcement_level,
        dismiss_stale_reviews_on_push:            dismiss_stale_reviews_on_push,
        pull_request_reviews_enforcement_level:   pull_request_reviews_enforcement_level,
        require_code_owner_review:                require_code_owner_review,
        required_status_checks_enforcement_level: required_status_checks_enforcement_level,
        strict_required_status_checks_policy:     strict_required_status_checks_policy,
        authorized_actors_only:                   authorized_actors_only,
        authorized_user_urls:                     authorized_user_urls,
        authorized_team_urls:                     authorized_team_urls,
        dismissal_restricted_user_urls:           dismissal_restricted_user_urls,
        dismissal_restricted_team_urls:           dismissal_restricted_team_urls,
        required_status_checks:                   required_status_checks
      }
    end

    private

    def type
      "protected_branch"
    end

    def branch_permissions
      bbs_model["branch_permissions"]
    end

    def branch_name
      bbs_model["branch_name"]
    end

    def branch_permissions_by_type(type)
      branch_permissions.select { |p| p["type"] == type }
    end

    def user_permissions_by_type(type)
      permissions = branch_permissions_by_type(type)
      return [] unless permissions

      users = Set.new
      permissions.each do |permission|
        permission["users"].each do |user|
          users << url_for_model(user, type: "user")
        end
      end

      users.to_a
    end

    def model_url_service
      @model_url_service ||= ModelUrlService.new
    end

    def group_url(group)
      group_model = {
        "name"    => group,
        "project" => bbs_model["repository"]["project"]
      }

      model_url_service.url_for_model(group_model, type: "team")
    end

    def team_permissions_by_type(type)
      permissions = branch_permissions_by_type(type)
      return [] unless permissions

      teams = Set.new
      permissions.each do |permission|
        permission["groups"].each do |group|
          teams << group_url(group)
        end
      end

      teams.to_a
    end

    def url
      url_for_model(bbs_model, type: "protected_branch")
    end

    def repository_url
      url_for_model(bbs_model["repository"], type: "repository")
    end

    def admin_enforced
      # There are no admin exceptions for this option in BitBucket Server.
      true
    end

    def block_deletions_enforcement_level
      # Sets the enforcement protection levels for blocking deletions.
      # Although this permission is selectable, GitHub sets this to "everyone"
      # for all protected branches.
      # 0 => :off        no protection
      # 1 => :non_admins non-admins cannot delete the branch
      # 2 => :everyone   everyone, including an admin, cannot delete the branch
      2
    end

    def block_force_pushes_enforcement_level
      # Sets the enforcement protection levels for branch pushes.
      # 0 => :off        no protection
      # 1 => :non_admins non-admins cannot force push to branch
      # 2 => :everyone   everyone, including an admin, cannot force push to the branch
      2
    end

    def dismiss_stale_reviews_on_push
      true
    end

    def pull_request_reviews_enforcement_level
      branch_permissions_by_type("pull-request-only").any? ? "everyone" : "off"
    end

    def authorized_actors_only
      branch_permissions_by_type("read-only").any?
    end

    def require_code_owner_review
      # There are no code owners in BitBucket Server.
      false
    end

    def required_status_checks_enforcement_level
      # There are no status checks in BitBucket Server.
      "off"
    end

    def strict_required_status_checks_policy
      # There are no status checks in BitBucket Server.
      false
    end

    def authorized_user_urls
      user_permissions_by_type("read-only")
    end

    def authorized_team_urls
      team_permissions_by_type("read-only")
    end

    def dismissal_restricted_user_urls
      user_permissions_by_type("pull-request-only")
    end

    def dismissal_restricted_team_urls
      team_permissions_by_type("pull-request-only")
    end

    def required_status_checks
      # There are no status checks in BitBucket Server.
      []
    end
  end
end
