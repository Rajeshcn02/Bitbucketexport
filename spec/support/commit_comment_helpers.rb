# frozen_string_literal: true

module CommitCommentHelpers
  def find_line_comment(diff, comment_text)
    diff["lineComments"].detect { |c| c["text"].start_with?(comment_text) }
  end

  def find_file_comment(diff, comment_text)
    diff["fileComments"].detect { |c| c["text"].start_with?(comment_text) }
  end
end
