# Clean → LLZK: cross-session orchestration plan

> **Historical bootstrap protocol.** S00 enacted this plan and repository-owned
> `CURRENT.md`, `PINS.md`, `GATES.md`, and `PUBLIC-READINESS.md` are now the
> control plane. Paths, branches, and starting pins below are preserved as
> provenance, not current instructions.

**Date:** 2026-07-31  
**Status:** proposed execution protocol  
**Architecture baseline:** `clean-to-llzk-plan-2026-07-31.md`

## 1. Objective

Make the work resumable, reviewable, and safe across independent Codex or human
sessions. No session should need chat history to discover:

- the accepted source revisions;
- the current integration commit;
- what has actually passed;
- what remains blocked;
- the exact next bounded task.

The unit of execution is a **session packet**: one commit-sized objective, its
allowed scope, and its acceptance gates. Milestones are accepted only by
evidence committed in the repository, not by a session's narrative.

## 2. One canonical control plane

`/home/alh/LLZK` is currently an unversioned coordination directory, and the
reviewed Clean checkout is outside its writable workspace. Session S00 must
create a dedicated Clean worktree inside `/home/alh/LLZK`, based on the pinned
Clean revision, and establish an integration branch.

Suggested local shape:

```text
/home/alh/LLZK/
  clean-llzk-frontend/       # dedicated Clean integration worktree
  clean-to-llzk-plan-2026-07-31.md
  clean-to-llzk-session-orchestration.md
```

Suggested branch:

```text
clean-to-llzk/integration
```

Once S00 is complete, repository-owned files under the Clean worktree become
the source of truth:

```text
doc/llzk/
  CURRENT.md                 # single resume point; updated every session
  ROADMAP.md                 # milestone and session dependency graph
  PINS.md                    # exact source/tool revisions and acquisition
  DECISIONS.md               # append-only architecture decision log
  GATES.md                   # commands and meanings of acceptance gates
  SESSION_TEMPLATE.md
  sessions/
    S00-bootstrap.md
    S01-llzk-tooling.md
    ...
  evidence/
    S00/
    S01/
    ...
scripts/llzk/
  doctor.sh
  check-pins.sh
  e2e.sh
```

Until then, this file and the architecture baseline in the coordination
directory are the bootstrap record. S00 copies them into `doc/llzk/` and
records their provenance.

## 3. Pinned inputs

S00 records and verifies at least:

| Component | Accepted starting revision |
|---|---|
| Clean | `1e563b9c27991b3795eb440c1ee0757edb4ce8b1` |
| LLZK | `5db6f8f9baaa40787a1a40625796497445f2da36` |
| project-llzk VeIR | `eae1c27e7842c0503233ec99155c39791bd5f502` |
| upstream VeIR | `a4e6194d5810a02d74f0094ff6014cda6db6d617` |
| llzk-lean accepted VeIR pin | `d899d95004d4bd988c8456d686c33b11a7a5eb4a` |

`PINS.md` must distinguish:

- a source revision;
- a locally tested tool binary and its version;
- how that binary was obtained;
- the command used to reproduce it.

Updating a pin is its own session objective or an explicit prerequisite in a
session packet. A session must not silently float a dependency.

## 4. Session lifecycle

### 4.1 Start

Every implementation session begins by:

1. reading the applicable `AGENTS.md` in full;
2. reading `doc/llzk/CURRENT.md`, `PINS.md`, `GATES.md`, and its session packet;
3. confirming the expected worktree, branch, and integration base;
4. checking `git status` and preserving unrelated work;
5. running `scripts/llzk/check-pins.sh` and the relevant doctor checks;
6. stating the one session objective and the gates required to accept it.

If the recorded state and filesystem disagree, the session becomes a recovery
session. It reconciles state before starting feature work.

### 4.2 Work

A session should:

- stay inside the files and repositories named in its packet;
- produce one coherent, reviewable result;
- add positive and negative tests with new accepted syntax or constructors;
- record architecture decisions when they are made, not in a later cleanup;
- use exact revisions for external evidence;
- avoid changing the integration worktree from another simultaneous session.

Discoveries may narrow the session. They may not silently broaden it. A design
change that invalidates the accepted architecture is recorded as a decision
proposal and handed to a dedicated decision session.

### 4.3 Close

Before ending, a session must:

1. run every required gate and retain concise evidence;
2. commit accepted implementation and control-plane changes together, or
   clearly record why the work remains uncommitted;
3. write its session record;
4. update `CURRENT.md` with the accepted integration commit, status, blockers,
   and exact next task;
5. leave the worktree clean, or list every intentional uncommitted path;
6. identify the first command the next session should run.

“Implemented” means the stated gates passed. “Investigated” or “drafted” must
not be reported as accepted implementation.

## 5. `CURRENT.md` resume contract

Keep `CURRENT.md` short enough to read at the beginning of every session:

