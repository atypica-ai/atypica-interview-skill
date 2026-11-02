# atypica Interview API Reference

Every tool of the MCP server at `https://atypica.ai/mcp/interview`, with its input and output. The same tools are on the unified server `https://atypica.ai/mcp`, together with user research and desk research.

## Conventions

**Transport and sign-in.** Streamable HTTP, JSON-RPC 2.0, at `https://atypica.ai/mcp/interview`. Send `Authorization: Bearer atypica_…`, an API key from https://atypica.ai/account/api-keys. It acts as the account the user signed in as (a personal account or a team member) and spends that account's credits. A missing or invalid key is HTTP 401.

**Results.** Every tool returns `content` (one text block, for clients that read only text) and, on success, `structuredContent` (the JSON below). Both are made from the tool's declared `outputSchema`, which `tools/list` returns; no field outside it is sent. A failure is a normal result with `isError: true` and one sentence in the text, not a JSON-RPC error:

- one the client can act on (not found, still running, a wrong answer shape) says what to do;
- an unexpected one says only that something went wrong on atypica's side; the cause stays in the server log.

Input that does not match the schema is the same kind of failure: `isError: true`, and the text starts with `MCP error -32602: Input validation error` and names the field.

**Ownership.** A token or id that belongs to another account gives the same "not found" as one that does not exist.

**Links.** Public pages (study replay, report and podcast share, interview invite) are absolute URLs on the site the request came to: `https://atypica.ai` in production. They open without sign-in.

**Notation.** Shapes are TypeScript-like. `?` marks an optional field; dates are ISO 8601 strings.

**Annotations.** Read tools: `readOnlyHint: true`. Write tools: `readOnlyHint: false, destructiveHint: false`, except `atypica_interview_update_questions` (`destructiveHint: true`, it replaces all questions).

## The flow

Real people are interviewed by an AI interviewer through a link the user distributes. A project holds the questions; each person's interview is a session.

```
create_project ──► generate_share_link ──► (people answer over hours or days)
   ──► get_progress ──► generate_stats ──► get_stats (poll)
                    └─► list_sessions ──► get_session
```

## Tools

### atypica_interview_create_project

Input:

```ts
{
  brief: string                  // at most 5000 characters
  questions: Question[]          // 1–50
}

type Question = {
  id?: string                    // kept if given; generated otherwise
  text: string                   // 1–1000 characters
  questionType?: "open" | "single-choice" | "multiple-choice"  // default "open"
  options?: string[]             // 2–50, required for choice types, absent for open
  hint?: string                  // what the interviewer should probe for; at most 500 characters
  images?: {                     // at most 4
    objectUrl: string            // from atypica_get_upload_credentials
    name: string                 // at most 255 characters
    mimeType: string
    size: number                 // bytes, at most 10 MB
  }[]
}
```

Output:

```ts
{
  projectId: number
  brief: string
  questions: { id: string, text: string, questionType: "open" | "single-choice" | "multiple-choice" }[]
  createdAt: string
}
```

### atypica_interview_update_questions

Replaces all of a project's questions. Sessions already started keep the questions they started with.

Input:

```ts
{
  projectId: number
  questions: Question[]          // 1–50; a question whose id matches an existing one keeps that id
}
```

Output:

```ts
{
  projectId: number
  questions: { id: string, text: string, questionType: string }[]
}
```

### atypica_interview_list_projects

The caller's projects that are not archived, newest first.

Input:

```ts
{
  page?: integer                 // default 1
  pageSize?: integer             // default 20, at most 50
  searchQuery?: string           // matches the brief
}
```

Output:

```ts
{
  projects: {
    projectId: number
    brief: string
    questionCount: number
    hasStats: boolean
    sessionStats: { humanSessions: number, personaSessions: number, total: number }
    createdAt: string
    updatedAt: string
  }[]
  pagination: { page, pageSize, totalCount, totalPages }
}
```

### atypica_interview_generate_share_link

