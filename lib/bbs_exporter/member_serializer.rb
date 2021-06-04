# frozen_string_literal: true

class BbsExporter
  # Serializes Organization Members from Bitbucket Server's Group Members.
  class MemberSerializer < BaseSerializer
    validates_presence_of :permission

    # Which Bitbucket Server access levels are equivalent to GitHub's
    # Organization Owner role.
    OWNER_ROLES = %w(PROJECT_ADMIN)

    def to_gh_hash
      {
        user: url,
        role: role,
      }
    end

    private

    def permission
      bbs_model["permission"]
    end

    def url
      url_for_model(bbs_model, type: "member")
    end

    def role
      OWNER_ROLES.include?(permission) ? "admin" : "direct_member"
    end
  end
end
