---
name: atypica-interview
description: Access atypica.ai's AI-conducted human interview capabilities through MCP protocol. Use when users need to create interview projects with structured questions, distribute interview links to real people, monitor participation progress, retrieve per-session structured answers, and generate aggregated question statistics. Supports question types (open/single-choice/multiple-choice), image attachments, permanent/temporary share links, and cross-session statistical analysis.
---

# atypica Interview

Access atypica.ai's interview framework for conducting AI-guided human interviews at scale — structured questionnaires, real-time progress monitoring, and aggregated statistical analysis.

## Calling Methods

Three ways to call the Interview API, depending on your environment:

### Method 1: MCP Client (Recommended for AI assistants)

If tools starting with `atypica_interview_` are already available, the MCP server is configured. Otherwise, configure it:

- **Endpoint**: `https://atypica.ai/mcp/interview`
- **API Key**: From https://atypica.ai/account/api-keys (format: `atypica_xxx`)
- **Authentication**: HTTP header `Authorization: Bearer <api_key>`

**Claude Desktop** config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

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

### Method 2: curl + jq (Best for scripting without MCP client)

When you don't have an MCP client, curl + jq is the most flexible combination. All MCP tools are plain JSON-RPC over HTTP:

```bash
export ATYPICA_TOKEN="atypica_xxx"
export ATYPICA_ENDPOINT="https://atypica.ai/mcp/interview"

# Generic pattern: call any tool
call_tool() {
  local tool_name="$1"
  local args="$2"
  curl -s -X POST "$ATYPICA_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ATYPICA_TOKEN" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"$tool_name\",\"arguments\":$args},\"id\":1}"
}

# Create project
call_tool atypica_interview_create_project '{"brief":"Coffee research","questions":[{"text":"What brand?"}]}' | jq '.result'

# Get progress (extract structured data)
call_tool atypica_interview_get_progress '{"projectId":123}' | jq '.result.structuredContent'

# List completed sessions with pagination
call_tool atypica_interview_list_sessions '{"projectId":123,"filter":"completed","pageSize":10}' \
  | jq '.result.structuredContent.sessions[] | {id: .sessionId, title, status}'

# Poll stats until ready
while true; do
  stats=$(call_tool atypica_interview_get_stats '{"projectId":123}')
  is_generating=$(echo "$stats" | jq -r '.result.structuredContent.isGenerating')
  if [ "$is_generating" = "false" ]; then
    echo "$stats" | jq '.result.structuredContent.questionStats'
    break
  fi
  echo "Generating..." && sleep 15
done
```

**Tips**:

- Use `jq '.result.structuredContent'` to extract the structured response
- Use `jq '.result.content[0].text'` to get the human-readable summary
- Pipe into `jq -r` for raw strings (no quotes)
- Chain with `| jq '.fieldName'` for specific fields

### Method 3: mcp-call.sh (Bundled convenience script)

A standalone script that wraps curl+jq with nicer output, error handling, and options:

```bash
export ATYPICA_TOKEN="atypica_xxx"

# Create project
scripts/mcp-call.sh atypica_interview_create_project '{"brief":"Research coffee","questions":[{"text":"What brand?"}]}'

# Get progress (auto-detects output format)
scripts/mcp-call.sh atypica_interview_get_progress '{"projectId":123}'

# Output as raw JSON
scripts/mcp-call.sh atypica_interview_list_sessions '{"projectId":123}' -o json

# Write to file
scripts/mcp-call.sh atypica_interview_get_stats '{"projectId":123}' -f results.json

# Verbose mode (shows request/response details)
scripts/mcp-call.sh atypica_interview_get_progress '{"projectId":123}' -v
```

Options: `-t <token>`, `-o text|json|structured|auto`, `-f <file>`, `-v`, `-h`

See [scripts/mcp-call.sh](scripts/mcp-call.sh) for full documentation.

## Core Workflow

1. **Create** interview project with brief + structured questions
2. **Distribute** share link to interviewees (humans complete interviews asynchronously)
3. **Monitor** progress — poll `get_progress` every 5-10 minutes
4. **Generate** stats when enough sessions complete — `generate_stats` (async, 30-90s)
5. **Retrieve** aggregated stats via `get_stats`, or drill into individual sessions via `list_sessions` + `get_session`

```
create_project → generate_share_link → [wait for humans] → get_progress
                                                               ↓
                                          enough completions? → generate_stats → get_stats
                                                               ↓
                                          individual analysis? → list_sessions → get_session
```

## Available Tools