```markdown
# Clean → LLZK current state

Updated: YYYY-MM-DD
Active milestone: P0
Last accepted session: S01
Integration branch: clean-to-llzk/integration
Integration commit: <full SHA>

## Accepted pins
- Clean: <SHA>
- LLZK source: <SHA>
- LLZK tools: <absolute or reproducible path, version>

## State
- Completed:
- In progress:
- Blocked:

## Last green gates
- G0: <command/evidence>
- G1: <command/evidence>

## Known constraints
- ...

## Next session
- Packet: doc/llzk/sessions/S02-golden-contract.md
- Objective: ...
- First command: ...
```

Only accepted integration state belongs under “Completed.” Branch-local work
belongs under “In progress.”

## 6. Session packet and handoff schema

Create each packet before its implementation session:

```markdown
# SNN — Title

Status: proposed | active | accepted | blocked | superseded
Depends on: SNN
Base integration commit: <full SHA>
Worktree:
Branch:

## Objective
One observable outcome.

## Must read
Exact files, decisions, and external references.

## Allowed scope
Repositories and files that may change.

## Deliverables
Concrete source, tests, documentation, or tool artifacts.

## Non-goals
Adjacent work explicitly excluded.

## Acceptance gates
Gate IDs plus exact commands.

## Evidence
Repository paths containing concise results.

## Handoff
- Changes made:
- Decisions made:
- Deviations:
- Blockers:
- Resulting commit:
- Exact next action:
```

If a session is blocked, its handoff must state the smallest external action or
decision needed to unblock it. Failed commands and partial results belong in
the session record; they do not become milestone acceptance evidence.

## 7. Branch, worktree, and integration rules

- One active writing session owns one worktree and one branch.
- Two sessions must never edit the same worktree concurrently.
- The integration branch advances only through reviewed commits whose packet
  gates pass.
- Concurrent work is integrated through commits, not through shared
  uncommitted files.
- Each feature branch starts at the `Base integration commit` recorded in its
  packet.
- A session rebases or refreshes its branch only as an explicit integration
  step and reruns its gates afterward.
- External repositories are read-only unless their packet explicitly
  authorizes changes.
- No result that exists only in `/tmp` is durable evidence.
- Publishing a branch, opening a PR, changing machine trust configuration, or
  modifying an upstream repository requires explicit authorization.

Prefer a small linear history for the core frontend. Preserve separate commits
when they have independent review value, such as tool bootstrap, golden
contract, emitter IR, and semantic lowering.

## 8. Dependency-ordered session packets

### S00 — Bootstrap the control plane

Create the dedicated Clean worktree and integration branch. Copy the
architecture and orchestration baselines into `doc/llzk/`. Add `CURRENT.md`,
`PINS.md`, `DECISIONS.md`, `GATES.md`, the session template, and pin/doctor
scripts.

**Exit:** the worktree is clean, the Clean pin is exact, the ordinary Clean
build/targeted checks are green, and a fresh session can resume solely from
repository files.

### S01 — Provision current LLZK 3.0 tools

Resolve the trusted-binary-cache versus reproducible source-build issue. Record
the selected `llzk-opt` and `llzk-witgen` paths, versions, acquisition method,
and smoke tests. Do not implement frontend code.

**Exit:** both tools from the pinned LLZK revision are reproducibly available;
the stale installed LLZK 2.0 package cannot accidentally satisfy the doctor.

### S02 — Freeze the handwritten golden contract

Implement the handwritten `Addition8FullCarry.llzk`, named inputs, expected
public output, expected full witness, and Clean comparison fixtures.

**Exit:** `llzk-opt` parse and round-trip pass; interpreter and
execution-engine witness generation agree with expected output and Clean on
the selected input corpus. The fixture becomes the frontend contract.

### R0 — P0 review

Start read-only. Re-run S01–S02 gates from the recorded integration commit,
inspect the fixture against current LLZK syntax, and record discrepancies.

**Exit:** P0 is either accepted or returned to a narrowly scoped repair
session.

### S03 — Backend-local IR and deterministic renderer

Add `Basic.lean`, `IR.lean`, and `Print.lean` with a minimal typed emitter
model. Test deterministic rendering of a small module. Do not yet walk a Clean
circuit.

**Exit:** targeted Lean tests and deterministic golden tests pass.

### S04 — Analysis, layout, and assertion-only vertical slice

Add fail-closed analysis, generated input/witness/output layouts, field
expression lowering, assertion lowering, and a tiny assertion-only circuit.

**Exit:** the generated artifact passes LLZK parse/round-trip and differential
witness tests; unsupported operations fail during analysis.

### R1 — Frontend-foundation review

Audit the public backend API, diagnostics, output stability, unsupported-case
behavior, and whether S03's emitter IR is sufficiently stable for parallel
follow-on work.

### S05 — Addition8 witness computation

Lower the two explicitly recognized safe `NExpr` div/mod shapes, compute
arguments, witness writes, and output mapping. Keep general natural arithmetic
rejected.

**Exit:** generated computation agrees with Clean and both LLZK witness
backends for boundary and representative inputs.

### S06 — Export tables and full constraints

Add `ExportTable.ofStatic`, registry validation, ByteTable materialization,
`global.def/read`, lookup lowering, and `constrain.in`.

