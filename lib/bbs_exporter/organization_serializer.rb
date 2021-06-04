# frozen_string_literal: true

class BbsExporter
  # Serializes Organizations from Bitbucket Server's Projects.
  class OrganizationSerializer < BaseSerializer
    validates_presence_of :key, :name

    def to_gh_hash
      {
        type:        type,
        url:         url,
        login:       key,
        name:        name,
        description: description,
        members:     members_serialized
      }
    end

    private

    def type
      "organization"
    end

    def description
      bbs_model["description"].to_s
    end

    def key
      bbs_model["key"]
    end

    def members
      bbs_model["members"]
    end

    def name
      bbs_model["name"]
    end

    def url
      url_for_model(bbs_model)
    end

    def members_serialized
      members.to_a.map { |m| MemberSerializer.new.serialize(m) }
    end

    def created_at
      generate_created_at
    end
  end
end
