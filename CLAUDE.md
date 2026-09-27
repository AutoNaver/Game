@AGENTS.md

# Claude Code specifics

AGENTS.md above is the contract. This section only adds the mechanics of the PR and review loop.

## Local toolchain on the owner's Windows machine

- Godot: `GODOT=$(ls /c/Users/naver/AppData/Local/Microsoft/WinGet/Packages/GodotEngine*/Godot_v4.7.2-stable_win64_console.exe)`
- gdtoolkit: `export PATH="$APPDATA/Python/Python312/Scripts:$PATH"`
- Then `bash scripts/check.sh`.

## PR and Codex review loop

1. Branch from `main`, push early, and open a **draft** PR (`gh pr create --draft`). Use a body that
   follows the PR template and ends with the attribution line from the session instructions.
2. When the milestone is complete: run `scripts/check.sh`, self-review the full diff
   (`git diff main...HEAD`) against the AGENTS.md Review guidelines, fix what you find, then run
   `gh pr ready <n>`. That triggers Codex's round-1 review. If nothing arrives for the head commit
   within about 10 minutes, comment `@codex review`. A clean pass isn't a review: it's an issue
   comment ("Didn't find any major issues", naming the reviewed commit) or a 👍 reaction.
3. Read the findings:
   - `gh api repos/AutoNaver/Game/pulls/<n>/comments` (inline comments; the P0/P1/P2 badge is in the body)
   - `gh api repos/AutoNaver/Game/pulls/<n>/reviews` (check `commit_id` matches the head)
4. Fix all P0/P1s, and cheap P2s, in **one batch** of commits. Reply on every thread with the fixing
   commit, a concrete reason, or "deferred" plus the backlog entry for P2s. Then resolve them:
   ```bash
   gh api graphql -f query='query { repository(owner:"AutoNaver", name:"Game") { pullRequest(number: <n>) {
     reviewThreads(first: 100) { nodes { id isResolved comments(first: 1) { nodes { body path } } } } } } }'
   gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "<id>"}) { thread { isResolved } } }'
   ```
   Escalate P0/P1 findings you disagree with to the owner and leave them unresolved.
5. Comment `@codex review` once for round 2, which verifies the fixes.
6. Merge once the AGENTS.md merge policy holds:
   ```bash
   gh pr update-branch <n>              # if main moved on; then wait for ci again
   gh pr merge <n> --squash --delete-branch
   ```
   Never use `--admin`.
