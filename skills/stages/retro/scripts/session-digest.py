#!/usr/bin/env python3
"""Condense a Claude Code session log into the signals a retro needs.

Usage: session-digest.py [--json | --signals [--since TIME]] [SESSION_JSONL | SESSION_ID]
With no argument, reads the newest session for the current directory under
~/.claude/projects/<cwd-slug>/. Also reads `claude -p --output-format
stream-json` traces. Prints plain text, or one JSON object with --json;
reads nothing else.

--signals prints only the lines a model should look at, one per signal, and
nothing for a clean session; it exits 0 either way:
  signal: error tool=<name> result=<first 160 chars>
  signal: repeat tool=<name> count=<n> input=<first 200 chars>  (identical input, n >= 3)
  signal: merge pr=<number or ?> command=<the gh pr merge command>
A Bash result `Exit code 1` is no error signal when every command in it is
read-only (READ_ONLY: no match, files differ, test false). A merge signal can
be a mention (echo, grep, heredoc); it over-reports rather than misses.

--since TIME (ISO 8601 with a zone, e.g. 2026-11-13T05:00:00Z) counts only
records stamped at or after TIME toward every signal. A record without a
`timestamp` (stream-json traces) still counts, so a filter never hides one.
Usage errors exit 2.
"""
import collections
import datetime
import glob
import json
import os
import re
import shlex
import sys

PROJECTS = os.path.expanduser("~/.claude/projects")
REPEAT_SIGNAL = 3  # one identical retry is routine; a third run is a loop worth a look
MERGE = re.compile(r"(?:^|[\s;&|(])gh\s+pr\s+merge\b(.*)", re.S)
SEPARATORS = (";", "&&", "||", "|", "&", "(", ")", "\n")
# Exit 1 from these means "no match", "files differ" or "false", not a failure.
READ_ONLY = {"grep", "egrep", "fgrep", "rg", "test", "[", "[[", "diff", "cmp", "ls", "find",
             "echo", "printf", "head", "tail", "wc", "sort", "uniq", "cut"}
READ_ONLY_GIT = {"diff", "grep"}


def bad_usage(msg):
    print(f"session-digest: {msg}", file=sys.stderr)
    print(__doc__.split("\n\n")[1], file=sys.stderr)
    sys.exit(2)


def parse_time(value):
    try:
        t = datetime.datetime.fromisoformat(value)
    except ValueError:
        return None
    return t if t.tzinfo else None


def resolve(arg):
    if arg and os.path.isfile(arg):
        return arg
    slug = re.sub(r"[^A-Za-z0-9]", "-", os.getcwd())
    if arg:
        hits = glob.glob(os.path.join(PROJECTS, "*", arg + ".jsonl"))
        if hits:
            return hits[0]
        sys.exit(f"session not found: {arg}")
    logs = glob.glob(os.path.join(PROJECTS, slug, "*.jsonl"))
    if not logs:
        sys.exit(f"no sessions under {os.path.join(PROJECTS, slug)}; pass a path")
    return max(logs, key=os.path.getmtime)


def text_of(content):
    if isinstance(content, str):
        return content
    parts = []
    for block in content or []:
        if block.get("type") == "text":
            parts.append(block.get("text", ""))
        elif block.get("type") == "tool_result":
            parts.append(text_of(block.get("content")))
    return "\n".join(parts)


def short(s, n=160):
    s = " ".join(str(s).split())
    return s if len(s) <= n else s[: n - 1] + "…"


def pr_number(rest):
    """The PR a `gh pr merge` targets: a number, #N or a /pull/N URL; `?` means the current branch's PR."""
    for token in re.findall(r"\n|[;&|()]+|[^\s;&|()]+", rest):
        if token in SEPARATORS or token[0] in ";&|()":
            break
        m = re.fullmatch(r"#?(\d+)|\S*/pull/(\d+)\S*", token)
        if m:
            return m.group(1) or m.group(2)
    return "?"


def read_only(command):
    """True when every simple command in a Bash line is in READ_ONLY; anything unparsed is not."""
    if not isinstance(command, str) or "$(" in command or "`" in command:
        return False
    try:
        lex = shlex.shlex(command.replace("\n", ";"), posix=True, punctuation_chars=True)
        tokens = list(lex)
    except ValueError:
        return False
    words = []
    for token in tokens + [";"]:
        punct = set(token) <= set("();<>|&")
        if punct and set(token) <= set("();|&"):  # a separator such as ; && | ( or );
            if words and not read_only_simple(words):
                return False
            words = []
        elif punct and ("(" in token or not words):  # <( process substitution, leading redirect
            return False
        else:
            words.append(token)
    return True


def read_only_simple(words):
    name, rest = words[0], words[1:]
    if name == "git":
        while len(rest) > 1 and rest[0] in ("-C", "-c"):
            rest = rest[2:]
        return bool(rest) and rest[0] in READ_ONLY_GIT
    if name == "find":
        return not {"-exec", "-execdir", "-ok", "-okdir", "-delete", "-fprint"} & set(rest)
    return name in READ_ONLY


