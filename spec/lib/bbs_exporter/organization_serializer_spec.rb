# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::OrganizationSerializer do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:project) do
    VCR.use_cassette("projects/MIGR8") do
      project_model.project
    end
  end

  subject { described_class.new }

  describe "#serialize" do
    subject { described_class.new.serialize(project) }

    it "returns a serialized User hash" do
      expected = {
        type:        "organization",
        url:         "https://example.com/projects/MIGR8",
        login:       "MIGR8",
        name:        "Migrate Me",
        description: "Test project description",
        website:     nil,
        location:    nil,
        email:       nil
      }

      expected.each do |key, value|
        expect(subject[key]).to eq(value)
      end
    end
  end
end
