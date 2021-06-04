# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::AttachmentExporter::ContentType do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:content_type) do
    described_class.new(
      repository_model: repository_model,
      path:             ["328eabcebf", "octocat.png"]
    )
  end

  describe "#raw_content_type" do
    it "returns the content type from response headers" do
      expect(repository_model).to receive(:attachment_content_type).with(
        ["328eabcebf", "octocat.png"]
      )

      content_type.raw_content_type
    end
  end

  describe "#parsed_content_type" do
    it 'returns "image/png" when content type is "image/png"' do
      allow(content_type).to receive(:raw_content_type).and_return("image/png")

      expect(content_type.parsed_content_type).to eq("image/png")
    end

    it 'returns "text/plain" when content type is "text/plain;charset=UTF-8"' do
      allow(content_type).to receive(:raw_content_type).and_return(
        "text/plain;charset=UTF-8"
      )

      expect(content_type.parsed_content_type).to eq("text/plain")
    end

    it "returns #raw_content_type when a type is unknown to MIME::Types" do
      allow(content_type).to receive(:raw_content_type).and_return(
        "application/x-wacky"
      )

      expect(content_type.parsed_content_type).to eq("application/x-wacky")
    end
  end

  describe "#content_type" do
    it 'returns "text/x-log" when content type is "application/octet-stream"' do
      allow(content_type).to receive(:raw_content_type).and_return(
        "application/octet-stream"
      )

      expect(content_type.content_type).to eq("text/x-log")
    end
  end

  describe "#supported?" do
    it 'returns true when content type is "image/png"' do
      allow(content_type).to receive(:raw_content_type).and_return("image/png")

      expect(content_type.supported?).to eq(true)
    end

    it 'returns true when content type is "application/octet-stream"' do
      allow(content_type).to receive(:raw_content_type).and_return(
        "application/octet-stream"
      )

      expect(content_type.supported?).to eq(true)
    end

    it 'returns true when content type is "text/plain;charset=UTF-8"' do
      allow(content_type).to receive(:raw_content_type).and_return(
        "text/plain;charset=UTF-8"
      )

      expect(content_type.supported?).to eq(true)
    end

    it 'returns false when content type is "application/x-wacky"' do
      allow(content_type).to receive(:raw_content_type).and_return(
        "application/x-wacky"
      )

      expect(content_type.supported?).to eq(false)
    end
  end
end
