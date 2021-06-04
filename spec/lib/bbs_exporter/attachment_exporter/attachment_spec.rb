# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::AttachmentExporter::Attachment do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:repository) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/repository") do
      repository_model.repository
    end
  end

  def create_attachment(
    link: "attachment:6/328eabcebf%2Foctocat.png", tooltip: " 'octocat'"
  )
    described_class.new(
      link:             link,
      tooltip:          tooltip,
      repository_model: repository_model,
      archiver:         current_export.archiver
    )
  end

  before(:each) do
    allow(repository_model).to receive(:repository).and_return(repository)
  end

  describe "#repository_id" do
    it "returns a String that represents the repository ID" do
      expect(create_attachment.repository_id).to eq("6")
    end
  end

  describe "#filename" do
    it "returns a MD5-encoded filename of the link with the extension" do
      expect(create_attachment.filename).to eq(
        "131b93cdc85108ef1c75907eaf5bd5ae.png"
      )
    end
  end

  describe "#path" do
    it 'splits link into array items with "%2F"' do
      expect(create_attachment.path).to eq(["328eabcebf", "octocat.png"])
    end

    it 'converts "+" into spaces' do
      attachment = create_attachment(link: "attachment:6/328eabcebf%2Focto+cat.png")
      expect(attachment.path).to eq(["328eabcebf", "octo cat.png"])
    end

    it 'converts "%2B" into "+"' do
      attachment = create_attachment(link: "attachment:6/328eabcebf%2Focto%2Bcat.png")
      expect(attachment.path).to eq(["328eabcebf", "octo+cat.png"])
    end
  end

  describe "#encoded_path" do
    it "encodes characters with percent-encoding" do
      attachment = create_attachment(link: "attachment:6/328eabcebf/octo%5B%5Dcat.png")
      expect(attachment.encoded_path).to eq(["328eabcebf", "octo%5B%5Dcat.png"])
    end

    it 'encodes spaces to "%20"' do
      attachment = create_attachment(link: "attachment:6/328eabcebf/octo%20cat.png")
      expect(attachment.encoded_path).to eq(["328eabcebf", "octo%20cat.png"])
    end
  end

  describe "#asset_name" do
    it "returns the last array item from #path" do
      attachment = create_attachment(link: "attachment:6/328eabcebf/octocat.png")
      expect(attachment.asset_name).to eq("octocat.png")
    end
  end

  describe "#rewritten_link" do
    it "creates URLs for attachments" do
      expect(create_attachment.rewritten_link).to eq(
        "https://example.com/projects/MIGR8/repos/hugo-pages/attachments/" \
        "328eabcebf/octocat.png"
      )
    end

    it "percent-encodes characters" do
      attachment = create_attachment(link: "attachment:6/328eabcebf/octo[]cat.png")

      expect(attachment.rewritten_link).to eq(
        "https://example.com/projects/MIGR8/repos/hugo-pages/attachments/" \
        "328eabcebf/octo%5B%5Dcat.png"
      )
    end
  end

  describe "#asset_content_type" do
    it "calls content_type.content_type" do
      attachment = create_attachment

      expect(attachment.content_type).to receive(:content_type)

      attachment.asset_content_type
    end
  end

  describe "#asset_url" do
    it "creates a tarball:// url" do
      expect(create_attachment.asset_url).to eq(
        "tarball://root/attachments/131b93cdc85108ef1c75907eaf5bd5ae.png"
      )
    end
  end

  describe "#archive!" do
    it "fetches attachments for supported file types" do
      allow(current_export.archiver).to receive(:save_attachment)

      allow(repository_model).to receive(:attachment_content_type).with(
        ["328eabcebf", "octocat.png"]
      ).and_return("image/png")

      expect(repository_model).to receive(:attachment).with(
        ["328eabcebf", "octocat.png"]
      )

      create_attachment.archive!
    end

    it "saves attachments to the archive for supported file types" do
      file_double = double(:file_double)

      allow(repository_model).to receive(:attachment).with(
        ["328eabcebf", "octocat.png"]
      ).and_return(file_double)

      allow(repository_model).to receive(:attachment_content_type).with(
        ["328eabcebf", "octocat.png"]
      ).and_return("image/png")

      expect(current_export.archiver).to receive(:save_attachment).with(
        file_double, "131b93cdc85108ef1c75907eaf5bd5ae.png"
      )

      create_attachment.archive!
    end

    it "does not fetch attachments for unsupported file types" do
      allow(repository_model).to receive(:attachment_content_type).with(
        ["328eabcebf", "octocat.png"]
      ).and_return("image/svg+xml")

      expect(repository_model).to_not receive(:attachment)

      create_attachment.archive!
    end

    it "does not save attachments to the archive for unsupported file types" do
      allow(repository_model).to receive(:attachment_content_type).with(
        ["328eabcebf", "octocat.png"]
      ).and_return("image/svg+xml")

      expect(current_export.archiver).to_not receive(:save_attachment)

      create_attachment.archive!
    end

    it "calls #content_type_error when encountering an unsupported file type" do
      allow(repository_model).to receive(:attachment_content_type).with(
        ["328eabcebf", "octocat.png"]
      ).and_return("image/svg+xml")

      attachment = create_attachment

      expect(attachment).to receive(:content_type_error)

      attachment.archive!
    end
  end

  describe "#markdown_link" do
    it "returns a rewritten link for supported file types" do
      expect(repository_model).to receive(:attachment_content_type).with(
        ["328eabcebf", "octocat.png"]
      ).and_return("image/png")

      expect(create_attachment.markdown_link).to eq(
        "(https://example.com/projects/MIGR8/repos/hugo-pages/attachments/" \
        "328eabcebf/octocat.png 'octocat')"
      )
    end

    it "returns the original link for unsupported file types" do
      expect(repository_model).to receive(:attachment_content_type).with(
        ["328eabcebf", "octocat.png"]
      ).and_return("image/svg+xml")

      expect(create_attachment.markdown_link).to eq(
        "(attachment:6/328eabcebf%2Foctocat.png 'octocat')"
      )
    end
  end
end
