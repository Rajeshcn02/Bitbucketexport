# frozen_string_literal: true

class BbsExporter
  class BranchPermissionsExporter
    include Writable
    include SafeExecution
    include TimeHelpers

    # This Hash helps the branches_from_branch_pattern method build
    # Regexp-compatible regular expressions from the proprietary Bitbucket
    # branch permission pattern syntax.  See:
    # https://confluence.atlassian.com/bitbucketserver/branch-permission-patterns-776639814.html.
    BRANCH_PATTERN_REGEX = {
      # Convert "**": zero or more path segments.
      # Starts at the beginning of the string or at a /, followed by two
      # escaped "*"s, then ends with the end of the string or another /.
      /(\A|\/)\\\*\\\*(\z|\/)/ => "\\1([^/]+/)*([^/]+)?\\2",

      # Convert "*": zero or more characters (not including path separators).
      # Any remaining escaped "*" characters that the "**" regex above didn't
      # find.  This must be followed by "**" above because "**" has stricter
      # rules.
      /\\\*/ => "[^/]*",

      # Convert "?": one character (any character except path separators.
      # Easy peasy!  Find those escaped "?"s, por favor.
      /\\\?/ => "[^/]"
    }

    log_handled_exceptions_to :logger

    attr_reader :branch_permissions, :branches, :branching_models,
      :repository_exporter, :archiver, :repository, :project

    def initialize(
      repository_exporter:, project:, branches:, branch_permissions:,
      branching_models:
    )
      @repository_exporter = repository_exporter
      @archiver = current_export.archiver
      @branch_permissions = branch_permissions
      @branches = branches
      @branching_models = branching_models
      @repository = repository_exporter.repository
      @project = project
    end

    # Alias for `branch_permissions`
    #
    # @return [Hash]
    def model
      branch_permissions
    end

    # References the current export
    #
    # @return [BbsExporter]
    def current_export
      repository_exporter.current_export
    end

    def logger
      current_export.logger
    end

    def regex_from_branch_pattern(branch_pattern)
      # Escape the entire branch pattern, then loop through
      # BRANCH_PATTERN_REGEX and build a Regexp string from the branch
      # permission pattern syntax.
      pattern_regex = Regexp.escape(branch_pattern)
      BRANCH_PATTERN_REGEX.each do |match, regex|
        pattern_regex.gsub!(match, regex)
      end

      # Add anchors.  We probably could use "^" and "$", but "\A" and "\z" is
      # safer.
      "\\A#{pattern_regex}\\z"
    end

    def branches_from_branch_pattern(branch_pattern)
      # These bits of information are excerpts from
      # https://confluence.atlassian.com/bitbucketserver/branch-permission-patterns-776639814.html.
      #
      # Bitbucket Server supports a powerful type of pattern syntax for
      # matching branch names (similar to pattern matching in Apache Ant). You
      # can use branch permission patterns when adding branch permissions at
      # the project or repository level to apply a branch permission to
      # multiple branches.
      #
      # These expressions can use the following wild cards:
      #
      #   ?   Matches one character (any character except path separators)
      #   *   Matches zero or more characters (not including path separators)
      #   **  Matches zero or more path segments.
      #
      # Pattern used in branch permissions match against all refs pushed to
      # Bitbucket Server (i.e. branches and tags).
      #
      # In Git, branch and tag names can be nested in a namespace by using
      # directory syntax within your branch names, e.g. stable/1.1. The '**'
      # wild card selector enables you to match arbitrary directories.
      #
      #   * A pattern can contain any number of wild cards.
      #   * If the pattern ends with / then ** is automatically appended - e.g.
      #     foo/ will match any branches or tags containing a foo path segment
      #   * Patterns only need to match a suffix of the fully qualified branch
      #     or tag name. Fully qualified branch names look like
      #     refs/heads/master, while fully qualified tags look like
      #     refs/tags/1.1.
      #
      # Example patterns tested against branch name bugfix/that/cool/perm-test:
      #
      # *                                      matches
      # **                                     matches
      # **/perm-test                           matches
      # **cool**                               does not match
      # **perm-test                            does not match
      # **test                                 does not match
      # *test                                  matches
      # bug**                                  does not match
      # bug***                                 does not match
      # bugfix                                 does not match
      # bugfix**                               does not match
      # bugfix/**                              matches
      # bugfix/th**/perm-test                  does not match
      # bugfix/th**ol/perm-test                does not match
      # bugfix/that/c**/perm-test              matches
      # bugfix/that/c*/perm-test               matches
      # cool                                   does not match
      # cool**                                 does not match
      # cool/perm-test                         matches
      # perm*                                  matches
      # perm**                                 matches
      # perm-test**                            matches
      # refs                                   does not match
      # refs/heads/*                           does not match
      # refs/heads/**                          matches
      # refs/heads/**cool**                    does not match
      # refs/heads/bug**                       does not match
      # refs/heads/bugfix/that/cool/perm-test  matches
      # that/cool/perm-test                    matches
      # perm-tes?                              matches

      # Patterns that start with "**" followed by a character that isn't "/"
      # will never match.  The BRANCH_PATTERN_REGEX constant could be modified
      # to do follow this rule, but this way is faster and easier to read.
      return [] if branch_pattern.match(/\A\*\*[^\/]/)

      # Bitbucket Server appends a "**" to patterns that end with "/".
      branch_pattern += "**" if branch_pattern.end_with?("/")

      # Build a Regexp-compatible string from the branch permission pattern
      # syntax.
      branch_regex = regex_from_branch_pattern(branch_pattern)

      # For each branch, remove path segments from the beginning of the
      # fully-qualified branch name (starts with "refs/heads/") until a path
      # matches the regex generated above or no more segments are left.
      #
      # As an example, for "refs/heads/bugfix/that/cool/perm-test", this checks:
      #
      # refs/heads/bugfix/that/cool/perm-test
      #      heads/bugfix/that/cool/perm-test
      #            bugfix/that/cool/perm-test
      #                   that/cool/perm-test
      #                        cool/perm-test
      #                             perm-test
      branches.select do |branch|
        branch_name = branch["id"]
        splits = branch_name.split("/").count

        (1..splits).detect do |split_limit|
          branch_name_suffix = branch_name.split("/", split_limit).last
          branch_name_suffix.match(branch_regex)
        end
      end
    end

    def branching_model_category_prefixes_by_id
      @branching_model_category_prefixes ||= Hash[
        branching_models["types"].map do |type|
          [type["id"], type["prefix"]]
        end
      ]
    end

    def branches_from_branching_model_category(branching_model)
      prefix = branching_model_category_prefixes_by_id[branching_model]
      regex = /\A#{prefix}/

      branches.select do |branch|
        branch["displayId"].match(regex)
      end
    end

    def append_branch_permission(branch_name, branch_permission)
      (@branch_permissions_by_branch[branch_name] ||= []) << branch_permission
    end

    def convert_from_branch_name(branch_permission)
      append_branch_permission(
        branch_permission["matcher"]["displayId"],
        branch_permission
      )
    end

    def convert_from_branch_pattern(branch_permission)
      branches = branches_from_branch_pattern(
        branch_permission["matcher"]["displayId"]
      )

      branches.each do |branch|
        append_branch_permission(
          branch["displayId"],
          branch_permission
        )
      end
    end

    def convert_from_branching_model_category(branch_permission)
      branches = branches_from_branching_model_category(
        branch_permission["matcher"]["id"]
      )

      branches.each do |branch|
        append_branch_permission(
          branch["displayId"],
          branch_permission
        )
      end
    end

    def convert_from_branching_model_branch(branch_permission)
      matcher_id = branch_permission["matcher"]["id"]
      branch = branching_models[matcher_id]

      append_branch_permission(
        branch["displayId"],
        branch_permission
      )
    end

    def branch_permission_active?(branch_permission)
      branch_permission["matcher"]["active"]
    end

    def convert_branch_permissions
      # Bitbucket Server has branch permissions for branch names, branch
      # patterns, and branching models.  See:
      # https://confluence.atlassian.com/bitbucketserver/using-branch-permissions-776639807.html

      # GitHub only supports protected branches for explicit branches.  To
      # accomodate for this, the applicable permissions are resolved and
      # aggregated for each branch to be serialized into protected branches
      # later.
      branch_permissions.each do |branch_permission|
        next unless branch_permission_active?(branch_permission)

        matcher_type_id = branch_permission["matcher"]["type"]["id"]

        case matcher_type_id
        when "BRANCH"
          convert_from_branch_name(branch_permission)
        when "PATTERN"
          convert_from_branch_pattern(branch_permission)
        when "MODEL_CATEGORY"
          convert_from_branching_model_category(branch_permission)
        when "MODEL_BRANCH"
          convert_from_branching_model_branch(branch_permission)
        else
          raise(
            NotImplementedError,
            %("#{matcher_type_id}" is not a valid branch permission type ID!)
          )
        end
      end
    end

    def branch_permissions_by_branch
      return @branch_permissions_by_branch if @branch_permissions_by_branch

      @branch_permissions_by_branch = {}
      convert_branch_permissions

      @branch_permissions_by_branch
    end

    def export
      branch_permissions_by_branch.each do |branch_name, branch_permissions|
        protected_branch = {
          "branch_name"        => branch_name,
          "branch_permissions" => branch_permissions,
          "repository"         => repository
        }

        serialize("protected_branch", protected_branch)
      end
    end
  end
end
