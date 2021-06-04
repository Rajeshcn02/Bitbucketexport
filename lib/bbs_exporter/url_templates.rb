# frozen_string_literal: true

class BbsExporter::UrlTemplates
  def templates
    {
      "user"                        => "{scheme}://{+host}/{segment}/{user}",
      "organization"                => "{scheme}://{+host}/projects/{organization}",
      "team"                        => "{scheme}://{+host}/admin/groups/view?name={team}\#{owner}",
      "repository"                  => "{scheme}://{+host}/{segment}/{owner}/repos/{repository}",
      "issue_comment"               => {
        "pull_request" => "{scheme}://{+host}/{segment}/{owner}/repos/{repository}/pull-requests/{number}/overview?commentId={issue_comment}"
      },
      "issue_event"                 => {
        "pull_request" => "{scheme}://{+host}/{segment}/{owner}/repos/{repository}/pull-requests/{number}#event-{event}"
      },
      "pull_request"                => "{scheme}://{+host}/{segment}/{owner}/repos/{repository}/pull-requests/{pull_request}",
      "pull_request_review_comment" => "{scheme}://{+host}/{segment}/{owner}/repos/{repository}/pull-requests/{pull_request}/overview?commentId={pull_request_review_comment}#r{pull_request_review_comment}",
      "commit_comment"              => "{scheme}://{+host}/{segment}/{owner}/repos/{repository}/commits/{commit}?commentId={commit_comment}#commitcomment-{commit_comment}",
      "release"                     => "{scheme}://{+host}/{segment}/{owner}/repos/{repository}/browse?at=refs/tags/{release}",
      "protected_branch"            => "{scheme}://{+host}/plugins/servlet/branch-permissions/{owner}/{repository}{#protected_branch}"
    }
  end
end
