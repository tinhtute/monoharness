# Explorer Brief

One brief per angle, sent to a `scout` (model `haiku`, read-only). Fill the braces.

```
GOAL     Trace {ANGLE} to help answer: {QUESTION}. Other scouts cover other slices of the same subsystem; go deep on yours only.
SCOPE    read-only; start from {paths or symbols, if known}
TIMEBOX  {budget}; on expiry return what you have
REPORT   the sections below; every item cites file:line; mark anything you inferred rather than read
```

Report sections:

- **Components** — each type, service or function in the slice: name, `file:line`, one sentence on what it does.
- **Flow** — step by step: the function that runs, its file, what it does, what it calls next, and the data passed along.
- **Boundaries** — where the slice meets the rest of the codebase: its inputs and outputs.
- **Non-obvious** — anything surprising, historically motivated or easy to get wrong.
- **Files read** — every file opened.
- **Open questions** — what you could not trace.
