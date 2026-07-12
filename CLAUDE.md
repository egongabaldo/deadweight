# Working in this repo

Godot 4 project — see [README.md](README.md) for what the game is and how the
scenes/scripts are organized.

## Setting up a new machine / new collaborator

When asked to get a collaborator's machine ready to work on this project, do
the following, in order. Ask the user before anything destructive (discarding
local changes, force push) or before guessing which branch to use if it's not
obvious.

1. **Clone the repo if it isn't already local:**
   ```
   git clone https://github.com/egongabaldo/deadweight.git
   ```

2. **Fetch everything and check out the active work branch:**
   ```
   git fetch --all
   git branch -a
   ```
   Work usually happens on a feature branch, not directly on `main` — check
   `git log --all --oneline --graph` or ask the user which branch is current
   (e.g. `claude/shredder-game-mvp-87fxa8`) before assuming. Then:
   ```
   git switch <branch-name>
   ```
   (`git switch` auto-creates a local tracking branch from `origin/<branch-name>`
   if one doesn't exist yet.)

3. **Set local git identity if commits fail with "Author identity unknown":**
   Ask the user for their name/email first — don't invent or guess values,
   and don't use `--global` unless they ask for it (scope it to this repo):
   ```
   git config user.name "..."
   git config user.email "..."
   ```

4. **Install Godot 4.3** (standard build, not .NET/Mono — check
   `project.godot`'s `config/features` line if unsure which version).

5. **Open and run the project:**
   - Launch Godot, "Import" this folder (select `project.godot`).
   - First open reimports assets — normal, just takes a few seconds.
   - Press F5 / the Play button to run `scenes/Main.tscn`.
   - The scenes are hand-authored as `.tscn` text rather than saved from the
     editor, so the editor may want to resave/reformat some resources on
     first touch — that's expected, not a bug.

## Build number

The HUD shows "Build N" in the top-right corner (`scripts/BuildInfo.gd`,
`BUILD_NUMBER` constant), so collaborators can eyeball whether they're
running the same version without diffing commits. **Bump `BUILD_NUMBER` by
1 every time you push a change that another collaborator might pull** —
do this as part of the same commit, right before pushing.

## Notes for Claude specifically

- This is a Windows machine; use the PowerShell tool for real Windows
  process/window automation (screenshots, window enumeration) — the Bash
  tool is Git Bash and mangles PowerShell-style `$_`/quoting.
- To visually verify a change without opening the editor, you can run the
  project headless: write a small `SceneTree`-extending `.gd` script that
  loads and instantiates `res://scenes/Main.tscn`, then run
  `Godot*_console.exe --headless -s your_script.gd`. Delete the script when
  done — it's a throwaway debugging aid, not part of the project.
- If a Godot editor or Play-mode window is already open (check with
  `Get-Process` in PowerShell, or window titles via `EnumWindows`), don't
  simulate mouse/keyboard input into it — that's the user's live session.
  Launch a separate instance for your own testing instead, and close only
  the one you started.
- `SaveManager` writes to `user://savegame.json`, which is shared by every
  Godot instance running this project on the same machine (editor Play
  sessions and any headless instance you launch alike) — don't be surprised
  if `Economy.money` already has a nonzero value on a fresh scene load.
