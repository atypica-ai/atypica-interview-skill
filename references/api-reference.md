# atypica Interview API Reference

Complete reference for all 10 MCP tools provided by the atypica.ai interview framework.

## Setup

The MCP server is available at `https://atypica.ai/mcp/interview`. Authentication uses a Bearer token in the Authorization header. API keys follow the format `atypica_xxx`, obtained from the atypica.ai account settings page.

---

## atypica_interview_create_project

Create a new interview project with structured questions.

Input:

```
{
  brief: string,              // Research brief. Max 5000 chars.
  questions: [{               // 1-50 items
    id?: string,              // Stable ID. Auto-generated (nanoid) if omitted.
    text: string,             // Question text. 1-1000 chars.
    questionType?: "open" | "single-choice" | "multiple-choice",  // Default: "open"
    options?: string[],       // Required for choice types. Min 2, max 50. Must NOT be present for "open".
    hint?: string,            // AI interviewer behavior instruction. Max 500 chars.
    images?: [{               // Max 4 per question
      objectUrl: string,      // S3 URL from atypica_get_upload_credentials
      name: string,           // Original file name
      mimeType: string,       // e.g. "image/png"
      size: number            // Bytes. Max 10MB (10485760).
    }]
  }]
}
```

Output:

```
{
  projectId: number,
  brief: string,
  questions: [{ id: string, text: string, questionType: string }],
  createdAt: string           // ISO 8601
}
```

Notes:

- Choice-type questions must have ≥2 options. Open questions must not include the options field.
- If id is provided, it is preserved. If omitted, server generates a stable nanoid.
- The project is immediately ready for share link generation after creation.

---

## atypica_interview_update_questions

Replace the full question list for an existing project.

Input:

```
{
  projectId: number,          // The project to update
  questions: [{               // Full replacement. 1-50 items.
    id?: string,              // If matches existing question, that ID is preserved. Otherwise new nanoid.
    text: string,             // 1-1000 chars
    questionType?: "open" | "single-choice" | "multiple-choice",  // Default: "open"
    options?: string[],       // Required for choice types. Min 2, max 50. Must NOT be present for "open".
    hint?: string,            // Max 500 chars
    images?: [{               // Max 4 per question
      objectUrl: string,      // S3 URL from atypica_get_upload_credentials
      name: string,
      mimeType: string,
      size: number            // Bytes. Max 10MB.
    }]
  }]
}
```

Output:

```
{
  projectId: number,
  questions: [{ id: string, text: string, questionType: string }]
}
```

Notes:

- This is a full replacement. Questions not in the new array are removed.
- Does NOT affect already-started sessions. They use a snapshot from session creation.
- Questions with a matching id retain that identifier.

---

## atypica_interview_list_projects

List the user's interview projects with pagination and optional search.

Input:

```
{
  page?: number,              // Min 1. Default: 1.
  pageSize?: number,          // Min 1, max 50. Default: 20.
  searchQuery?: string        // Free-text search on project briefs.
}
```

Output:

```
{
  projects: [{
    projectId: number,
    brief: string,
    questionCount: number,
    hasStats: boolean,         // Whether aggregated stats exist
    sessionStats: {
      humanSessions: number,
      personaSessions: number,
      total: number
    },
    createdAt: string,         // ISO 8601
    updatedAt: string
  }],
  pagination: { page: number, pageSize: number, totalCount: number, totalPages: number }
}
```

Notes:

- Results ordered by most recently created first.
- sessionStats gives a quick participation count without needing a separate get_progress call.
- Archived projects are excluded. There is no archived filter parameter.

---

## atypica_interview_generate_share_link

Generate a shareable URL. Interviewees open it to begin an AI-conducted interview.

Input:

```
{
  projectId: number,
  permanent?: boolean,        // Default: false (temporary link)
  expiryHours?: number        // 1-720. Default: 24. Ignored if permanent=true.
}
```

Output:

```
{
  shareUrl: string,           // Full URL: https://atypica.ai/interview/invite/{token}
  shareToken: string,         // Raw encrypted token
  permanent: boolean,
  expiryHours: number | null  // null if permanent
}
```

Notes:

- Multiple links can be generated for the same project. Each call produces a new token.
- Permanent links remain valid until the project is deleted.
- Temporary links expire after the specified hours from generation time.
- The URL format is a path parameter, not a query parameter.

---

## atypica_interview_get_progress

Query participation status, broken down by session type.

Input:

```
{
  projectId: number
}
```

Output:

```
{
  projectId: number,
  total: number,              // All sessions
  completed: number,
  inProgress: number,
  humanSessions: { total: number, completed: number, inProgress: number },
  personaSessions: { total: number, completed: number, inProgress: number }
}
```

Notes:

- A session is "completed" when its internal `ongoing` flag is not true (missing or false).
- humanSessions = real people via share link. personaSessions = AI persona simulations.
- Counts update in real time.

---

## atypica_interview_list_sessions

List sessions for a project with pagination and status filtering.

Input:

```
{
  projectId: number,
  page?: number,              // Min 1. Default: 1.
  pageSize?: number,          // Min 1, max 50. Default: 20.
  filter?: "all" | "completed" | "in_progress"  // Default: "all"
}
```

Output:

```
{
  projectId: number,
  sessions: [{
    sessionId: number,
    title: string | null,     // null if interviewee didn't provide identifying info
    status: "completed" | "in_progress",
    type: "human" | "persona",
    createdAt: string,        // ISO 8601
    hasStructuredAnswers: boolean  // Whether extracted Q&A is available
  }],
  pagination: { page: number, pageSize: number, totalCount: number, totalPages: number }
}
```

