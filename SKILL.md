---
name: atypica-interview
description: Interview real people with atypica.ai's AI interviewer through its MCP server. Use when the user wants answers from real people, as an interview or a questionnaire sent by link. Covers writing the questions, getting the link to send, checking how many have answered, reading one person's answers and transcript, and aggregated statistics per question.
---

# atypica Interview

An interview project: the user writes questions, sends a link, and real people are interviewed by an AI interviewer on their own time. Each person's interview is a session.

Read [references/api-reference.md](references/api-reference.md) for every tool's input and output.

## Connection

- **Endpoint**: `https://atypica.ai/mcp/interview`
- **API key**: from https://atypica.ai/account/api-keys, sent as `Authorization: Bearer atypica_xxx`

If tools named `atypica_interview_*` are available, it is connected. Otherwise add it to the client, for example Claude Desktop:

```json
{
  "mcpServers": {
    "atypica-interview": {
      "transport": "http",
      "url": "https://atypica.ai/mcp/interview",
      "headers": { "Authorization": "Bearer atypica_xxx" }
    }
  }
}
```

Without an MCP client, every tool is one JSON-RPC call over HTTP. `scripts/mcp-call.sh` wraps it:

```bash
export ATYPICA_TOKEN="atypica_xxx"
scripts/mcp-call.sh atypica_interview_create_project '{"brief":"Coffee habits","questions":[{"text":"Which brand do you drink, and why?"}]}'
scripts/mcp-call.sh atypica_interview_get_progress '{"projectId":123}' -o structured
```

## The flow

```
atypica_interview_create_project({ brief, questions })  → projectId
atypica_interview_generate_share_link({ projectId })    → shareUrl: give it to the user to distribute
later: atypica_interview_get_progress({ projectId })    → how many have answered
enough answers: atypica_interview_generate_stats({ projectId }), then atypica_interview_get_stats every 15 s
one person: atypica_interview_list_sessions → atypica_interview_get_session({ sessionId })
```

- When delivering the share link, tell the user that human participants answer on their own time and that you can check participation progress later. People answer over hours or days. After sending the link there is nothing to poll; check progress when the user asks.
- Statistics are not automatic. `generate_stats` uses the account's credits and takes 30–90 s. `get_stats` has three states: `isGenerating: true` (poll again), `questionStats` filled (ready), both empty (never generated: call `generate_stats`).
- `atypica_interview_update_questions` replaces all questions and does not change interviews already started.
- A link is temporary (24 hours by default) unless `permanent: true`; each call makes a new link.

## Writing questions

| `questionType`    | `options` | Notes                                             |
| ----------------- | --------- | ------------------------------------------------- |
| `open` (default)  | none      | Text answer; the AI interviewer probes for detail |
| `single-choice`   | 2–50      | One pick                                          |
| `multiple-choice` | 2–50      | Several picks                                     |

Up to 50 questions, 1000 characters each. `hint` (500 characters) tells the interviewer what to probe for. Images on a question: `atypica_get_upload_credentials({ fileName, mimeType })`, HTTP PUT the file to `putUrl` with the same `Content-Type` within 5 minutes, then put `{ objectUrl, name, mimeType, size }` in the question's `images`, up to 4, 10 MB each.

## Delivering

- Progress: `completed` vs `inProgress`, split into `humanSessions` (real people) and `personaSessions` (AI-simulated participants, if the user ran any).
- Aggregated: `get_stats` gives, per question, categories with counts and ratios plus a summary.
- Individual: `list_sessions` (check `hasStructuredAnswers`), then `get_session` for answers, a summary and the transcript. These are real people's words: share them only with the user who owns the project.
