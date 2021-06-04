# frozen_string_literal: true

class BbsExporter
  # Serializes Collaborators from Bitbucket Server's Repository Team Members.
  class CollaboratorSerializer < BaseSerializer
    validates_presence_of :permission

    PERMISSION_MAP = {
      "REPO_READ"  => "read",
      "REPO_WRITE" => "write",
      "REPO_ADMIN" => "admin"
    }

    # @see BbsExporter::BaseSerializer#to_gh_hash
    def to_gh_hash
      {
        user:       user_url,
        permission: permission_mapped
      }
    end

    private

    def user_url
      url_for_model(bbs_model, type: "member")
    end

    def permission
      bbs_model["permission"]
    end

    def permission_mapped
      PERMISSION_MAP.fetch(permission)
    end
  end
end
