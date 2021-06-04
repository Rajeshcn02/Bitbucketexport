# frozen_string_literal: true

module PullRequestHelpers
  include BbsExporter::PullRequestHelpers

  def comment_activities(activities)
    activities.select { |a| commented?(a) }
  end

  def comment_activity_start_with(activities, comment_text)
    comment_activities(activities).detect do |activity|
      activity["comment"]["text"].start_with?(comment_text)
    end
  end
end
