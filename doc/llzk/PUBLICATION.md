# Organization publication settings

Updated: 2026-08-25

Status: intentionally Public bootstrap; hosted-CI portability recovery in
progress; publication closure and settings changes remain incomplete

This is the current-state and settings sheet for the organization repository.
It records completed bootstrap facts separately from the narrow recovery now
authorized and from later publication work that remains unauthorized.

## Repository identity

Actual destination: `project-llzk/clean-llzk-frontend`, repository ID
`1345370888`, with full selected history. The repository was created on
2026-08-24 and its Public visibility is intentional by explicit owner decision.

Proposed metadata:

| Setting | Value |
|---|---|
| Description | Assurance-oriented Clean frontend for LLZK, implemented and checked in Lean 4 |
| Visibility | Public; keep Public |
| Default branch | `main` |
| Topics | `llzk`, `lean4`, `formal-verification`, `zero-knowledge`, `zkp`, `compiler`, `clean` |
| Issues | Enabled |
| Wiki | Disabled; repository documentation is authoritative |
| Projects | Disabled initially |
| Discussions | Disabled initially; enable only with an owner and moderation plan |
| Merge strategy | Squash merge; delete head branches after merge |

The organization profile should add this entry under “Frontends” only after
publication closure:

```markdown
- [Clean](https://github.com/project-llzk/clean-llzk-frontend)
```

As checked through the GitHub API on 2026-08-24, the organization profile has no
Clean entry, `project-llzk/llzk-lib` has no repository security policy, and its
private vulnerability reporting is disabled. Do not assume organization-wide
defaults supply either feature for this repository.

`project-llzk` is currently on GitHub Free. Public visibility now permits the
planned branch protection and
[private vulnerability reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting),
but neither is enabled. Main is unprotected; Dependabot security updates,
secret scanning, and push protection are also disabled. Those are exposed
bootstrap boundaries, not implicit authorization to change settings during the
portability recovery.

## Commit roles

- `193ec342cb2aae9055c36f4f77d2a4fe23da7823` remains the semantic R8 code
  candidate and theorem/reproduction evidence authority.
- `03150549adebd1ef4d83d1415bdcd117e9887493` is the exposed bootstrap `main`.
- `f6ef1331ee860a2395d7058025da488e2553a390` is the tested hosted-portability
  candidate C, the sole direct child of `03150549`.
- C's reviewed documentation/evidence-only sole child D is the proposed
  replacement `main`. D is not relabelled as the locally matrix-tested code SHA.

Run all four organization jobs first on exact D through its automatic
`event=push` run. Only if that attempt-1 run is wholly green may C be pushed as
`r8-code-candidate-f6ef1331` and `ci.yml` dispatched once on that branch. Accept
only `event=workflow_dispatch` with `head_sha=f6ef1331`; the separate main result
must be its push-event run at exact D. A parent, rerun, synthetic merge revision,
or job-name match without the exact SHA/event does not substitute.

## Desired default-branch protection (not yet authorized)

Configure `main` with:

- pull requests required; at least one approving review;
- stale approvals dismissed when the diff changes;
- conversation resolution required;
- branches required to be up to date before merging;
- force pushes and deletion disabled;
- linear history required;
- administrator bypass disabled for ordinary changes;
- no code-owner requirement until an organization team is explicitly named.

Required status checks, matching `.github/workflows/ci.yml`:

- `build`
- `llzk-harness`
- `llzk-e2e`
- `plonky3-backend`

The release-candidate commit must receive those checks at its own SHA. A green
run on an older staging-fork commit is not publication evidence.

Bind these checks through `required_status_checks.checks`, not legacy bare
`contexts`: copy each `{context, app_id}` from the exact initial-main GitHub
Actions check runs, set `strict: true`, then read the protection object back and
verify all four bindings. Before requiring an approval with administrator
enforcement, verify that a second human with write or admin permission is
available to approve the later evidence PR; its author cannot approve it. If no
qualified reviewer exists, publication pauses rather than weakening or
bypassing the rule.