| Tool                                    | Description                                                              |
| --------------------------------------- | ------------------------------------------------------------------------ |
| `atypica_interview_create_project`      | Create interview project with brief + questions                          |
| `atypica_interview_update_questions`    | Replace question list (doesn't affect started sessions)                  |
| `atypica_interview_list_projects`       | List/search user's projects with pagination                              |
| `atypica_interview_generate_share_link` | Generate permanent or temporary share URL                                |
| `atypica_interview_get_progress`        | Get participation breakdown (human vs persona, completed vs in-progress) |
| `atypica_interview_list_sessions`       | List sessions with filter and pagination                                 |
| `atypica_interview_get_session`         | Get full session detail with structured answers                          |
| `atypica_interview_get_stats`           | Read aggregated statistics (three states: ready/generating/empty)        |
| `atypica_interview_generate_stats`      | Trigger async stats generation                                           |
| `atypica_get_upload_credentials`        | Get presigned URL for file upload (images for questions)                 |

For complete input/output schemas, see [references/api-reference.md](references/api-reference.md).

## Understanding Interview State

Unlike research (which has a real-time agent loop), interviews are **fully asynchronous** — real humans participate on their own schedule.

### Progress monitoring

```bash
# Check if anyone has participated
call_tool atypica_interview_get_progress '{"projectId":123}' | jq '.result.structuredContent'
# → { "total": 12, "completed": 8, "inProgress": 4, "humanSessions": {...}, "personaSessions": {...} }
```

- `completed` = sessions where `extra.ongoing` is NOT true
- `inProgress` = sessions still being conducted
- `humanSessions` vs `personaSessions` = real people vs AI persona simulations

### Stats lifecycle

Stats are NOT auto-generated. You explicitly trigger them:

```bash
# 1. Trigger (fire-and-forget, async 30-90s)
call_tool atypica_interview_generate_stats '{"projectId":123}'

# 2. Poll until ready
call_tool atypica_interview_get_stats '{"projectId":123}' | jq '.result.structuredContent | {isGenerating, count: (.questionStats | length)}'
# → { "isGenerating": true, "count": 0 }   ← still working
# → { "isGenerating": false, "count": 5 }  ← done!
```

Three states:

- `questionStats.length > 0` → ready
- `isGenerating: true` → poll again in 15s
- `questionStats.length == 0 && !isGenerating` → never generated, call `generate_stats`

### Individual session drill-down

```bash
# List completed sessions
call_tool atypica_interview_list_sessions '{"projectId":123,"filter":"completed"}' \
  | jq '.result.structuredContent.sessions[] | {id: .sessionId, title, hasStructuredAnswers}'

# Get detail for one session
call_tool atypica_interview_get_session '{"sessionId":456}' \
  | jq '.result.structuredContent | {title, answers: .structuredAnswers.questions}'
```

## Question Validation Rules

| Type              | Options               | Constraint                        |
| ----------------- | --------------------- | --------------------------------- |
| `open`            | Must NOT have options | Text answer, AI probes for detail |
| `single-choice`   | Must have ≥2 options  | One selection only                |
| `multiple-choice` | Must have ≥2 options  | Multiple selections allowed       |

- `text`: 1-1000 chars, required
- `hint`: max 500 chars, optional — instructs AI behavior
- `options`: max 50 items per question
- `images`: max 4 per question, each ≤10MB (upload via `atypica_get_upload_credentials` first)

## Best Practices

1. **Async mindset**: Human interviews take hours/days. Create → distribute → come back later.
2. **Poll conservatively**: Every 5-10 minutes for `get_progress`. Human-speed, not machine-speed.
3. **Stats are explicit**: Call `generate_stats` when YOU decide there's enough data.
4. **Two levels of results**: `get_stats` for "what does the crowd say?" vs `get_session` for "what did this person say?"
5. **Question updates don't propagate**: Already-started interviews use their snapshot.
6. **Use permanent links** for ongoing research; temporary links for time-bounded campaigns.
7. **Check `hasStructuredAnswers`** before calling `get_session` — saves unnecessary calls.
8. **Parallelize independent reads**: `get_progress` and `list_sessions` for the same project can run concurrently. Same for fetching multiple session details.
9. **Use `hasStats` from `list_projects`**: Skip `get_stats` calls for projects that haven't generated stats yet.

## Performance Expectations

- Project creation: < 2s
- Share link generation: < 1s
- Progress/list queries: < 2s
- Stats generation: 30-90s (depends on question count × session count)
- Session detail retrieval: < 2s

## Reference Documentation

**IMPORTANT**: Read [references/api-reference.md](references/api-reference.md) in full before making any API calls. Do not read it partially or look up individual tools on demand — the notes and constraints for each tool inform how other tools behave. Reading the complete reference upfront prevents subtle mistakes that come from missing cross-tool dependencies.
