# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::DiffHunkGenerator do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:pull_request_model) do
    repository_model.pull_request_model(8)
  end

  let(:activities) do
    VCR.use_cassette("projects/MIGR8/hugo-pages/pull_requests/8/activities") do
      pull_request_model.activities
    end
  end

  let(:comment_activity) do
    activities.detect { |a| a["id"] == 367 }
  end

  let(:diff_hunk_generator) do
    described_class.new(comment_activity)
  end

  let(:expected_diff_hunk) do
    "@@ -6,10 +6,13 @@\n" +
    " [![Deploy to Heroku](https://cdn.herokuapp.com/deploy/button.svg)](https://heroku.com/deploy)\n" +
    " \n" +
    " Next, create a GitHub repository and add a hugo-pages branch to it.\n" +
    " See [this repository's hugo-pages branch](https://github.com/spraints/hugo-pages/tree/hugo-pages)\n" +
    " for an example.\n" +
    " \n" +
    " Finally, visit your GitHub Pages site! For example, see\n" +
    " [http://pickardayune.com/hugo-pages](http://spraints.github.io/hugo-pages).\n" +
    " \n" +
    "+Added line.\n" +
    "+Another added line."
  end

  describe "#initialize" do
    it 'sets output to ""' do
      output = diff_hunk_generator.output

      expect(output).to eq("")
    end

    it "sets actiity from first parameter" do
      activity = diff_hunk_generator.activity

      expect(activity).to eq(comment_activity)
    end
  end

  describe "#diff_hunk" do
    it "should call #generate! if output is not present" do
      expect(diff_hunk_generator).to receive(:generate!)
      diff_hunk_generator.diff_hunk
    end

    context "when output is present" do
      before { diff_hunk_generator.diff_hunk }

      it "should not call #generate!" do
        expect(diff_hunk_generator).to_not receive(:generate!)
        diff_hunk_generator.diff_hunk
      end
    end

    it "should return diff hunk" do
      diff_hunk = diff_hunk_generator.diff_hunk

      expect(diff_hunk).to eq(expected_diff_hunk)
    end
  end

  describe "#generate!" do
    it "clears the output before generating new output" do
      diff_hunk_generator.generate!
      first_output = diff_hunk_generator.output

      diff_hunk_generator.generate!
      second_output = diff_hunk_generator.output

      expect(first_output).to eq(second_output)
    end

    it "should stop generating lines when the comment is found" do
      segments = comment_activity["diff"]["hunks"].first["segments"]

      comment_line = catch :line do
        segments.each do |segment|
          segment["lines"].each do |line|
            throw(:line, line["line"]) if line["commentIds"] == [116]
          end
        end
      end

      diff_hunk = diff_hunk_generator.diff_hunk
      ends_with_line = diff_hunk.end_with?(comment_line)

      expect(ends_with_line).to be(true)
    end

    it "should populate output" do
      diff_hunk_generator.generate!
      output_is_present = diff_hunk_generator.output.present?

      expect(output_is_present).to be(true)
    end
  end

  describe "#hunks" do
    it "should return diff hunks from activity" do
      hunks = diff_hunk_generator.send(:hunks)
      expected_hunks = comment_activity["diff"]["hunks"]

      expect(hunks).to eq(expected_hunks)
    end
  end

  describe "#comment_id" do
    it "should return the activity's comment ID" do
      comment_id = diff_hunk_generator.send(:comment_id)
      expected_comment_id = comment_activity["comment"]["id"]

      expect(comment_id).to eq(expected_comment_id)
    end
  end

  describe "#range_info" do
    subject(:hunk) do
      {
        "sourceLine"      => 1,
        "sourceSpan"      => 2,
        "destinationLine" => 3,
        "destinationSpan" => 4
      }
    end

    it "uses hunk data in range info" do
      range_info = diff_hunk_generator.send(:range_info, hunk)
      expected_range_info = "@@ -1,2 +3,4 @@"

      expect(range_info).to eq(expected_range_info)
    end
  end

  describe "#line_indicator" do
    context "for added lines" do
      subject(:segment) do
        { "type" => "ADDED" }
      end

      it 'returns "+"' do
        indicator = diff_hunk_generator.send(:line_indicator, segment)
        expect(indicator).to eq("+")
      end
    end

    context "for removed lines" do
      subject(:segment) do
        { "type" => "REMOVED" }
      end

      it 'returns "-"' do
        indicator = diff_hunk_generator.send(:line_indicator, segment)
        expect(indicator).to eq("-")
      end
    end

    context "for context lines" do
      subject(:segment) do
        { "type" => "CONTEXT" }
      end

      it 'returns " "' do
        indicator = diff_hunk_generator.send(:line_indicator, segment)
        expect(indicator).to eq(" ")
      end
    end
  end
end
