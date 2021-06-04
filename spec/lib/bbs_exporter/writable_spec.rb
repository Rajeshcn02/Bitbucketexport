# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::Writable do
  let(:pseudo_exporter) do
    PseudoExporter.new(
      model:            pseudo_model,
      bitbucket_server: bitbucket_server
    )
  end

  let(:pseudo_model) do
    PseudoModel.new.tap do |model|
      model["links"] = {
        "self" => [
          {"href" => "http://hostname.com/path"}
        ]
      }
    end
  end

  let(:archiver) { double BbsExporter::ArchiveBuilder }
  let(:serializer) { double BbsExporter::RepositorySerializer }

  before(:each) do
    PseudoExporter.include(BbsExporter::Writable)
    allow(pseudo_exporter).to receive(:archiver).and_return(archiver)
    allow(BbsExporter::RepositorySerializer).to receive(:new).and_return(serializer)
  end

  describe "#serialize" do
    context "when the archiver has written this model before" do
      before(:each) do
        allow(archiver).to receive(:seen?)
          .with("repository", "http://hostname.com/path")
          .and_return(true)
      end

      it "does not write the model" do
        expect(archiver).to_not receive(:write)
        expect(archiver).to_not receive(:seen)
        expect(pseudo_exporter.serialize("repository", pseudo_model)). to be_falsey
      end
    end

    context "when the archiver has not written this model before" do
      before(:each) do
        allow(archiver).to receive(:seen?)
          .with("repository", "http://hostname.com/path")
          .and_return(false)
      end

      it "does writes the model" do
        expect(serializer).to receive(:serialize)
        expect(archiver).to receive(:write)
        expect(archiver).to receive(:seen).with("repository", "http://hostname.com/path")
        expect(pseudo_exporter.serialize("repository", pseudo_model)). to be_truthy
      end
    end
  end
end