def main():
    args = sys.argv[1:]
    since = None
    rest = []
    while args:
        a = args.pop(0)
        if a == "--since":
            if not args:
                bad_usage("--since needs a timestamp")
            a = "--since=" + args.pop(0)
        if a.startswith("--since="):
            since = parse_time(a[len("--since="):])
            if since is None:
                bad_usage(f"--since wants ISO 8601 with a zone, got {a[len('--since='):]!r}")
            continue
        rest.append(a)
    as_json = "--json" in rest
    as_signals = "--signals" in rest
    if as_json and as_signals:
        bad_usage("--json and --signals are exclusive")
    if since is not None and not as_signals:
        bad_usage("--since works only with --signals")
    args = [a for a in rest if a not in ("--json", "--signals")]
    path = resolve(args[0] if args else None)
    seen = set()
    calls = {}
    counts = collections.Counter()
    repeats = collections.Counter()
    exact = collections.Counter()  # untruncated input, so --signals never merges distinct calls
    merges = []
    signal_errors = []
    errors, results, prompts, answers = [], [], [], []
    peak_context = output_tokens = compactions = 0
    final_output = None  # stream-json `result` record: per-record usage there is a partial snapshot

    with open(path, encoding="utf-8") as f:
        for line in f:
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if rec.get("isSidechain") or rec.get("parent_tool_use_id"):
                continue
            stamp = parse_time(str(rec.get("timestamp"))) if rec.get("timestamp") else None
            counted = since is None or stamp is None or stamp >= since
            if rec.get("type") == "result" and isinstance(rec.get("usage"), dict):
                final_output = rec["usage"].get("output_tokens")
            if rec.get("type") == "system" and "compact" in str(rec.get("subtype", "")):
                compactions += 1
            msg = rec.get("message") or {}
            content = msg.get("content")
            usage = msg.get("usage") if rec.get("type") == "assistant" else None
            if usage and (msg.get("id") is None or msg["id"] not in seen):  # one API message spans several records
                seen.add(msg.get("id"))
                context = sum(usage.get(k) or 0 for k in (
                    "input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
                peak_context = max(peak_context, context)
                output_tokens += usage.get("output_tokens") or 0
            if rec.get("type") == "assistant" and isinstance(content, list):
                for b in content:
                    if b.get("type") == "tool_use":
                        sig = short(json.dumps(b.get("input"), sort_keys=True), 200)
                        calls[b["id"]] = (b["name"], sig)
                        counts[b["name"]] += 1
                        repeats[(b["name"], sig)] += 1
                        command = (b.get("input") or {}).get("command") if b["name"] == "Bash" else None
                        calls[b["id"]] += (command,)
                        if not counted:
                            continue
                        exact[(b["name"], json.dumps(b.get("input"), sort_keys=True))] += 1
                        hit = MERGE.search(command) if isinstance(command, str) else None
                        if hit:
                            merges.append((pr_number(hit.group(1)), short(command, 200)))
            elif rec.get("type") == "user":
                if isinstance(content, str):
                    if not content.startswith("<"):
                        prompts.append(short(content, 240))
                    continue
                for b in content or []:
                    if b.get("type") == "text" and not b.get("text", "").startswith("<"):
                        prompts.append(short(b["text"], 240))
                    if b.get("type") != "tool_result":
                        continue
                    name, sig, command = calls.get(b.get("tool_use_id"), ("?", "", None))
                    body = text_of(b.get("content"))
                    results.append((len(body), name, sig))
                    if name == "AskUserQuestion":
                        answers.append(short(body, 240))
                    if b.get("is_error"):
                        errors.append((name, short(body)))
                        quiet = name == "Bash" and re.match(r"Exit code 1(\n|$)", body) and read_only(command)
                        if counted and not quiet:
                            signal_errors.append((name, short(body)))

    if as_signals:
        for name, body in signal_errors:
            print(f"signal: error tool={name} result={body}")
        for (name, full), n in exact.most_common():
            if n < REPEAT_SIGNAL:
                break
            print(f"signal: repeat tool={name} count={n} input={short(full, 200)}")
        for pr, command in merges:
            print(f"signal: merge pr={pr} command={command}")
        return
    if final_output is not None:
        output_tokens = final_output
    if as_json:
        print(json.dumps({
            "session": path, "user_prompts": len(prompts),
            "tool_use": sum(counts.values()), "tool_use_by_name": dict(counts),
            "repeats": sum(n - 1 for n in repeats.values()),
            "top_repeats": [{"name": k[0], "input": k[1], "count": n}
                            for k, n in repeats.most_common(5) if n > 1],
            "errors": len(errors), "peak_context": peak_context,
            "output_tokens": output_tokens, "compactions": compactions,
        }, sort_keys=True))
        return
    print(f"session: {path}")
    print(f"user prompts: {len(prompts)}  tool calls: {sum(counts.values())}")
    print(f"peak context tokens: {peak_context}  output tokens: {output_tokens}  "
          f"compactions: {compactions}")
    subagents = glob.glob(os.path.join(path[: -len(".jsonl")], "subagents", "*.jsonl"))
    if subagents:
        print(f"sub-agent logs: {len(subagents)} (pass one as the argument to digest it)")
    print("\n## tool calls by name")
    for name, n in counts.most_common():
        print(f"- {name}: {n}")
    print(f"\n## errored tool results ({len(errors)})")
    for name, body in errors:
        print(f"- {name}: {body}")
    print("\n## repeated identical calls")
    for (name, sig), n in repeats.most_common():
        if n < 2:
            break
        print(f"- {name} x{n}: {sig}")
    print("\n## largest tool results (chars)")
    for size, name, sig in sorted(results, reverse=True)[:5]:
        print(f"- {size} {name}: {sig}")
    print("\n## user prompts (corrections and steering show up here)")
    for i, p in enumerate(prompts, 1):
        print(f"{i}. {p}")
    print(f"\n## answers to structured questions ({len(answers)})")
    for a in answers:
        print(f"- {a}")


if __name__ == "__main__":
    main()
