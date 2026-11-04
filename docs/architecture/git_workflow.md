# Git workflow

## Branch policy

- `main` is the only working and integration branch.
- Do not create feature/fix branches or pull requests for normal project development.
- Make changes directly on `main`, in small, reviewable commits.
- Do not force-push, rewrite shared history, or reset the working tree to discard changes.

## Before changes

Run from the repository root:

```bash
git status --short --branch
git log -1 --oneline
```

Confirm that the current branch is `main` and inspect every local modification before editing. Never overwrite or remove user-owned local changes.

## Synchronizing main

Use fast-forward-only pulls:

```bash
git switch main
git pull --ff-only origin main
```

After a change, inspect the diff and test results before committing. Push ordinary project commits directly to `main`:

```bash
git status --short
git diff --check
git diff
git push origin main
```

## Local generated files

Godot may create `.uid` files during import and editor scans. Keep valid resource UID files; do not delete them as cleanup. Treat logs and other untracked files as user data unless their purpose has been confirmed.

## Accidental branches

Do not create new branches. If an accidental branch is created and confirmed to contain no unique commits, delete it explicitly rather than merging it. For a remote branch:

```bash
git push origin --delete <branch-name>
```

For a local branch, first switch to `main`, then use a non-forced delete:

```bash
git switch main
git branch -d <branch-name>
```
