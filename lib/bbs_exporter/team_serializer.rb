# frozen_string_literal: true

class BbsExporter
  # Serializes Teams from data collected by `TeamBuilder`.
  class TeamSerializer < BaseSerializer
    validates_exclusion_of :repositories, :members, in: [nil]
    validates_presence_of :project, :name

    PERMISSION_MAP = {
      "PROJECT_READ"  => "pull",
      "PROJECT_WRITE" => "push",
      "PROJECT_ADMIN" => "admin",

      "REPO_READ"  => "pull",
      "REPO_WRITE" => "push",
      "REPO_ADMIN" => "admin"
    }

    def to_gh_hash
      {
        "type"         => type,
        "url"          => url,
        "organization" => project_url,
        "name"         => name,
        "permissions"  => repository_permissions,
        "members"      => member_permissions,
        "created_at"   => created_at
      }
    end

    private

    def type
      "team"
    end

    def project
      bbs_model["project"]
    end

    def name
      bbs_model["name"]
    end

    def permission
      bbs_model["permission"]
    end

    def repositories
      bbs_model["repositories"]
    end

    def members
      bbs_model["members"]
    end

    def url
      url_for_model(bbs_model, type: type)
    end

    def project_url
      model_url_service.url_for_model(project)
    end

    def repository_permissions
      repositories.map do |repository|
        {
          "repository" => repository,
          "access"     => permission_mapped
        }
      end
    end

    def permission_mapped
      PERMISSION_MAP.fetch(permission)
    end

    def member_permissions
      members.map do |member|
        {
          "user" => member,
          "role" => "member"
        }
      end
    end

    def created_at
      generate_created_at
    end
  end
end
