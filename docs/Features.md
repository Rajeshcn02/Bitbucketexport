<!--
# @title Bitbucket Server Exporter Features
-->

# Bitbucket Server Exporter Features and Limitations

Bitbucket Server Exporter was designed to export repository information and meta data from instances of Bitbucket Server in such a format that can be imported by GitHub Enterprise's `ghe-migrator`. Some models and data can be successfully migrated but it does have some limitations, due to a lack of information provided by Bitbucket Server's API.

## High-level resources

| Source (BBS) | Exported? | Destination (GitHub) | Notes |
| --- | --- | --- | --- |
| Projects | Yes | Organizations | |
| Users | Yes | Users | |
| Project members | Yes | Organization members | |
| Groups | Yes | Teams | May be duplicated across multiple organizations. |
| Repositories | Yes | Repositories | |
| Pull requests | Yes | Pull requests | |

## Repositories

| Source (BBS) | Exported? | Destination (GitHub) | Notes |
| --- | --- | --- | --- |
| Git data | Yes | Git data | |
| Pull request comments | Yes | Pull request comments | |
| Commit comments | Yes | Commit comments | Diff comments are imported verbatim with three exceptions where necessary: see [Diff hunk context lines](#diff-hunk-context-lines) and [Replies to commit comments](#replies-to-commit-comments). |
| Diff comments | Yes | Diff comments | Diff comments are imported verbatim with three exceptions where necessary: see [Diff hunk context lines](#diff-hunk-context-lines), [Nested comment threads in PR reviews](#nested-comment-threads-in-pr-reviews), and [Pull request code reviews](#pull-request-code-reviews). |
| Code reviews | Yes | Code reviews | |
| Forks | No | Forks | Forked repositories are migrated, but as original repos. |
| Attachments | Yes | Yes | |

## Project settings

| Source (BBS) | Exported? | Destination (GitHub) | Notes |
| --- | --- | --- | --- |
| User access | Yes | Organization collaborators | |
| Group access | Yes | Teams | |

## Repository settings

| Source (BBS) | Exported? | Destination (GitHub) | Notes |
| --- | --- | --- | --- |
| Default branches | Yes | Default branches | |
| User access | Yes | Repository collaborators | |
| Group access | Yes | Repository teams | |
| Branch permissions | Yes | Protected branches | Bitbucket Server's branch permissions differ from GitHub's protected branches. The exporter takes a conservative approach and creates more restrictive permissions for deltas that do not have a direct equivalent. |
| Access keys | Yes | Deploy keys | |
| Hooks | No | | Bitbucket Server's "hooks" appear to be similar to GitHub's webhooks and perform similar functions, but they are very different in implementation. BBS' hooks" leverage the Atlassian Marketplace with the intent of integrating with third-party services, while GitHub's webhooks are intended to POST data about GitHub activity directly to HTTP servers. |
| Pull request settings | WIP | Protected branches | These settings will be acommodated for via GitHub's protected branches. For areas where there are permission deltas, a conservative approach will be taken where stricter permission will be applied. |

## User settings

| Source (BBS) | Exported? | Destination (GitHub) | Notes |
| --- | --- | --- | --- |
| Names | Yes | Names | |
| Emails | Yes | Primary email addresses | |
| SSH keys | WIP | SSH and GPG keys | |

## Diversions for parity and compatibility

Naturally, there are some differences between Bitbucket Server and GitHub that requires data to be changed and/or generated to successfully import. In all cases, strong considerations to the user experience were kept in mind while leaving the original data as-is wherever possible.

#### Diff hunk context lines

Bitbucket Server uses ten lines of context where GitHub uses three, which means comments attached to diff lines in BBS can be placed outside of the supported context in GitHub. These comments are moved to the closest context line when necessary. A line is prepended to the comment body that details the original location when a comment is moved.

#### Nested comment threads in PR reviews

Bitbucket Server supports comment threads of a virtually unlimited depth in PR reviews, where GitHub only supports replies to the original comment. Replies that were intended to go into a nested thread will be added as replies to the original comment. When this happens, a line is prepended to the comment body with a link to the comment that it was originally a reply to.

#### Replies to commit comments

Bitbucket Server supports comment threads of a virtually unlimited depth in commit comments, where GitHub supports base-level commit comments. Replies in Bitbucket Server will be added as base-level comments. When this happens, a line is prepended to the comment body with a link to the comment that it was originally a reply to.

#### File comments

Bitbucket Server supports comments on an entire file without specifying a line number, which is not supported in GitHub. File comments are imported to the first diff hunk position, and a line is prepended to the comment body that details that the comment was a file comment in Bitbucket Server.

#### Pull request code reviews

Pull request review comments in Bitbucket Server are submitted without a code review, but a review is required in GitHub. Due to this, comments are grouped into "comment" reviews by user and commit ID with a date of the earliest comment in each group.
