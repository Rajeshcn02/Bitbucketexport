# frozen_string_literal: true

require "bitbucket_server/model"
require "bitbucket_server/project"
require "bitbucket_server/repository"
require "bitbucket_server/pull_request"

class BitbucketServer
  class UserNotFound < StandardError; end

  attr_reader :connection
  delegate :get, to: :connection

  def initialize(
    base_url:, user: nil, password: nil, token: nil, read_timeout: nil,
    open_timeout: nil, retries: nil, ssl_verify: nil
  )
    @connection = Connection.new(
      base_url:      base_url,

      user:          user,
      password:      password,
      token:         token,

      read_timeout:  read_timeout,
      open_timeout:  open_timeout,
      retries:       retries,
      ssl_verify:    ssl_verify
    )
  end

  # Returns the username of the currently authenticated user
  #
  def authenticated_user
    @authenticated_user ||= (connection.user || get_authenticated_user)
  end

  # Get the version information for the Bitbucket Server instance
  #
  # @return [Hash]
  def version
    get("application-properties")
  end

  # Search for a namespace on Bitbucket Server
  #
  # @example
  #   BitbucketServer.namespaces(search: 'gitlabhq')
  # @param [String] search namespace to search for
  # @return [Array]
  def namespaces(search:)
    get do |request|
      request.url "namespaces"
      request.params["search"] = search
    end.body
  end

  # Create a BitbucketServer::Project model.
  #
  # @param [String] project_key the project_key of the project
  # @return [BitbucketServer::Project]
  def project_model(project_key)
    Project.new(connection: @connection, key: project_key)
  end

  # Get a single user or currently authenticated user
  #
  # @param [String] username Username of the user to fetch.
  # @return [Hash] When a username is provided, returns the requested user.
  #   When username is not specified, the currently authenticated user is
  #   returned.
  def user(username = authenticated_user)
    # There is a users/{username} route in the BBS API, but it only accepts a
    # user slug.  Unfortuntely, user slugs substitute some characters (like @
    # and %) with _, and the mapping is undocumented.
    #
    # To make things more confusing, BBS also accepts characters like 🌭 (the
    # hot dog emoji) in usernames, and this character isn't substituted with _.
    # Also, ed@smith and ed%smith, which are both valid usernames, each would
    # use ed_smith as a slug.  One user would claim it, and the other user
    # would not be accessible through users/.
    #
    # In order to be able to fetch every user, we get data from admin/users/
    # and filter by username.  The filter also searches for first and last
    # names, email addresses, etc., so we call #detect to pick out the correct
    # user by username, which is guaranteed to be unique.

    users = get(
      "admin", "users",
      query:         { filter: username },
      auto_paginate: true
    )

    users.detect { |u| u["name"] == username } || raise(
      UserNotFound, "Could not find user with username: #{username}"
    )
  end

  # Get the groups
  #
  # @return [Array<Hash>]
  def groups
    get("admin", "groups", auto_paginate: true)
  end

  # Get repositories.
  #
  # @return [Array<Hash>]
  def repositories
    get("repos", auto_paginate: true)
  end

  # Get the group members
  #
  # @param [String] group_name the group name
  # @return [Array<Hash>]
  def group_members(group_name)
    get(
      "admin", "groups", "more-members",
      query:         { context: group_name },
      auto_paginate: true
    )
  end

  def clear_cache
    connection.http_cache.clear
  end

  # Return authentication being used.
  #
  # @return [String] Returns password or token

  def password_or_token
    connection.token_authenticated? ? connection.token : connection.password
  end

  private

  # Gets the username of the currently authenticated user
  #
  def application_properties
    url = connection.encode_url(path: ["application-properties"])
    connection.faraday_safe(:get, url)
  end

  def get_authenticated_user
    username = application_properties.headers[:x_ausername]
    raise(AuthenticationError) unless username

    URI.decode(username)
  end

  class AuthenticationError < StandardError
    def message
      "Unable to connect to Bitbucket Server with the provided credentials"
    end
  end
end
