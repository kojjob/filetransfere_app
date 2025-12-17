# ZipShare MCP Server

Enable AI agents (Claude, ChatGPT, etc.) to transfer files using ZipShare.

## What is this?

This is a [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) server that allows AI assistants to send and receive files on your behalf. Instead of manually uploading files and sharing links, you can simply tell your AI:

> "Send this report to Sarah"

And the AI will handle the upload and share the link.

## Quick Start

### 1. Get your API Key

Sign up at [zipshare.io](https://zipshare.io) and generate an API key from your dashboard.

### 2. Configure your AI Client

#### For Claude Desktop

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "zipshare": {
      "command": "npx",
      "args": ["@zipshare/mcp-server"],
      "env": {
        "ZIPSHARE_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

#### For Cursor

Add to your MCP settings:

```json
{
  "zipshare": {
    "command": "npx",
    "args": ["@zipshare/mcp-server"],
    "env": {
      "ZIPSHARE_API_KEY": "your-api-key-here"
    }
  }
}
```

### 3. Use it!

Now you can ask your AI to send files:

- "Upload `/Users/me/report.pdf` and give me a share link"
- "Send the file at `/path/to/presentation.pptx` to team@company.com"
- "Share these files with password protection: `/docs/contract.pdf`, `/docs/appendix.pdf`"
- "Check the status of my last transfer"
- "Delete transfer abc123"

## Available Commands

| Command | Description |
|---------|-------------|
| `send_file` | Upload a single file and get a share link |
| `send_files` | Upload multiple files as a batch |
| `get_transfer_status` | Check upload progress or download count |
| `list_transfers` | See your recent transfers |
| `delete_transfer` | Remove a transfer and revoke its link |
| `get_download_link` | Get direct download URL for a share |

## Examples

### Send a file with password protection

```
User: Upload /Users/me/secret.pdf with password "abc123" and expire in 24 hours

AI: ✅ File uploaded successfully!

File: secret.pdf
Size: 2.4 MB
Share Link: https://zipshare.io/s/xyz789
Password Protected: Yes
Expires: 2024-12-18 14:30 UTC
```

### Send multiple files

```
User: Send these files to client@example.com: /projects/mockup.fig, /projects/assets.zip

AI: ✅ 2 files uploaded successfully!

Total Size: 45.2 MB
Share Link: https://zipshare.io/s/batch123
Notification sent to: client@example.com

Files included:
- mockup.fig (12.1 MB)
- assets.zip (33.1 MB)
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ZIPSHARE_API_KEY` | Yes | Your ZipShare API key |
| `ZIPSHARE_API_URL` | No | Custom API URL (default: https://api.zipshare.io) |

## Why ZipShare + AI?

1. **No context switching** - Send files without leaving your AI conversation
2. **Natural language** - Just describe what you want, no forms to fill
3. **Automation ready** - Build workflows that move files automatically
4. **Secure by default** - Password protection, expiration, download limits

## Self-Hosting

If you're running your own ZipShare instance, set the API URL:

```json
{
  "env": {
    "ZIPSHARE_API_KEY": "your-key",
    "ZIPSHARE_API_URL": "https://your-instance.com"
  }
}
```

## Support

- Documentation: [docs.zipshare.io](https://docs.zipshare.io)
- Issues: [github.com/kojjob/zipshare-mcp/issues](https://github.com/kojjob/zipshare-mcp/issues)
- Email: support@zipshare.io

## License

MIT
