# frozen_string_literal: true

class BbsExporter
  # Serializes Pull Request Comments from Bitbucket Server's Pull Request
  # Comments.
  class PullRequestCommentSerializer < BaseSerializer
    validates_presence_of :author, :created_date, :pull_request_comment, :text

    def to_gh_hash
      {
        type:         type,
        url:          url,
        pull_request: pull_request_url,
        user:         user_url,
        body:         text,
        formatter:    formatter,
        created_at:   created_date_formatted
      }
    end

    # PullRequestComments require that its pull_request be attached before
    # serialization

    private

    def type
      "issue_comment"
    end

    def pull_request_comment
      bbs_model[:pull_request_comment]
    end

    def author
      pull_request_comment["author"]
    end

    def text
      pull_request_comment["text"]
    end

    def created_date
      pull_request_comment["createdDate"]
    end

    def url
      url_for_model(bbs_model, type: "issue_comment")
    end

    def pull_request_url
      url_for_model(bbs_model[:pull_request])
    end

    def user_url
      url_for_model(author)
    end

    def formatter
      "markdown"
    end

    def created_date_formatted
      format_long_timestamp(created_date)
    end
  end
end
