#!/usr/bin/env python3
"""Print a Lean file with its comments blanked out, preserving line count.

G12 greps for the names of entry points that skip a gate. It was greping the
*source*, so a docstring saying "use `compile`, not `compileSource'`" counted as
a call site, and the fix each time was to widen the allowlist — three times in
one session (A2). An allowlist that grows every time someone writes a good
comment stops meaning "these modules may call this" and starts meaning "these
modules mention it", which is not a property worth gating.

So the gate reads code. Comments are blanked rather than deleted so that a
reported line number still points at the right line.

Handled: `--` to end of line, nested `/- … -/` (including `/-!` and `/-- … -/`),
and string literals, so that a `--` inside `s!"…"` does not blank the rest of a
line of real code. Not handled: character literals containing a quote, which do
not occur in this tree; if one appears, the failure mode is a *widened* match,
which is the safe direction for a gate.
"""

import sys


def strip(text: str) -> str:
    out = []
    i, n = 0, len(text)
    depth = 0          # nesting depth of /- -/
    in_string = False
    in_line_comment = False

    while i < n:
        c = text[i]
        two = text[i:i + 2]

        if c == "\n":
            in_line_comment = False
            out.append(c)
            i += 1
            continue

        if in_line_comment or depth > 0:
            # Inside a comment: blank everything but track nesting.
            if depth > 0 and two == "/-":
                depth += 1
                out.append("  ")
                i += 2
                continue
            if depth > 0 and two == "-/":
                depth -= 1
                out.append("  ")
                i += 2
                continue
            out.append(" ")
            i += 1
            continue

        if in_string:
            out.append(c)
            if c == "\\":
                # Keep the escaped character with it, so \" does not end the string.
                if i + 1 < n:
                    out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_string = False
            i += 1
            continue

        if c == '"':
            in_string = True
            out.append(c)
            i += 1
            continue

        if two == "/-":
            depth = 1
            out.append("  ")
            i += 2
            continue

        if two == "--":
            in_line_comment = True
            out.append("  ")
            i += 2
            continue

        out.append(c)
        i += 1

    return "".join(out)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: strip-lean-comments.py FILE", file=sys.stderr)
        return 2
    with open(sys.argv[1], encoding="utf-8") as handle:
        sys.stdout.write(strip(handle.read()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
