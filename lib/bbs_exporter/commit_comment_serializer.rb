# frozen_string_literal: true

class BbsExporter
  class CommitCommentSerializer < BaseSerializer
    validates_presence_of :body, :comment, :commit_id, :created_date, :path,
      :position, :repository

    def to_gh_hash
      {
        type:       type,
        url:        url,
        repository: repository_url,
        user:       author_url,
        body:       body,
        formatter:  formatter,
        path:       path,
        position:   position,
        commit_id:  commit_id,
        created_at: created_date_formatted
      }
    end

    private

    def type
      "commit_comment"
    end

    def body
      bbs_model[:body]
    end

    def comment
      bbs_model[:comment]
    end

    def commit_id
      bbs_model[:commit_id]
    end

    def created_date
      comment["createdDate"]
    end

    def path
      bbs_model[:path]
    end

    def position
      bbs_model[:position]
    end

    def repository
      bbs_model[:repository]
    end

    def author
      bbs_model[:author]
    end

    def url
      url_for_model(bbs_model, type: type)
    end

    def repository_url
      url_for_model(repository, type: "repository")
    end

    def author_url
      url_for_model(author, type: "user")
    end

    def formatter
      "markdown"
    end

    def created_date_formatted
      format_long_timestamp(created_date)
    end
  end
end
