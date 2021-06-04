# frozen_string_literal: true

class BitbucketServer
  class Repository < Model
    attr_reader :project_model, :slug

    def initialize(connection:, project_model:, slug:)
      @connection = connection
      @project_model = project_model
      @slug = slug
      @path = [project_model.path, "repos", slug]
    end

    # Create a BitbucketServer::PullRequest model.
    #
    # @param [String] pull_request_id the id of the pull request
    # @return [BitbucketServer::PullRequest]
    def pull_request_model(pull_request_id)
      PullRequest.new(
        connection:       @connection,
        repository_model: self,
        id:               pull_request_id
      )
    end

    # Get the project key and repository slug, delimited by a slash.
    #
    # @return [String]
    def project_and_repo
      File.join(project_model.key, slug)
    end

    # Get the repository.
    #
    # @return [Hash]
    def repository
      get
    end

    # Get commits.
    #
    # @param [Boolean] follow_renames If true, the commit history of the
    #   specified file will be followed past renames. Only valid for a path to
    #   a single file.
    # @param [Boolean] ignore_missing true to ignore missing commits, false
    #   otherwise
    # @param [String] merges If present, controls how merge commits should be
    #   filtered. Can be either exclude, to exclude merge commits, include, to
    #   include both merge commits and non-merge commits or only, to only
    #   return merge commits.
    # @param [String] path An optional path to filter commits by
    # @param [String] since_id The commit ID or ref (exclusively) to retrieve
    #   commits after
    # @param [String] until_id The commit ID (SHA1) or ref (inclusively) to
    #   retrieve commits before
    # @param [Boolean] with_counts Optionally include the total number of
    #   commits and total number of unique authors
    # @return [Array<Hash>]
    def commits(
      follow_renames: nil, ignore_missing: nil, merges: nil, path: nil,
      since_id: nil, until_id: nil, with_counts: nil
    )
      query = {
        followRenames: follow_renames,
        ignoreMissing: ignore_missing,
        merges:        merges,
        path:          path,
        since:         since_id,
        until:         until_id,
        withCounts:    with_counts
      }

      get("commits", query: query, auto_paginate: true)
    rescue Faraday::ResourceNotFound => exception
      error = exception.response[:body]["errors"].first

      # Workaround for a bug in BBS 4.8.6 where a 404 is returned for empty
      # repositories.

      return [] if error["exceptionName"] == "com.atlassian.bitbucket." \
        "repository.NoDefaultBranchException"

      raise($!)
    end

    # Get a commit.
    #
    # @param [String] sha1 the sha of the commit
    # @return [Hash]
    def commit(sha1)
      get("commits", sha1)
    end

    # Get branches.
    #
    # @return [Array<Hash>]
    def branches
      get("branches", auto_paginate: true)
    end

    # Get branching models.
    #
    # @return [Array<Hash>]
    def branching_models
      base_path = ["rest", "branch-utils", "1.0", path]
      get("branchmodel", base_path: base_path, api_v1: false)
    rescue Faraday::ClientError => exception
      error = exception.response[:body]["errors"].first

      if error["exceptionName"] == "com.atlassian.bitbucket.repository.EmptyRepositoryException"
        nil
      elsif error["message"].start_with?("There is no branch model defined for repository ")
        []
      else
        raise($!)
      end
    end

    # Get branch permissions.
    #
    # @return [Array<Hash>]
    def branch_permissions
      base_path = ["rest", "branch-permissions", "2.0", path]
      get(
        "restrictions",
        base_path:     base_path,
        auto_paginate: true,
        api_v1:        false
      )
    end

    # Get access keys.
    #
    # @return [Array<Hash>]
    def access_keys
      base_path = ["rest", "keys", "1.0", path]
      get("ssh", base_path: base_path, auto_paginate: true, api_v1: false)
    end

    # Get team members.
    #
    # @return [Array<Hash>]
    def team_members
      get("permissions", "users", auto_paginate: true)
    end

    # Get group access.
    #
    # @return [Array<Hash>]
    def group_access
      get("permissions", "groups", auto_paginate: true)
    end

    # Get tags.
    #
    # @return [Array<Hash>]
    def tags
      get("tags", auto_paginate: true)
    end

    # Get a tag.
    #
    # @param [String] displayId the URL slug of the tag
    # @return [Hash]
    def tag(displayId)
      get("tags", displayId)
    end

    # Get pull requests.
    #
    # @return [Array<Hash>]
    def pull_requests
      get("pull-requests", query: { state: "all" }, auto_paginate: true)
    end

    # Get a pull request.
    #
    # @param [#to_s] pull_request_id the id of the pull request
    # @return [Hash]
    def pull_request(pull_request_id)
      get("pull-requests", pull_request_id.to_s)
    end

    # Get a diff.
    #
    # @param [String] commit_id The commit ID to get diff data for.
    # @param [String] since The commit ID to compare `commit_id` to.
    # @return [Hash] Bitbucket Server diff data.
    def diff(commit_id, file_path: nil, since: nil)
      path = ["commits", commit_id, "diff", file_path].compact
      query = { since: since }

      get(path, query: query)
    end

    def attachment_content_type(path)
      base_path = [@path, "attachments"]
      head_response = head(path, base_path: base_path, api_v1: false)
      head_response.headers["Content-Type"]
    end

    def attachment(path)
      base_path = [@path, "attachments"]
      get(path, base_path: base_path, api_v1: false)
    end
  end
end
