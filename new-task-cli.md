# new-task CLI

A Linux command that opens a new isolated VSCode window on a separate git branch, so you can run multiple AI agent sessions (like Cline) in parallel without conflicts.

---

## How git worktree works

Normally, a git repository has one working directory tied to one branch at a time. If you want to work on two branches simultaneously, you have to `git stash`, switch branches, work, then switch back — which is slow and error-prone.

**Git worktrees** solve this by letting you check out multiple branches from the same repository into separate directories at the same time. Each directory is its own working copy with its own branch, but they all share the same `.git` history.

```
~/projects/
├── myrepo/              ← main working directory (branch: main)
├── myrepo-fix-login/    ← worktree (branch: task/fix-login)
└── myrepo-refactor-auth/ ← worktree (branch: task/refactor-auth)
```

All three directories point to the same repository. You can work in all of them simultaneously — no conflicts, no stashing.

Key rules:
- Each branch can only be checked out in **one** worktree at a time.
- Worktrees share commits, tags, and remotes — `git push` works normally.
- Removing a worktree does **not** delete the branch.

---

## Installation

### 1. Create the script

```bash
sudo nano /usr/local/bin/new-task
```

Paste the following content:

```bash
#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: new-task <task-name>"
  exit 1
fi

TASK_NAME=$1
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -z "$REPO_ROOT" ]; then
  echo "Error: not inside a git repository"
  exit 1
fi

WORKTREE_PATH="$(dirname $REPO_ROOT)/${REPO_ROOT##*/}-$TASK_NAME"

git worktree add "$WORKTREE_PATH" -b "task/$TASK_NAME"
code --new-window "$WORKTREE_PATH"

echo "Opened: $WORKTREE_PATH (branch: task/$TASK_NAME)"
```

### 2. Make it executable

```bash
sudo chmod +x /usr/local/bin/new-task
```

### 3. Verify

```bash
which new-task
# /usr/local/bin/new-task
```

---

## Usage

Run from anywhere inside a git repository:

```bash
new-task <task-name>
```

**Examples:**

```bash
new-task fix-login-bug
new-task refactor-auth
new-task add-dashboard
```

Each command:
1. Creates a new branch `task/<task-name>`
2. Checks it out into a new directory next to your repo
3. Opens that directory in a new VSCode window

You can then open Cline in each window and work independently.

---

## Cleanup

When a task is done and the branch is merged or no longer needed:

```bash
# Remove the worktree directory
git worktree remove ../myrepo-fix-login-bug

# Optionally delete the branch
git branch -d task/fix-login-bug
```

To list all active worktrees:

```bash
git worktree list
```

---

## Why /usr/local/bin

`/usr/local/bin` is included in `PATH` by default on all Linux distributions. Any executable placed there becomes a system-wide command available in any terminal session, for any user, without extra configuration.
