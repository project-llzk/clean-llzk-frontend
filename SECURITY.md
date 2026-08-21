# Security policy

## Supported versions

This Clean-to-LLZK frontend has not made a versioned public release. Reports
against the current default branch are welcome, but there is no stable-version
support promise yet. After organization publication, the protected default
branch and the latest release will be the supported lines; historical
development branches and the personal staging fork will not be.

The frontend is experimental formal-verification infrastructure. Its documented
claim boundaries—especially the absence of a formal LLZK semantics and the open
caller-to-circuit lookup-table identity gap—are maintained in
[`doc/llzk/GAPS.md`](doc/llzk/GAPS.md). A documented limitation is not by itself
a vulnerability, but an implementation that exceeds or contradicts that
boundary may be one.

## Reporting a vulnerability

Do not disclose suspected vulnerabilities in a public issue, pull request,
discussion, or chat channel.

Once the organization repository is public, use its **Security → Report a
vulnerability** form. Publication is not complete until GitHub private
vulnerability reporting is enabled for the repository, as required by
[`doc/llzk/PUBLICATION.md`](doc/llzk/PUBLICATION.md).

If that form is unexpectedly unavailable, open a detail-free issue titled
“Private security contact needed.” Include no exploit, affected circuit,
private artifact, or reproduction details. A maintainer can then establish a
private channel before technical information is exchanged.

A useful private report includes:

- the exact repository commit and Clean/LLZK pins;
- the affected circuit, theorem, gate, parser, or emitted artifact;
- the difference between the documented claim and observed behaviour;
- a minimal reproduction, if it can be shared safely;
- the potential impact and whether disclosure is already public.

Particularly relevant reports include an accepted circuit whose emitted
constraints or witnesses do not match Clean, a way around a fail-closed gate,
an unsound theorem instantiation, a renderer check bypass, or a supply-chain
issue in the pinned tool path.

## Disclosure

Please allow maintainers time to reproduce, assess, and repair the problem
before public disclosure. Maintainers will keep the reporter informed through
the private advisory, credit them if requested, and record any change to the
project's assurance boundary in the gap and decision registers.
