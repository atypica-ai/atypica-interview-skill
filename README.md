# atypica Interview Skill

AI-conducted human interviews at scale through MCP protocol. Create structured questionnaires, distribute shareable links, monitor participation, and retrieve structured answers with aggregated statistics.

## Features

- Create interview projects with structured questions (open/single-choice/multiple-choice)
- Generate shareable links (permanent or temporary) for distribution
- Monitor real-time participation progress
- Retrieve per-session structured answers
- Generate aggregated question statistics with category distributions
- Support image attachments in questions

## Prerequisites

### Required

- **atypica.ai account** - Sign up at https://atypica.ai
- **API Key** - Get from https://atypica.ai/account/api-keys (format: `atypica_xxx`)
- **MCP-compatible AI assistant** OR **bash/curl** for direct API access

### Usage & Billing

- Interview operations consume atypica.ai token credits
- Token usage tracked per user account
- Check usage at https://atypica.ai/account/tokens

## Installation

### Option 1: MCP Integration

Requires MCP-compatible AI assistant (e.g., Claude Desktop, Cline).

**Configuration**:

```json
{
  "mcpServers": {
    "atypica-interview": {
      "transport": "http",
      "url": "https://atypica.ai/mcp/interview",
      "headers": {
        "Authorization": "Bearer atypica_xxx"
      }
    }
  }
}
```

See [SKILL.md](SKILL.md) for detailed setup instructions.

### Option 2: Bash Script (No MCP required)

```bash
export ATYPICA_TOKEN="atypica_xxx"
export ATYPICA_ENDPOINT="https://atypica.ai/mcp/interview"
scripts/mcp-call.sh atypica_interview_create_project '{"brief":"Research coffee preferences","questions":[{"text":"What brand do you drink?"}]}'
```

## Documentation

- **[SKILL.md](SKILL.md)** - Detailed usage guide for AI assistants
- **[API Reference](references/api-reference.md)** - Complete API documentation
- **[scripts/mcp-call.sh](scripts/mcp-call.sh)** - Bash fallback tool

## Available Tools

**Project**: `atypica_interview_create_project`, `atypica_interview_update_questions`, `atypica_interview_list_projects`

**Distribution**: `atypica_interview_generate_share_link`

**Monitoring**: `atypica_interview_get_progress`

**Sessions**: `atypica_interview_list_sessions`, `atypica_interview_get_session`

**Statistics**: `atypica_interview_get_stats`, `atypica_interview_generate_stats`

**File Upload**: `atypica_get_upload_credentials`

## Quick Links

- Website: https://atypica.ai
- Documentation: https://atypica.ai/docs/mcp

---

**Auto-synced from [atypica-llm-app](https://github.com/bmrlab/atypica-llm-app)**