## Desired security and Actions state (not yet authorized)

- Enable GitHub private vulnerability reporting before announcing the
  repository; `SECURITY.md` directs reporters to it.
- Enable dependency-graph and Dependabot security alerts.
- Keep the default `GITHUB_TOKEN` permission read-only. The main CI workflow
  declares that default in-repository; opt-in workflows declare their minimal
  job-level writes.
- Preserve the full action commit SHAs recorded in `PINS.md`, the
  `ubuntu-24.04` hosted-runner label, and Rust `1.98.0`.
- Preserve the LLZK job's exact public substituter/key and `--max-jobs 0`; the
  frozen organization run must prove it can download the accepted output
  anonymously rather than fall back to a source build.
- Run `scripts/llzk/check-actions-pinned.sh` after any workflow change. A release
  label in a comment is not a dependency pin.
- Leave the repository variable `CLEAN_BENCH_ENABLED` unset. The two self-hosted
  benchmark jobs execute pull-request code in a Docker container with network
  access and persistent caches; their Docker base and elan bootstrap also need
  immutable provenance. Enable them only after a named runner owner reviews the
  container image, network, cache isolation, cleanup, and host exposure. They
  are not required release checks.
- Preserve secret scanning if it is available to the organization.

## Publication procedure

Repository creation and the owner-directed Public visibility change are already
facts. The currently authorized recovery is deliberately narrower than the
remaining settings sheet:

1. Keep `CLEAN_BENCH_ENABLED` absent. Re-read Public visibility, exact remote
   `main=03150549`, branches, runs, and the held local publication lock. Any
   unexpected change is a stop.
2. Seal one documentation/evidence-only sole child D of exact tested candidate
   C=`f6ef1331`. Its diff must contain only `doc/llzk/` paths and preserved raw
   evidence; the candidate worktree must be clean.
3. Push D once with an explicit non-force fast-forward refspec to public `main`.
   Read the ref back. Do not push C yet.
4. Require one newly registered automatic CI run with repository
   `project-llzk/clean-llzk-frontend`, `event=push`, `head_sha=D`, and
   `run_attempt=1`. Accept it only if `build`, `llzk-harness`, `llzk-e2e`, and
   `plonky3-backend` all conclude success. Bench Main should remain skipped.
   A rerun, dispatch, parent result, duplicate attempt, or synthetic merge SHA
   does not substitute; any failure stops the transaction.
5. Only after step 4 succeeds, push exact C once to
   `refs/heads/r8-code-candidate-f6ef1331` with a non-force refspec and read the
   ref back. Dispatch `ci.yml --ref r8-code-candidate-f6ef1331` exactly once.
6. Accept only the resulting `event=workflow_dispatch`, `head_sha=C`,
   `run_attempt=1` suite with the same four successful jobs. Stop on any
   mismatch, failure, duplicate, missing run, or external-state drift.

This packet authorizes no workflow edit, force push, rerun, visibility change,
metadata/profile edit, organization-policy change, branch protection, security
setting, benchmark enablement, or announcement. The repository remains Public.
Those remaining closure items require a later explicit decision. The exact D
push run and exact C dispatch are terminal GitHub evidence for this recovery;
an in-repository file cannot contain its own commit SHA or subsequent run ID.

## State verification

The authorized operator should inspect, not infer, the resulting state:

```bash
gh repo view project-llzk/clean-llzk-frontend \
  --json nameWithOwner,description,visibility,defaultBranchRef,url
gh api repos/project-llzk/clean-llzk-frontend/branches/main/protection
gh api repos/project-llzk/clean-llzk-frontend/private-vulnerability-reporting
gh run list --repo project-llzk/clean-llzk-frontend --branch main
```

These are verification commands, not authorization to create or modify the
repository.