A link that opens an interview for whoever has it. Each call makes a new link.

Input:

```ts
{
  projectId: number
  permanent?: boolean            // default false
  expiryHours?: number           // 1–720, default 24; ignored when permanent
}
```

Output:

```ts
{
  shareUrl: string; // https://atypica.ai/interview/invite/<shareToken>
  shareToken: string;
  permanent: boolean;
  expiryHours: number | null; // null when permanent
}
```

### atypica_interview_get_progress

Input:

```ts
{
  projectId: number;
}
```

Output:

```ts
{
  projectId: number
  total: number
  completed: number
  inProgress: number
  humanSessions: { total: number, completed: number, inProgress: number }    // real people
  personaSessions: { total: number, completed: number, inProgress: number }  // AI-simulated participants
}
```

### atypica_interview_list_sessions

Input:

```ts
{
  projectId: number
  page?: integer                 // default 1
  pageSize?: integer             // default 20, at most 50
  filter?: "all" | "completed" | "in_progress"  // default "all"
}
```

Output:

```ts
{
  projectId: number;
  sessions: {
    sessionId: number;
    title: string | null; // null for a person: the title starts with their name
    status: "completed" | "in_progress";
    type: "human" | "persona";
    createdAt: string;
    hasStructuredAnswers: boolean;
  }
  [];
  pagination: {
    (page, pageSize, totalCount, totalPages);
  }
}
```

### atypica_interview_get_session

One interview. A person who answered is not identified: no account id, name, title or the personal info they filled in. The account owner sees those on the web page.

Input:

```ts
{
  sessionId: number;
}
```

Output:

```ts
{
  sessionId: number
  projectId: number
  title: string | null           // null for a person: the title starts with their name
  status: "completed" | "in_progress"
  type: "human" | "persona"
  interviewee: { type: "human" } | { type: "persona", id: number, name: string } | null  // a person is not identified
  summary: string | null         // once the interview has one
  structuredAnswers: {           // null until the answers are extracted
    questions: {
      questionId: string
      questionText: string
      answers: { kind: "main" | "followup", label: string, value: string | number }[]
    }[]
  } | null
  transcript: string | null      // the conversation as text, without the opening form that asks who they are
  createdAt: string
}
```

### atypica_interview_generate_stats

Starts aggregating the answers per question. It runs in the background for 30–90 seconds and uses the account's credits; read the result with `atypica_interview_get_stats`.

Input:

```ts
{
  projectId: number
  forceRegenerate?: boolean      // default false
}
```

Output:

```ts
{ projectId: number, status: "started" | "already_running" }
```

### atypica_interview_get_stats

Input:

```ts
{
  projectId: number;
}
```

Output:

```ts
{
  projectId: number
  questionStats: {
    questionId: string
    questionText: string
    answerStats: {
      totalCount: number
      categories: { label: string, count: number, ratio: number }[]  // ratio 0–1
    }
    summary: string
  }[]
  statsGeneratedAt: string | null
  isGenerating: boolean
  progress: { done: number, total: number } | null   // while generating
  lastFailedAt: number | null    // when the last generation failed (ms since epoch); why stays in the server log
}
```

Three states: `isGenerating: true` (poll again in about 15 seconds); `questionStats` not empty (ready); both empty (never generated: call `atypica_interview_generate_stats`).

### atypica_get_upload_credentials

A URL to upload one file to. PUT the file to `putUrl` with the same `Content-Type` within 5 minutes, then pass `objectUrl` in a question's `images`.

Input:

```ts
{
  fileName: string; // with extension
  mimeType: string; // images: jpeg, png, gif, webp, bmp, svg+xml; documents: pdf, doc, docx, xls, xlsx, ppt, pptx, txt, md, json, csv
}
```

Output:

```ts
{
  putUrl: string; // presigned PUT, valid 5 minutes
  objectUrl: string; // the file's address, without signature
  fileName: string;
  mimeType: string;
}
```

Another type gives `isError: true`.
