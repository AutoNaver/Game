@AGENTS.md

# Claude Code specifics

AGENTS.md above is the contract. This section only adds the mechanics of the PR and review loop.

## Local toolchain on the owner's Windows machine

- Godot: `GODOT=$(ls /c/Users/naver/AppData/Local/Microsoft/WinGet/Packages/GodotEngine*/Godot_v4.7.2-stable_win64_console.exe)`
- gdtoolkit: `export PATH="$APPDATA/Python/Python312/Scripts:$PATH"`
- Then `bash scripts/check.sh`.

## PR and Codex review loop

1. Push the branch and `gh pr create --fill`, or with a body following the PR template. End the body with
   the attribution line from the current session instructions.
2. Wait for `ci` (`gh pr checks <n> --watch`) and for the Codex review. Codex auto-reviews new PRs.
   If no review from the Codex bot shows up for the head commit within about 10 minutes, comment
   `@codex review`.
3. Read the findings:
   - `gh pr view <n> --comments`
   - `gh api repos/AutoNaver/Game/pulls/<n>/comments` (inline comments)
   - `gh api repos/AutoNaver/Game/pulls/<n>/reviews` (check `commit_id` matches the head)
4. For each thread, either push a fix and reply naming the commit, or reply with a concrete reason for
   not changing it. Only then resolve it:
   ```bash
   gh api graphql -f query='query { repository(owner:"AutoNaver", name:"Game") { pullRequest(number: <n>) {
     reviewThreads(first: 100) { nodes { id isResolved comments(first: 1) { nodes { body path } } } } } } }'
   gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "<id>"}) { thread { isResolved } } }'
   ```
   Escalate P0/P1 findings you disagree with to the owner and leave them unresolved.
5. After pushing fixes, comment `@codex review` so the new head commit gets reviewed.
6. Merge once the AGENTS.md merge policy holds:
   ```bash
   gh pr update-branch <n>              # if main moved on; then wait for ci again
   gh pr merge <n> --squash --delete-branch
   ```
   Never use `--admin`.
