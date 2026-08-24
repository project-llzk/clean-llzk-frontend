# Organization publication settings

Updated: 2026-08-24

Status: prepared locally; no repository creation, transfer, push, or settings
change is authorized by this document

This is the settings sheet for the final publication action. It makes D027's
repository choice and the non-code parts of `PUBLIC-READINESS.md` reviewable
before anybody changes GitHub state.

## Repository identity

Preferred destination: `project-llzk/clean-llzk-frontend`.

The descriptive name makes this repository legible beside the organization's
Circom, Halo2/PLONKish, Airbender, and Noir frontends. Preserving the GitHub fork
badge by transferring the personal `clean` fork remains an alternative, but it
must be chosen explicitly; this sheet does not decide or perform the transfer.

Proposed metadata:

| Setting | Value |
|---|---|
| Description | Assurance-oriented Clean frontend for LLZK, implemented and checked in Lean 4 |
| Visibility | Private bootstrap; controlled Public activation after exact-SHA CI |
| Default branch | `main` |
| Topics | `llzk`, `lean4`, `formal-verification`, `zero-knowledge`, `zkp`, `compiler`, `clean` |
| Issues | Enabled |
| Wiki | Disabled; repository documentation is authoritative |
| Projects | Disabled initially |
| Discussions | Disabled initially; enable only with an owner and moderation plan |
| Merge strategy | Squash merge; delete head branches after merge |

The organization profile should add this entry under “Frontends” after the
repository exists:

```markdown
- [Clean](https://github.com/project-llzk/clean-llzk-frontend)
```

As checked through the GitHub API on 2026-08-24, the organization profile has no
Clean entry, `project-llzk/llzk-lib` has no repository security policy, and its
private vulnerability reporting is disabled. Do not assume organization-wide
defaults supply either feature for this repository.

`project-llzk` is currently on GitHub Free. GitHub provides
[protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
for this plan only on public repositories, while
[private vulnerability reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting)
is itself a public-repository feature. Therefore a private bootstrap cannot
install the final protection first. The Free-plan path below bounds the
activation interval and forbids any push during it. An upgrade to Team would
permit protection while private, but is a separate cost and authorization, not
an assumed prerequisite.

The current CLI credential could read repository-level settings but could not
read organization Actions policy or billing/minute allowance. Before creating
the repository, an authorized operator must verify that policy and private-run
capacity through an appropriately scoped credential or the organization UI.
Failure to establish either is a stop condition, not permission to make the
repository public early.

## Commit roles

- `193ec342cb2aae9055c36f4f77d2a4fe23da7823` is the immutable code candidate
  that passed both local matrices and R8.
- Its reviewed documentation descendant is the proposed initial organization
  `main`; it must include the final evidence rather than stopping at the code
  candidate.
- Any later publication-evidence merge is a distinct public tip. It does not
  retroactively become the locally matrix-tested code candidate.

Run all four organization jobs at exact `193ec342`, at the exact initial `main`,
and at every later protected-main merge used for publication closure. A PR check
on GitHub's synthetic merge revision, a squash-created replacement SHA, or a
green parent is not evidence for any of those exact commits.

The exact code candidate is reached through dedicated branch
`r8-code-candidate-193ec342`. `workflow_dispatch` takes a branch or tag rather
than a raw SHA and the workflow must already exist on default `main`: push and
verify initial `main`, push
`193ec342:refs/heads/r8-code-candidate-193ec342`, verify that ref, then dispatch
`ci.yml --ref r8-code-candidate-193ec342`. Accept only
`event=workflow_dispatch` with `head_sha=193ec342`; the separate initial-main
result must be its `push`-event run at that exact documentation SHA.

## Default-branch protection

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

## Security and Actions

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

Only after L0, S26, S28, promoted headline examples, and R8 are complete:

Sealing this document authorizes none of the actions below. One explicit user
decision may authorize the complete enumerated packet, but it must name the
descriptive-repository topology and cover repository creation, the local
publication remote, both exact ref pushes, workflow dispatch, metadata,
protection, security settings, public visibility, anonymous verification,
organization-profile edit, the evidence PR/merge, and contingency return to
Private if activation configuration fails. Any omitted action remains out of
scope. An organization plan upgrade, billing change, Actions-policy change, or
benchmark enablement always requires another explicit decision.

1. Record the code-candidate SHA, reviewed documentation tip, and every accepted
   external pin; choose new descriptive repository versus fork transfer
   explicitly. Verify organization Actions policy, private-run capacity, and a
   second qualified human reviewer.
2. Create the authorized destination **private**, empty, and without a generated
   README, license, or initial commit. Add a distinct local `publication` remote;
   do not repurpose `origin` or `upstream`.
3. Keep `CLEAN_BENCH_ENABLED` unset. Push complete history with explicit,
   non-force immutable refspecs: the reviewed documentation tip to `main`, and
   exact `193ec342` to `r8-code-candidate-193ec342`. Read both refs back.
4. Accept the initial-main `push` run and the code-candidate `workflow_dispatch`
   run only when all four jobs are green at their exact SHAs. Inspect repository,
   event, head SHA, attempt, and check-run application, and retain the four
   initial-main `{context, app_id}` bindings.
5. While private, apply metadata and every security setting available on the
   current plan. Reconfirm the allowed writers and exact `main` SHA, then freeze
   all pushes for the activation transaction.
6. On GitHub Free, change visibility to Public without announcement, immediately
   install the app-bound branch protection described above, and enable private
   vulnerability reporting. Re-read the protection, reporting state, visibility,
   and `main` SHA; any change or failed setting stops the transaction before a
   profile link. Do not push during this interval. If rollback to private was
   authorized in the publication packet, immediately perform it, verify Private
   visibility and the exact unchanged `main` SHA, keep the push freeze, record
   the failure, and abort. If rollback was omitted or itself fails, leave the
   repository unannounced and frozen, add no profile link, and escalate the
   exact partial state. On Team or Enterprise, protection may instead be
   installed and verified while private before the visibility change.
7. Verify the README, security form, contribution links, badges, generated
   showcase, visibility, protection, and CI anonymously. Only then add the
   organization-profile link or announce publication.
8. Record the repository URL, exact code candidate, initial-main CI run IDs,
   protection, visibility, and security state in `CURRENT.md` and a publication
   evidence file. Submit that closure as a protected PR with an independent
   approval. After its squash merge, require the `push`-event four-job suite on
   the resulting exact `main` SHA; PR checks on the synthetic merge revision do
   not substitute.
9. Treat that exact post-merge SHA and its GitHub check suite as terminal external
   evidence. No in-repository file can contain its own commit SHA or post-merge
   run ID; do not create another documentary child merely to name them.

## Post-publication verification

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
