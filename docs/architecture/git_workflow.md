# Git workflow

## Branch policy

- `D:/Develop/MovieStudio` is the sole working checkout and Godot project. Keep project archives outside it.
- `main` is the only working and integration branch.
- Do not create feature/fix branches or pull requests for normal project development.
- Make changes directly on `main`, in small, reviewable commits.
- Do not force-push, rewrite shared history, or reset the working tree to discard changes.

## Before changes

Run from the repository root:

```bash
git status --short --branch
git rev-parse --show-toplevel
git branch --show-current
```

Confirm that the current branch is `main` and inspect every local modification before editing. Never overwrite or remove user-owned local changes.

## Synchronizing main

Fetch and inspect before integrating remote changes.

```bash
git fetch origin
git log --left-right --oneline HEAD...origin/main
```

Fast-forward when the remote only leads. When both sides have commits, merge on `main`, resolve conflicts and rerun affected checks. After a completed and tested change, commit it, check for remote changes again and publish it directly to `main`.

```bash
git status --short
git diff --check
git diff
git push origin main
git rev-parse HEAD
git ls-remote origin refs/heads/main
```

The stage is complete when all required changes are published and the local and remote SHAs match.

## Local generated files

Commit valid Godot resource UIDs alongside their sources. Preserve local logs and other untracked files until their purpose has been confirmed. Keep caches outside commits.
