# Git workflow

## Branch policy

MovieStudio uses a deliberately small branch set.

- \`main\` is the only permanent integration branch.
- At most one active feature/integration branch should be used for normal development.
- Small follow-up changes that belong to the current vertical slice are committed to its existing feature branch; do not create a new branch for every implementation step.
- A second feature branch is allowed only when work must proceed independently or a dependency requires a stacked pull request.
- Do not create long-lived branches for experiments. Use a short-lived branch and remove it after its pull request is merged.
- Never delete an unmerged branch or a branch that contains work not present in its target.

## Pull request order

When a feature depends on another unmerged feature, stack the pull requests explicitly and document the base branch. Merge in dependency order. After a parent pull request is merged, retarget the child pull request to the new integration base before merging it.

Do not merge a stacked child pull request directly into \`main\` while its parent is still unmerged; that would duplicate or obscure the dependency history.

## Current transition

The legacy dependency chain PR #1–#6 (Project Foundation, Character System v1/v2, Employee Management, Studio Buildings and Studio Operations) has been merged into \`main\`. The original source branches are historical and contain no work that is absent from \`main\`; they may be deleted after confirming the merged PRs in GitHub.

The current vertical slice is Film Production v1 and all of its follow-up implementation stays on \`feature/film-production-v1\`. No additional feature branch should be created for small fixes or tests in this slice.

The intended working set is \`main\` plus this one active feature branch. After PR #7 is merged, delete its source branch and return to \`main\` only until the next major vertical slice begins.

## Branch cleanup

Delete a source branch only after confirming its pull request is merged and its commits are reachable from the target branch.

GitHub UI: open the merged pull request and use **Delete branch**.

Local cleanup after merge:

~~~bash
git switch main
git pull --ff-only origin main
git branch -d feature/project-foundation
git branch -d feature/character-system-v1
git branch -d feature/character-system-v2
git branch -d feature/employee-management-v1
git branch -d feature/studio-buildings-v1
git branch -d feature/studio-operations-v1
git push origin --delete feature/project-foundation
git push origin --delete feature/character-system-v1
git push origin --delete feature/character-system-v2
git push origin --delete feature/employee-management-v1
git push origin --delete feature/studio-buildings-v1
git push origin --delete feature/studio-operations-v1
~~~

Run the cleanup only for branches whose pull requests have actually been merged. If a local branch is checked out or has unique commits, inspect it rather than forcing deletion.
