# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::DiffItem do
  describe "#path" do
    context "for a diff item with a destination" do
      subject(:diff) do
        described_class.new(
          "source"      => { "toString" => "source" },
          "destination" => { "toString" => "destination" }
        )
      end

      it "returns the destination path" do
        expect(diff.path).to eq("destination")
      end
    end

    context "for a diff item without a destination" do
      subject(:diff) do
        described_class.new(
          "source"      => { "toString" => "source" },
          "destination" => nil
        )
      end

      it "returns the source path" do
        expect(diff.path).to eq("source")
      end
    end
  end
end
