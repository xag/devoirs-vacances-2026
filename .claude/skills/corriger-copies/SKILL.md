---
name: corriger-copies
description: Surveille le dépôt des devoirs de vacances (xag/devoirs-vacances-2026) et corrige les copies rendues par Anaïs & Apo. Lance un watcher shell en arrière-plan qui ne consomme aucun token tant qu'il n'y a rien, et ne réveille Claude que lorsqu'une copie est rendue, puis poste la correction en commentaire. Invoke when the user wants to start watching for and correcting handed-in homework copies, or says something like "surveille les copies" / "corrige les devoirs".
---

# Corriger les copies (devoirs de vacances)

The user launches one session, invokes this skill, and walks away. A **pure-shell watcher**
polls GitHub every few minutes — **zero model tokens** while it waits. The instant a copy is
handed in, the watcher exits, which **wakes Claude** to correct it. Then re-arm and keep going.

Repo: `xag/devoirs-vacances-2026` (public). Context lives in the project memory
(`devoirs-workflow`): the girls are collaborators (Anaïs = `nayunanais-create`, Apo unknown),
corrections are posted as comments by `xag`, tone is warm and encouraging.

## The pieces
The scripts live at the **repository root** in `scripts/` (NOT inside this skill folder).
Run them from the project root — `bash scripts/check-copies.sh` — or with an absolute path.
- `scripts/check-copies.sh` — one programmatic check. Prints issue numbers ready to correct. No tokens.
- `scripts/watch-copies.sh` — loops the check every `$INTERVAL`s, exits (waking Claude) on the first hit.
  It finds `check-copies.sh` next to itself, so it works from any cwd.

## Auth — non-interactive, no `gh auth login`
The SSH key authenticates *git* but NOT the GitHub REST API that `gh` uses. `check-copies.sh`
therefore reads a token from `~/.github_token` (override: `GH_TOKEN_FILE`) into `GH_TOKEN`.
The PAT (fine-grained, scoped to `xag/devoirs-vacances-2026`, **Issues: Read and write**) is
stored in **Bitwarden** — item `GitHub PAT — devoirs de vacances`, username `xag` — and mirrored
to `~/.github_token` for runtime. So `check-copies.sh` resolves the token in this order:
`GH_TOKEN`/`GITHUB_TOKEN` env → `~/.github_token` (override `GH_TOKEN_FILE`) → `bw get password`
on that item using an inherited unlocked `BW_SESSION`. If none resolves, regenerate the PAT and
re-save both places — never fall back to interactive `gh auth login`.

A copy is **ready** when the submit box `- [x] … rend … copie` is ticked (or a "je rends ma
copie" comment exists) **and** the last comment is **not** from `xag` — i.e. not yet handled.
That last-comment rule re-triggers the two-pass hint flow automatically (girl asks a hint →
we answer → girl replies again → ready again), with no state file.

## Procedure

1. **Sanity check.** Confirm the token is loaded (no interactive login): from the project root
   run `bash scripts/check-copies.sh` once immediately. The script reads `~/.github_token` into
   `GH_TOKEN` itself, so `gh` is authenticated non-interactively. Verify with
   `GH_TOKEN="$(tr -d ' \t\r\n' < ~/.github_token)" gh auth status` if needed. If the token file
   is missing, guide the user to create the fine-grained PAT (see Auth above) — never wait on
   `gh auth login`. If the check already lists issues, correct them now (step 4) before arming.

2. **Arm the watcher in the BACKGROUND** (Bash tool with `run_in_background: true`):
   ```
   INTERVAL=300 LOG="<scratchpad>/devoirs-watch.log" bash scripts/watch-copies.sh
   ```
   Use the session scratchpad dir for `LOG`. Tell the user it's armed, they can leave the
   session open, and that it costs no tokens while idle. Then **wait** — do nothing else.

3. **On wake.** When the background command exits, the harness re-invokes you with its stdout =
   the pending issue numbers, one per line.

4. **Correct each pending issue N:**
   - `gh issue view N --repo xag/devoirs-vacances-2026 --json number,title,body,comments,labels`
   - Identify the format (labels/body): QCM, composition, expérience, problème guidé, projet créatif, logique.
   - Read what the girls did: ticked answers in the body (`- [x]`), and/or their comment(s)/photos.
     - Photos in comments: grab the image URL, `curl -sL <url> -o <scratchpad>/f.jpg`, then Read it (vision). Repo is public, no auth needed.
   - **Two-pass hint:** if their latest comment asks for *un indice* on a specific question →
     give a **hint, not the answer**, so they retry. Then **end the hint comment with a fresh
     submit checkbox** so they can re-hand-in by ticking it (the word "copie" must appear in it):
     `- [ ] **On a réessayé — on rend la copie pour la correction !** 📨`
     When they tick that box, the watcher re-fires (detection counts ticked "rendre la copie"
     boxes across the body + all comments vs. the number of replies I've posted). Otherwise
     give the full correction.
   - Post the correction: `gh issue comment N --repo xag/devoirs-vacances-2026 --body-file <scratchpad>/correction.md`
     - **QCM / logique:** score `/N`, per-question ✅/❌ with a short explanation of the right answer and *why*.
     - **Composition / expérience / problème guidé / projet créatif:** warm qualitative feedback — name
       what's good, gently fix mistakes, no harsh numeric score; for guided problems check the reasoning step by step.
   - **Tone:** warm, encouraging, French, addressed to Anaïs & Apo; make them love the subject; emojis used lightly.
   - **Special case — issue #10 (levures de sarrasin):** reveal the yeast-under-microscope photo in the
     correction (kept out of the body so it didn't spoil Q3):
     `![Les levures au microscope](https://commons.wikimedia.org/wiki/Special:FilePath/Yeast%2001.jpg?width=500)`

5. **Re-arm.** Relaunch the watcher in the background (step 2) and tell the user it's watching
   again. Loop forever until the user stops the session or kills the background task.

## Notes
- The watcher appends a heartbeat line to `$LOG` each poll — tail it to confirm it's alive.
- Cadence: change `INTERVAL` (seconds). Default 300 (5 min). The check is cheap, so frequent is fine.
- To stop: end the session, or stop the background watcher task.
- The watcher only lives as long as the session. If the user closes it, re-invoke this skill next time.
