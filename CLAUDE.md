# SSD Farm — Instructions for Claude Code

Before doing any work in this repo, read these three files in order:
1. docs/PROJECT_STATUS.md — current state, what's done, what's pending, key decisions
2. docs/REQUIREMENTS.md — full feature spec (what to build)
3. docs/DEVELOPMENT_PLAN.md — phase breakdown, folder structure, git workflow

Always follow the git workflow described in DEVELOPMENT_PLAN.md (branch per phase off develop). At the end of any meaningful chunk of work, update docs/PROJECT_STATUS.md to reflect what changed.

---
## Operating Mode — Autonomous Development

From this point on, you (Claude Code) are the sole developer on this project. There is no other assistant or chat feeding you instructions anymore — you work directly from these docs and from the user's replies in this session.

**Per-phase workflow** (repeat for every phase in DEVELOPMENT_PLAN.md, in order, starting from wherever PROJECT_STATUS.md says we left off):
1. Create the branch: `git checkout develop && git pull && git checkout -b feature/phase-<n>-<short-name>` (name matching DEVELOPMENT_PLAN.md's suggested branch name).
2. Work through that phase's "Tasks" and "Claude Code Prompts" from DEVELOPMENT_PLAN.md yourself, one at a time — you don't need the user to paste these to you, they're already written out in that file. Use your own judgement to break a task down further if needed.
3. Run `flutter analyze` after each change and keep it clean before moving to the next task.
4. Commit as you go with clear messages (feat/fix/docs prefixes, as established in the git history).
5. When a phase's tasks are complete, tell the user clearly what was built and give them a short numbered test plan (what to tap/check on their device) so THEY can verify it end-to-end on their real phone — do not mark a phase done until the user confirms it actually works, since you cannot run the app yourself.
6. Once the user confirms it works, update docs/PROJECT_STATUS.md yourself: move that phase from Pending to Done with a summary, note anything left open, and update the "immediate decision needed" line to name the next phase.
7. Merge to develop, push, and ask the user which phase to do next (or continue in DEVELOPMENT_PLAN.md's suggested order if they say "continue").

**Things only the user can do** — always pause and ask the user to do these themselves, giving clear step-by-step instructions, rather than attempting them yourself: anything in the Firebase Console (enabling services, creating console-only resources, viewing billing), anything in the Google Play Console or App Store Connect, physically testing the app on a device, and any product/business decision with real trade-offs (flag these clearly and explain the options, the way decisions have been made throughout this project so far — don't silently pick one).

**Environment note**: this is a Windows machine. Known gotchas (IPv6/Gradle timeouts, NDK version, PowerShell execution policy, Kotlin incremental cache on cross-drive projects, etc.) are logged in PROJECT_STATUS.md — check there before re-diagnosing a new-looking error, it may already be a known issue with a known fix.

**Documentation discipline**: keep REQUIREMENTS.md, DEVELOPMENT_PLAN.md, and PROJECT_STATUS.md consistent with each other and with the actual code at all times. If you build something that changes what a doc says, update the doc in the same commit or the next one — don't let drift accumulate.
