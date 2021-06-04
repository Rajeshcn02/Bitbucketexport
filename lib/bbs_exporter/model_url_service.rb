# frozen_string_literal: true

class BbsExporter
  # @todo Update to use UrlTemplates.
  class ModelUrlService
    include PullRequestHelpers

    # Gets a Bitbucket Server style URL for a Bitbucket Server model. Used to
    # explicitly identify a model.
    #
    # @param [Hash] model a Bitbucket Server model
    # @param [Hash] opts
    # @option opts [String] :type the type of model being passed in; uses GitHub
    #   naming conventions
    # @return [String] the url for the model
    def url_for_model(model, opts = {})
      case opts[:type]
      when "label"
        "#{url_for_model(model["repository"])}/labels#/#{parameterize(model["name"])}"
      when "issue"
        "#{url_for_model(model["repository"])}/issues/#{model["iid"]}"
      when "issue_comment"
        issue_comment_url(model)
      when "milestone"
        "#{url_for_model(model["repository"])}/milestones/#{model["iid"]}"
      when "release"
        "#{url_for_model(model["repository"])}?at=refs/tags/#{parameterize(model["displayId"])}"
      when "attachment"
        attachment_url(model)
      when "team"
        group_url(model)
      when "author"
        model["user"]["links"]["self"][0]["href"]
      when "member"
        model["user"]["links"]["self"][0]["href"]
      when "protected_branch"
        protected_branch_url(model)
      when "pull_request_review"
        pull_request_review_url(model)
      when "pull_request_review_comment"
        pull_request_review_comment_url(model, comment: opts[:comment])
      when "repository"
        repository_url(model)
      when "commit_comment"
        commit_comment_url(model)
      when "issue_event"
        issue_event_url(model)
      when "user"
        user_url(model)
      else
        model["links"]["self"][0]["href"]
      end
    end

    private

    def user_url(model)
      return url_for_model(model) if model.key?("links")

      repository_url = url_for_model(model[:repository], type: "repository")

      uri = Addressable::URI.parse(repository_url)
      uri.path = File.join("users", model[:user]["slug"])

      uri.normalize.to_s
    end

    def attachment_url(model)
      return model[:url] if model[:url]

      repository_url = url_for_model(model[:repository], type: "repository")

      uri = Addressable::URI.parse(repository_url)
      uri.path = File.join(uri.path, "attachments", model[:path])

      uri.to_s
    end

    def issue_comment_url(model)
      pull_request_url = url_for_model(model[:pull_request])
      comment = model[:pull_request_comment]

      uri = URI(pull_request_url)
      uri.path = File.join(uri.path, "overview")
      uri.query = { commentId: comment["id"] }.to_param

      uri.to_s
    end

    def repository_url(model)
      model["links"]["self"][0]["href"].chomp("/browse")
    end

    def pull_request_review_comment_url(model, comment: nil)
      pull_request_url = url_for_model(model[:pull_request])
      comment ||= model[:comment]

      uri = URI(pull_request_url)
      uri.path = File.join(uri.path, "overview")
      uri.query = { commentId: comment["id"] }.to_param
      uri.fragment = "r#{comment["id"]}"

      uri.to_s
    end

    def grouped_pr_review_fragment(model)
      "#{model[:activity]["comment"]["author"]["slug"]}-#{model[:commit_id]}"
    end

    def activity_id_fragment(model)
      model[:activity]["id"].to_s
    end

    def pull_request_review_fragment(model)
      if commented?(model[:activity])
        grouped_pr_review_fragment(model)
      else
        activity_id_fragment(model)
      end
    end

    def pull_request_review_url(model)
      pull_request_url = url_for_model(model[:pull_request])

      uri = URI(pull_request_url)
      uri.fragment = pull_request_review_fragment(model)

      uri.to_s
    end

    def group_url(model)
      path = File.join(
        File::SEPARATOR,
        "admin",
        "groups",
        "view"
      )

      project_url = url_for_model(model["project"])
      query = { name: URI.encode(model["name"]) }

      uri = URI(project_url)
      uri.path = path
      uri.query = query.to_param
      uri.fragment = URI.encode(model["project"]["key"])

      uri.to_s
    end

    # Bitbucket Server doesn't have a unique route for each branch permission,
    # so this links to the repository's branch permissions page with a branch
    # name as a URL fragment.
    def protected_branch_url(model)
      path = File.join(
        File::SEPARATOR,
        "plugins",
        "servlet",
        "branch-permissions",
        model["repository"]["project"]["key"],
        model["repository"]["slug"]
      )

      uri = URI(url_for_model(model["repository"]))
      uri.path = path
      uri.fragment = model["branch_name"]

      uri.to_s
    end

    def commit_comment_url(model)
      url = repository_url(model[:repository])

      uri = URI(url)
      uri.path = File.join(
        uri.path,
        "commits",
        model[:commit_id]
      )

      comment_id = model[:comment]["id"]

      uri.query = { commentId: comment_id }.to_param
      uri.fragment = "commitcomment-#{comment_id}"

      uri.to_s
    end

    def issue_event_url(model)
      pull_request_url = url_for_model(model[:pull_request])

      uri = URI(pull_request_url)
      uri.fragment = "event-#{model[:activity_id]}"

      uri.to_s
    end

    # Sometimes Bitbucket Server doesn't send over IDs for resources, so we make them up
    def fake_id(model)
      md5 = Digest::MD5.new
      md5 << model.to_s
      md5.hexdigest
    end

    def parameterize(str)
      URI.encode_www_form_component(str)
    end

    def team_slug(permission)
      "#{permission.downcase}-access"
    end
  end
end
