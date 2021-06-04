# frozen_string_literal: true

module BranchPermissionsExporterHelpers
  def branches_from_branch_names(*branch_names)
    branch_names.map do |branch_name|
      {
        "id"              => File.join("refs/heads", branch_name),
        "displayId"       => branch_name,
        "type"            => "BRANCH",
        "latestCommit"    => "0000000000000000000000000000000000000000",
        "latestChangeset" => "0000000000000000000000000000000000000000",
        "isDefault"       => false
      }
    end
  end

  def branch_name_matcher(branch_name, active: true)
    {
      "id"        => File.join("refs/heads", branch_name),
      "displayId" => branch_name,
      "active"    => active,
      "type"      => {
        "id"   => "BRANCH",
        "name" => "Branch"
      }
    }
  end

  def branch_pattern_matcher(branch_pattern, active: true)
    {
      "id"        => branch_pattern,
      "displayId" => branch_pattern,
      "active"    => active,
      "type"      => {
        "id"   => "PATTERN",
        "name" => "Pattern"
      }
    }
  end

  def branching_model_matcher(branching_model, active: true)
    {
      "id"        => branching_model["id"],
      "displayId" => branching_model["displayName"],
      "active"    => active,
      "type"      => {
        "id"   => "MODEL_CATEGORY",
        "name" => "Branching model category"
      }
    }
  end

  def matcher_from_type_id(matcher_id, matcher_data, active: true)
    case matcher_id
    when "BRANCH"
      branch_name_matcher(matcher_data, active: active)
    when "PATTERN"
      branch_pattern_matcher(matcher_data, active: active)
    when "MODEL_CATEGORY"
      branching_model_matcher(matcher_data, active: active)
    end
  end

  def user_from_username(username)
    {
      "name"         => username,
      "emailAddress" => "#{username}@github.com",
      "id"           => 1,
      "displayName"  => username,
      "active"       => true,
      "slug"         => username,
      "type"         => "NORMAL",
      "links"        => {
        "self" => [
          {
            "href" => "http://35.162.244.152:7990/users/#{username}"
          }
        ]
      }
    }
  end

  def branch_permission_from_matcher(
    type_id, matcher_data, users: [], active: true
  )
    matcher = matcher_from_type_id(
      type_id, matcher_data, active: active
    )

    {
      "id"         => 1,
      "type"       => "read-only",
      "matcher"    => matcher,
      "users"      => users,
      "groups"     => [],
      "accessKeys" => []
    }
  end

  def branch_permissions_from_matchers(matchers)
    matchers.map do |type_id, matcher_data|
      branch_permission_from_matcher(type_id, matcher_data)
    end
  end

  def branch_permissions_exporter(
    branches:           self.branches,
    branching_models:   self.branching_models,
    branch_permissions: self.branch_permissions
  )
    BbsExporter::BranchPermissionsExporter.new(
      branch_permissions:  branch_permissions,
      branches:            branches,
      branching_models:    branching_models,
      repository_exporter: repository_exporter,
      project:             project
    )
  end
end
