# hackboard

CLI for [Hackboard](https://github.com/igarbayo/hackathon-management): it connects Claude Code to your hackathon team's board. It installs a few hooks that send the activity of your sessions to Hackboard (metadata or summaries, depending on the privacy level you choose) and, if you want, adds the Hackboard MCP server to Claude Code.

## Install

```sh
npm i -g hackboard
hackboard init --team XXXX-XXXX
```

The team code is in **Team and settings → Claude Code** in the Hackboard web app. You need Node 20 or later.

Install it globally: each hook runs the binary, and `npx` would add latency to every call.

## Commands

| Command | What it does |
|---------|--------------|
| `hackboard init [--team CODE] [--scope local\|user] [--mcp\|--no-mcp]` | Connects to your account from the browser, installs the hooks and tests the connection. `--scope local` (the default) writes to `<repo>/.claude/settings.local.json`; `user`, to `~/.claude/settings.json`. |
| `hackboard status` | Team, privacy level, whether it is paused and queued events. |
| `hackboard pause` / `resume` | Stops or resumes sending activity. |
| `hackboard privacy <metadata\|summaries\|off>` | Changes the privacy level. |
| `hackboard test` | Sends a test event. |
| `hackboard uninstall [--purge]` | Removes the hooks, deletes the credential and revokes the token. `--purge` also deletes your events from the server. |

## What is sent and what is not

Diffs, file contents, commands you run, Claude's replies and the text of your prompts are never sent. With `metadata` (the default) only the event type, times, branch, HEAD sha, relative paths of edited files, number of tools used and prompt length are sent; with `summaries`, also a summary of the turn. With `off` nothing is sent. The hooks never block Claude Code: if something fails, they exit without an error and retry later.

## Configuration

- `HACKBOARD_API_URL`: the API URL if you run your own Hackboard deployment.
