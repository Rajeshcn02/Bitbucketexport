# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::UserSerializer do
  let(:user) do
    VCR.use_cassette("users/unit-test") do
      bitbucket_server.user
    end
  end
  subject { described_class.new }

  describe "#serialize" do
    subject { described_class.new.serialize(user) }

    it "returns a serialized User hash" do
      expected = {
        type:       "user",
        url:        "https://example.com/users/unit-test",
        login:      "unit-test",
        name:       "Unit Test",
        company:    nil,
        website:    nil,
        location:   nil,
        emails:     [
          {
            "address" => "unit-test@github.com",
            "primary" => true
          }
        ],
        created_at: "2017-05-25T21:13:25Z"
      }

      # Bitbucket Server does not save information on when users were created
      subject[:created_at] = "2017-05-25T21:13:25Z"

      expected.each do |key, value|
        expect(subject[key]).to eq(value)
      end
    end
  end
end