**Exit:** compiler output implements the full Addition8 golden contract;
unresolved, duplicate, or wrong-arity tables fail closed.

### S07 — User command and conformance harness

Add `#emit_llzk` or the selected file-output command, stable fixtures, and one
fail-closed end-to-end script. The harness must check exact tool versions
before accepting results.

**Exit:** one documented command emits Addition8 LLZK and one documented
command performs all Stage-1 conformance checks.

### R2 — Stage-1 acceptance

Re-run the full matrix from a clean checkout, inspect all capability
boundaries, and ensure documentation matches actual commands.

**Exit:** Stage 1 is accepted only if a clean session can reproduce it without
undocumented local state.

### S08 — Proof baseline

Define executable semantics for the backend-local subset and prove the first
field-expression, assertion, witness, and output-layout preservation results.
Track theorem coverage explicitly; do not describe unproved constructors as
verified.

### S09+ — Constructor-by-constructor expansion

Select additions from real target circuits. Give every new constructor its own
or a tightly related session packet with:

- one positive differential fixture;
- one negative or boundary fixture;
- explicit semantics and bounds assumptions;
- analyzer support;
- an updated proof-coverage entry.

General natural-number lowering, arrays/lists, conditionals, interactions, and
AIR/table-ensemble circuits remain separate decisions rather than an implicit
backlog bundle.

## 9. Parallel tracks

The core critical path is deliberately linear:

```text
S00 → S01 → S02 → R0 → S03 → S04 → R1 → S05 → S06 → S07 → R2
```

Safe parallelism begins only at stable seams:

- After S02, a **V00 VeIR audit** may independently test the frozen fixture
  corpus with unregistered-dialect round trips and produce a fork/upstream
  strategy. It must not add a direct VeIR dependency to Clean.
- After S04 and R1, proof work for the accepted expression/assertion subset may
  trail implementation in separate files and a separate worktree.
- Documentation and additional black-box fixture generation may proceed after
  their schemas are frozen.

Keep these linear:

- changes to the backend-local IR and renderer;
- layout and witness-cell ownership;
- analyzer capability decisions;
- golden fixture format;
- integration-branch and pin updates.

Parallel sessions name disjoint file ownership in their packets. If two tasks
need the same public API, first land a short API-freeze session or keep the work
linear.

## 10. Acceptance gates

`GATES.md` will hold exact commands. The stable gate meanings are:

| Gate | Requirement |
|---|---|
| G0 — State | Expected branch/worktree, clean or documented status, exact pins |
| G1 — Lean | Targeted Lean compilation/tests; broader build when required |
| G2 — Golden | Deterministic text matches the reviewed fixture |
| G3 — LLZK verify | Current pinned `llzk-opt` parses and verifies |
| G4 — Round trip | Current pinned `llzk-opt --verify-roundtrip` succeeds |
| G5 — Interpreter | Pinned `llzk-witgen` interpreter produces expected witness |
| G6 — Execution engine | Pinned execution engine produces the same witness |
| G7 — Differential | Clean and LLZK witnesses agree on the recorded corpus |
| G8 — Fail closed | Unsupported constructs and bad table/layout inputs diagnose |
| G9 — Proof | Named theorem target builds without new `sorry` or excluded axioms |

Each session packet lists only the gates relevant to its objective. R0, R1,
and R2 repeat the accumulated milestone gates rather than trusting prior logs.

Evidence should be concise and durable, for example:

```text
doc/llzk/evidence/S05/
  environment.txt
  commands.txt
  lean-test.txt
  llzk-opt.txt
  interpreter.json
  execution-engine.json
  clean-witness.json
  comparison.txt
```

Record complete commands, exit status, tool version, and relevant output. Do
not commit enormous build logs when a versioned script plus concise result is
sufficient.

## 11. Decision and escalation boundaries

A normal session may make local, reversible changes inside its packet and run
the named tests. Pause for an explicit decision before:

- changing the pinned Clean or LLZK source revision;
- changing Nix trust or binary-cache configuration;
- modifying Clean's core `RawTable` representation rather than using the
  backend registry;
- broadening Stage 1 beyond its fail-closed constructor set;
- adding a direct VeIR dependency to Clean;
- rebasing or publishing the project LLZK VeIR fork;
- pushing branches or opening upstream pull requests.

Record accepted decisions in `DECISIONS.md` with context, alternatives,
decision, consequences, and the session/commit that enacted them.

## 12. Recommended session cadence

- Keep one session to one externally observable, commit-sized outcome.
- Run a review session at every milestone boundary and whenever a shared API
  is declared stable.
- Use a recovery session after interrupted builds, dirty shared state, or
  disagreement between `CURRENT.md` and the filesystem.
- Update `CURRENT.md` last, after gates and integration, so it always points
  at accepted state.
- Begin the next session from its packet and recorded base commit, never from a
  prose memory of the previous conversation.

The immediate next action is S00. S01 should not begin until S00 leaves a
versioned control plane and a clean, pinned Clean integration worktree.