Notes:

- Ordered newest first.
- Check hasStructuredAnswers before calling get_session — saves unnecessary API calls.

---

## atypica_interview_get_session

Get full details of a single session including structured answers.

Input:

```
{
  sessionId: number
}
```

Output:

```
{
  sessionId: number,
  projectId: number,
  title: string | null,
  status: "completed" | "in_progress",
  type: "human" | "persona",
  interviewee: {              // null if anonymous
    type: "human" | "persona",
    id: number,
    name: string
  } | null,
  personalInfo: [{            // null if not collected
    label: string,
    text: string
  }] | null,
  structuredAnswers: {        // null if extraction hasn't run yet
    questions: [{
      questionId: string,     // Matches the question ID from project definition
      questionText: string,   // Question text at time of interview snapshot
      answers: [{
        kind: "main" | "followup",  // "main" = direct answer, "followup" = AI-probed elaboration
        label: string,
        value: string | number
      }]
    }]
  } | null,
  createdAt: string           // ISO 8601
}
```

Notes:

- personalInfo is populated from info the interviewee voluntarily shared during conversation.
- In-progress sessions may have partial or null structuredAnswers.
- The "main" answer kind represents the direct response. "followup" represents elaborations probed by the AI interviewer.

---

## atypica_interview_get_stats

Read aggregated question statistics. Reports three states: ready, generating, or not yet triggered.

Input:

```
{
  projectId: number
}
```

Output:

```
{
  projectId: number,
  questionStats: [{           // Empty array if stats not yet available
    questionId: string,
    questionText: string,
    answerStats: {
      totalCount: number,
      categories: [{
        label: string,
        count: number,
        ratio: number         // Decimal 0-1, proportion of responses
      }]
    },
    summary: string           // AI-generated natural language summary
  }],
  statsGeneratedAt: string | null,  // ISO 8601. null if never generated.
  isGenerating: boolean,
  progress: {                 // null when not generating
    done: number,
    total: number
  } | null,
  error: {                    // null if no error
    message: string | null,
    failedAt: number | null
  } | null
}
```

Notes:

- Three states: (1) isGenerating=true → poll again in ~15s. (2) questionStats non-empty + isGenerating=false → ready. (3) questionStats empty + isGenerating=false → call generate_stats first.
- If error is present, retry by calling generate_stats with forceRegenerate=true.

---

## atypica_interview_generate_stats

Trigger async generation of aggregated statistics. Takes 30-90s. Poll get_stats to retrieve results.

Input:

```
{
  projectId: number,
  forceRegenerate?: boolean   // Default: false. Regenerates even if cached.
}
```

Output:

```
{
  projectId: number,
  status: "started" | "already_running"
}
```

Notes:

- Requires at least one completed session with extracted structured answers.
- "already_running" means generation is in flight — just poll get_stats.
- Stats are cached. Without forceRegenerate, returns cached if no new sessions.
- Consumes LLM tokens from user quota.
- Concurrent generation per project is blocked (one job at a time).

---

## atypica_get_upload_credentials

Get a presigned URL to upload a file. After uploading via HTTP PUT, use the objectUrl in question images.

Input:

```
{
  fileName: string,           // With extension, e.g. "design.png"
  mimeType: string            // e.g. "image/png", "application/pdf"
}
```

Output:

```
{
  putUrl: string,             // Presigned PUT URL. Expires in 5 minutes.
  objectUrl: string,          // Permanent S3 URL to reference after upload.
  fileName: string,
  mimeType: string
}
```

Notes:

- Supported images: jpeg, png, gif, webp, bmp, svg.
- Supported documents: pdf, json, csv.
- Upload: HTTP PUT to putUrl with Content-Type header matching mimeType, file as body.
- putUrl is single-use and expires after 5 minutes.

---

## Error Handling

All errors follow JSON-RPC 2.0 format: `{ error: { code: number, message: string } }`

- **-32001 Unauthorized**: Invalid, expired, or missing API key. Verify format (`atypica_xxx`) and Bearer scheme.
- **-32602 Invalid params**: Field type mismatch or constraint violation (text too long, options count wrong, required field missing).
- **-32603 Internal error**: Server-side failure. Safe to retry after brief delay.
- **Project not found**: projectId doesn't exist or doesn't belong to authenticated user. All operations enforce ownership.
- **Question validation**: Choice without ≥2 options, open with options array, text >1000 chars, hint >500 chars, >50 questions.
- **Stats no data**: generate_stats called with no completed sessions or no extracted answers.
- **Retry guidance**: All read operations are idempotent. For generate_stats timeout, poll get_stats to check if it started.

---

## Security and Limitations

- API keys are user-scoped only. Team keys not supported.
- All operations verify ownership (user can only access own projects/sessions).
- Upload URLs expire after 5 minutes, single-use.
- Max 50 questions/project, 4 images/question at 10MB each, 50 options/question.
- Brief max 5000 chars, question text max 1000, hint max 500.
- Page size max 50 for list operations.
- Stats generation consumes LLM tokens. One concurrent job per project.
- Not available via MCP: bulk delete, custom persona config, real-time push notifications.
- Data isolation: per-user, per-interviewee. Question updates don't propagate to in-progress sessions (snapshot isolation). Raw transcripts never leave platform through stats API.
