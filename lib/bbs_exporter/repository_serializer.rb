# frozen_string_literal: true

class BbsExporter
  # Serializes Repositories from Bitbucket Server's Projects.
  class RepositorySerializer < BaseSerializer
    validates_exclusion_of :collaborators, in: [nil]
    validates_inclusion_of :repo_public?, in: [true, false]
    validates_presence_of :name, :project

    def to_gh_hash
      {
        type:           type,
        url:            url,
        owner:          owner_url,
        name:           name,
        description:    description,
        private:        project_and_repo_private?,
        has_issues:     has_issues,
        has_wiki:       has_wiki,
        has_downloads:  has_downloads,
        labels:         labels,
        collaborators:  serialized_collaborators,
        created_at:     created_at,
        git_url:        git_url,
        default_branch: default_branch,
        public_keys:    public_keys
      }
    end

    private

    def type
      "repository"
    end

    def name
      bbs_model["slug"]
    end

    def collaborators
      bbs_model["collaborators"]
    end

    def description
      bbs_model["description"]
    end

    def project
      bbs_model["project"]
    end

    def project_public?
      project["public"]
    end

    def repo_public?
      bbs_model["public"]
    end

    def url
      url_for_model(bbs_model, type: "repository")
    end

    def has_issues
      false
    end

    def has_wiki
      false
    end

    def has_downloads
      false
    end

    def labels
      []
    end

    def default_branch
      "master"
    end

    def owner_url
      url_for_model(project) if project
    end

    def project_and_repo_private?
      !(project_public? || repo_public?)
    end

    def serialized_collaborators
      collaborators.to_a.map do |repository_team_member|
        CollaboratorSerializer.new.serialize(repository_team_member)
      end
    end

    def public_keys
      bbs_model["access_keys"].map do |access_key|
        {
          "title"       => access_key["key"]["label"],
          "key"         => access_key["key"]["text"],
          "read_only"   => access_key["permission"] == "REPO_READ",
          "fingerprint" => SSHFingerprint.compute(access_key["key"]["text"]),
          "created_at"  => created_at
        }
      end
    end

    def created_at
      @created_at ||= generate_created_at
    end

    def git_url
      "tarball://root/repositories/#{project["key"] + "/" + bbs_model["slug"]}.git"
    end
  end
end
