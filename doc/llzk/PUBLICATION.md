# Organization publication settings

Updated: 2026-08-21

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
| Visibility | Public, only at the authorized publication step |
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

As checked through the GitHub API on 2026-08-21, the organization profile has no
Clean entry, `project-llzk/llzk-lib` has no repository security policy, and its
private vulnerability reporting is disabled. Do not assume organization-wide
defaults supply either feature for this repository.

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

1. Record the frozen candidate SHA and every accepted external pin.
2. Choose new descriptive repository versus fork transfer explicitly.
3. Create or transfer the repository and apply the metadata above.
4. Push the frozen history and make `main` the protected default branch.
5. Enable private vulnerability reporting and the security features above.
6. With self-hosted benchmarking still disabled, run all four required CI jobs
   on the frozen SHA in the organization repository; do not reuse staging-fork
   status.
7. Add the organization-profile link and verify the README, security form,
   contribution links, badges, and generated showcase anonymously.
8. Record the resulting repository URL, protection state, CI run, and release
   SHA in `CURRENT.md` and the publication evidence directory.

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
