# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::UrlTemplates do
  let(:templates) { described_class.new.templates }

  it "extracts user info" do
    params = extract("http://localhost:7990/users/unit-test", "user")

    expect(params).to eq(
      "scheme"   => "http",
      "host"     => "localhost:7990",
      "segment"  => "users",
      "user"     => "unit-test"
    )
  end

  it "extracts project info" do
    params = extract(
      "http://localhost:7990/projects/MIGR8",
      "organization"
    )

    expect(params).to eq(
      "scheme"       => "http",
      "host"         => "localhost:7990",
      "organization" => "MIGR8"
    )
  end

  it "extracts team info" do
    params = extract(
      "http://localhost:7990/admin/groups/view?name=stash-users#MIGR8",
      "team"
    )

    expect(params).to eq(
      "scheme" => "http",
      "host"   => "localhost:7990",
      "team"   => "stash-users",
      "owner"  => "MIGR8"
    )
  end

  it "extracts repository info" do
    params = extract(
      "http://localhost:7990/projects/MIGR8/repos/hugo-pages",
      "repository"
    )

    expect(params).to eq(
      "scheme"     => "http",
      "host"       => "localhost:7990",
      "segment"    => "projects",
      "owner"      => "MIGR8",
      "repository" => "hugo-pages"
    )
  end

  it "extracts pull request info" do
    params = extract(
      "http://localhost:7990/projects/MIGR8/repos/hugo-pages" \
      "/pull-requests/1",
      "pull_request"
    )

    expected_params = {
      "scheme"       => "http",
      "host"         => "localhost:7990",
      "segment"      => "projects",
      "owner"        => "MIGR8",
      "repository"   => "hugo-pages",
      "pull_request" => "1"
    }

    expect(params).to eq(expected_params)
  end

  it "extracts pull request comment info" do
    params = extract(
      "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/1/overview?commentId=2",
      "issue_comment",
      "pull_request"
    )

    expect(params).to eq(
      "scheme"        => "https",
      "host"          => "example.com",
      "segment"       => "projects",
      "owner"         => "MIGR8",
      "repository"    => "hugo-pages",
      "number"        => "1",
      "issue_comment" => "2"
    )
  end

  context "extracts pull request review comment info" do
    it "extracts review comment info scoped to projects" do
      params = extract(
        "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/1/overview?commentId=60#r60",
        "pull_request_review_comment"
      )

      expect(params).to eq(
        "scheme"                      => "https",
        "host"                        => "example.com",
        "segment"                     => "projects",
        "owner"                       => "MIGR8",
        "repository"                  => "hugo-pages",
        "pull_request"                => "1",
        "pull_request_review_comment" => "60"
      )
    end

    it "extracts review comment info scoped to users" do
      params = extract(
        "https://example.com/users/morty/repos/microverse/pull-requests/1/overview?commentId=104#r104",
        "pull_request_review_comment"
      )

      expect(params).to eq(
        "scheme"                      => "https",
        "host"                        => "example.com",
        "segment"                     => "users",
        "owner"                       => "morty",
        "repository"                  => "microverse",
        "pull_request"                => "1",
        "pull_request_review_comment" => "104"
      )
    end
  end

  it "extracts tag info" do
    params = extract(
      "http://localhost:7990/projects/MIGR8/repos/hugo-pages/browse" \
      "?at=refs/tags/v1.0.0",
      "release"
    )

    expect(params).to eq(
      "scheme"     => "http",
      "host"       => "localhost:7990",
      "segment"    => "projects",
      "owner"      => "MIGR8",
      "repository" => "hugo-pages",
      "release"    => "v1.0.0"
    )
  end

  it "extracts protected branch info" do
    params = extract(
      "http://localhost:7990/plugins/servlet/branch-permissions/MIGR8" \
      "/hugo-pages#bugfix/branch-permissions-test",
      "protected_branch"
    )

    expect(params).to eq(
      "scheme"           => "http",
      "host"             => "localhost:7990",
      "owner"            => "MIGR8",
      "repository"       => "hugo-pages",
      "protected_branch" => "bugfix/branch-permissions-test"
    )
  end

  it "can handle a specified port number" do
    params = extract("http://example.com:123/u/hubot", "user")

    expect(params).to eq(
      "scheme"   => "http",
      "host"     => "example.com:123",
      "segment"  => "u",
      "user"     => "hubot"
    )
  end

  it "can handle subdomains" do
    params = extract("http://this.has.manysubdomains.com/u/hubot", "user")

    expect(params).to eq(
      "scheme"   => "http",
      "host"     => "this.has.manysubdomains.com",
      "segment"  => "u",
      "user"     => "hubot"
    )
  end

  it "can handle localhost" do
    params = extract("http://localhost/u/hubot", "user")

    expect(params).to eq(
      "scheme"   => "http",
      "host"     => "localhost",
      "segment"  => "u",
      "user"     => "hubot"
    )
  end

  def extract(uri, *template_name)
    uri = Addressable::URI.parse(uri)
    template = Addressable::Template.new(template_name.inject(templates, :[]))
    template.extract(uri)
  end
end
