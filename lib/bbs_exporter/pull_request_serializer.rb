# frozen_string_literal: true

class BbsExporter
  # Serializes Pull Requests from Bitbucket Server's Pull Requests.
  class PullRequestSerializer < BaseSerializer
    validates_presence_of :author, :created_date, :from_ref,
      :from_ref_display_id, :from_ref_latest_commit, :owner, :repo_path,
      :repository, :state, :to_ref, :to_ref_display_id, :to_ref_latest_commit,
      :updated_date

    def to_gh_hash
      {
        type:        type,
        url:         url,
        user:        author_url,
        repository:  repository_url,
        title:       title,
        body:        body,
        base:        base,
        head:        head,
        labels:      labels,
        merged_at:   merged_at,
        closed_at:   closed_at,
        created_at:  created_date_formatted
      }
    end

    private

    def type
      "pull_request"
    end

    def author
      bbs_model["author"]
    end

    def repository
      bbs_model["repository"]
    end

    def owner
      bbs_model["owner"]
    end

    def state
      bbs_model["state"]
    end

    def created_date
      bbs_model["createdDate"]
    end

    def updated_date
      bbs_model["updatedDate"]
    end

    def repo_path
      bbs_model["repo_path"]
    end

    def to_ref
      bbs_model["toRef"]
    end

    def from_ref
      bbs_model["fromRef"]
    end

    def to_ref_display_id
      to_ref["displayId"]
    end

    def to_ref_latest_commit
      to_ref["latestCommit"]
    end

    def from_ref_display_id
      from_ref["displayId"]
    end

    def from_ref_latest_commit
      from_ref["latestCommit"]
    end

    def url
      url_for_model(bbs_model)
    end

    def author_url
      url_for_model(author, type: "author")
    end

    def owner_url
      url_for_model(owner)
    end

    def repository_url
      url_for_model(repository, type: "repository")
    end

    def merged?
      state == "MERGED"
    end

    def declined?
      state == "DECLINED"
    end

    def title
      bbs_model["title"].to_s
    end

    def body
      bbs_model["description"].to_s
    end

    def base
      {
        ref:  to_ref_display_id,
        sha:  to_ref_latest_commit,
        user: owner_url,
        repo: repository_url
      }
    end

    def head
      {
        ref:  from_ref_display_id,
        sha:  from_ref_latest_commit,
        user: owner_url,
        repo: repository_url
      }
    end

    def labels
      []
    end

    def created_date_formatted
      format_long_timestamp(created_date)
    end

    def updated_date_formatted
      format_long_timestamp(updated_date)
    end

    def merged_at
      updated_date_formatted if merged?
    end

    def closed_at
      updated_date_formatted if declined? || merged?
    end

    def rugged
      @rugged ||= Rugged::Repository.new(repo_path)
    end
  end
end
