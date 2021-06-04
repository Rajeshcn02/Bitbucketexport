# frozen_string_literal: true

require "spec_helper"

require "tmpdir"
require "fileutils"

describe BbsExporter::SerializedModelWriter do
  subject do
    BbsExporter::SerializedModelWriter.new(dir, "organizations")
  end

  let(:data) do
    {
      "something" => "this is a thing",
      "something2" => "this is also a thing"
    }
  end
  let(:dir) { Dir.mktmpdir("bbs-export-test") }

  after do
    FileUtils.remove_entry_secure(dir)
  end

  it "rolls over a file" do
    101.times { subject.add(data) }
    subject.close

    expect(data_in("organizations_000001.json").size).to eq(100)
    expect(data_in("organizations_000002.json").size).to eq(1)
  end

  it "jsonifies the data" do
    subject.add(data)
    subject.close

    expect(data_in("organizations_000001.json")).to eq([data])
  end

  def data_in(filename)
    path = File.join(dir, filename)
    json_data = File.read(path)
    JSON.load(json_data)
  end
end
