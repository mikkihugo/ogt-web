# Claude Code Permissions Configuration

## To Bypass All Permissions

Use one of these CLI commands:

```bash
# Option 1: Dangerously skip all permissions
claude --dangerously-skip-permissions

# Option 2: Set permission mode to bypassPermissions
claude --permission-mode bypassPermissions

# Option 3: Set permission mode to dontAsk
claude --permission-mode dontAsk
```

## Valid Permission Modes

- `default` - Normal permission checks
- `bypassPermissions` - Bypass all permission checks
- `dontAsk` - Allow without asking
- `acceptEdits` - Auto-accept all edits
- `plan` - Plan mode

## Current Settings File

`.claude/settings.local.json`:
```json
{
  "permissions": {
    "allow": ["*"],
    "deny": [],
    "ask": []
  }
}
```

## To Restore Permissions

Edit `.claude/settings.local.json` and set specific permissions:

```json
{
  "permissions": {
    "allow": [
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(helm upgrade:*)",
      "Bash(kubectl get:*)"
    ],
    "deny": [],
    "ask": []
  }
}
```

## Note

The CLI flag `--permission-mode bypassPermissions` cannot be set in `settings.local.json` - it must be passed as a command-line argument.
