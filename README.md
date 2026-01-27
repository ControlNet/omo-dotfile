# omo-dotfile

My opencode configurations.

Linux/Mac:
```bash
curl -fsSL https://gist.githubusercontent.com/ControlNet/b10f23a707e3515e8fd215770e929b1a/raw/pull.sh | bash
```

Windows:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://gist.githubusercontent.com/ControlNet/b10f23a707e3515e8fd215770e929b1a/raw/pull.ps1' | iex"
```

Required environment variables:
- `ANTHROPIC_BASE_URL` (without `/v1`)
- `ANTHROPIC_AUTH_TOKEN`
- `GITHUB_PERSONAL_ACCESS_TOKEN` (used for github MCP)
