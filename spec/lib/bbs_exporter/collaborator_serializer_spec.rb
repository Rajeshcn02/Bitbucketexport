# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::CollaboratorSerializer do
  let(:repository_model) do
    bitbucket_server.project_model("MIGR8").repository_model("hugo-pages")
  end

  let(:repository_team_member) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/team_members") do
      repository_model.team_members.first
    end
  end

  subject { described_class.new }

  describe "#serialize" do
    subject { described_class.new.serialize(repository_team_member) }

    it "returns a serialized collaborator hash" do
      expected = {
        user:       "https://example.com/users/dpmex4527",
        permission: "admin",
      }

      expected.each do |key, value|
        expect(subject[key]).to eq(value), "`#{key}` does not match \n\n  expected: #{value.inspect}\n       got: #{subject[key].inspect}\n"
      end
    end
  end
end
