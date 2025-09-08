# Claude Code Router (Containerized)

## Setup

1. Place the script inside of a repo.
2. Run:
   ```bash
   chmod u+x ./RUN_CLAUDE.sh
   ```
3. Then run:
   ```bash
   ./RUN_CLAUDE.sh
   ```

## Notes

- I like to hard code my OpenRouter variable and then, obviously, don't check this bash script into Git.
- I mainly use this for git worktree branches. Easy ones so that I can use cheap and fast models to work on them in the background.
- They are all (easy ones atleas) using this containerized ccr so that I don't mess with my real Claude instance on my laptop.
