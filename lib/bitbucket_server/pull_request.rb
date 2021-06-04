# frozen_string_literal: true

class BitbucketServer
  class PullRequest < Model
    attr_reader :repository_model, :project_model, :id

    def initialize(connection:, repository_model:, id:)
      @connection = connection
      @repository_model = repository_model
      @project_model = repository_model.project_model
      @id = id.to_s
      @path = [repository_model.path, "pull-requests", @id]
    end

    # Get the pull request.
    #
    # @return [Hash]
    def pull_request
      get
    end

    # Get commits.
    #
    # @return [Array<Hash>]
    def commits
      get("commits", auto_paginate: true)
    # Bitbucket Server's API returns a 404 when there are no commits. This is
    # undocumented and likely caused by an error state, but it still happens!
    rescue Faraday::ResourceNotFound
      []
    end

    # Get a pull request comment
    #
    # @param [#to_s] comment_id the id of the pull request comment
    # @return [Hash]
    def comment(comment_id)
      get("comments", comment_id.to_s)
    rescue Faraday::ResourceNotFound
      []
    end

    # Get activities.
    #
    # @param [Integer] from_id The id of the activity item to use as the first
    #   item in the returned page.
    # @param [String] from_type The type of the activity item specified by
    #   from_id (either "COMMENT" or "ACTIVITY").
    # @return [Array<Hash>]
    def activities(from_id: nil, from_type: nil)
      query = {
        fromId: from_id,
        fromType: from_type
      }

      get("activities", query: query, auto_paginate: true)
    end

    # Get a diff.
    #
    # @param [String] path The path to the file which should be diffed.
    # @param [Integer] context_lines The number of context lines to include
    #   around added/removed lines in the diff.
    # @param [String] diff_type The type of diff being requested.  When
    #   `with_comments` is `true` this works as a hint to the system to attach
    #   the correct set of comments to the diff.
    # @param [String] since_id The since commit hash to stream a diff between
    #   two arbitrary hashes.
    # @param [String] src_path The previous path to the file, if the file has
    #   been copied, moved or renamed.
    # @param [String] until_id The until commit hash to stream a diff between
    #   two arbitrary hashes.
    # @param [String] whitespace Optional whitespace flag which can be set to
    #   `ignore-all`.
    # @param [Boolean] with_comments `true` to embed comments in the diff (the
    #   default); otherwise, `false` to stream the diff without comments.
    # @return [Array<Hash>]
    def diff(
      path, context_lines: nil, diff_type: nil, since_id: nil, src_path: nil,
      until_id: nil, whitespace: nil, with_comments: nil
    )
      query = {
        contextLines: context_lines,
        diffType:     diff_type,
        sinceId:      since_id,
        srcPath:      src_path,
        untilId:      until_id,
        whitespace:   whitespace,
        withComments: with_comments
      }

      get("diff", path, query: query)
    end
  end
end
