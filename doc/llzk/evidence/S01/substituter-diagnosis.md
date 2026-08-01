# S01 — why the LLZK 3.0 substitute is rejected

Integration commit under test: `003874ac` (S00 accepted).

## Symptom

```
$ nix build --no-link github:project-llzk/llzk-lib/5db6f8f9…#llzk
```

silently falls back to compiling LLVM 20.1.8 from source (~hours), even though

```
$ nix build --dry-run github:project-llzk/llzk-lib/5db6f8f9…#llzk
these 7 paths will be fetched (363.5 MiB download, 1.6 GiB unpacked):
  /nix/store/r0144dmh1cvy3d4dp33irwxbpyygl69x-llvm-release-20.1.8
  /nix/store/lpikdb181jali919kfh3fj5v5qpggscx-llvm-release-20.1.8-dev
  /nix/store/bdpr5a4i6wng7d9ap96gj4p9wgi7fdig-llvm-release-20.1.8-lib
  /nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0
  /nix/store/i2mlz7qnmpsydwh6k9jjnck0xcgxcyz2-mlir-release-20.1.8
  /nix/store/mvj0yjzdipwh47xfvjagczyd8bxilkbl-mlir-release-20.1.8-dev
  /nix/store/rsrv9sm3swdn6h75aph8ajv7n7q72ilz-mlir-release-20.1.8-lib
```

reports nothing to build. `--dry-run` reports *availability*, not *acceptance*;
the signature check happens only on the real realisation. Forcing the issue
makes it explicit:

```
$ nix-store --realise /nix/store/r0144dmh1cvy3d4dp33irwxbpyygl69x-llvm-release-20.1.8 --max-jobs 0
warning: ignoring substitute for '/nix/store/r0144dmh1cvy3d4dp33irwxbpyygl69x-llvm-release-20.1.8'
         from 'https://veridise-public.cachix.org', as it's not signed by any of
         the keys in 'trusted-public-keys'
error: path '…' is required, but there is no substituter that can build it
```

## Root cause

The configured public key is wrong, not missing. `/etc/nix/nix.conf` contains

```
extra-substituters = https://veridise-public.cachix.org
extra-trusted-public-keys = veridise-public.cachix.org-1:JpCpoT4eXIKt0DH9HCkICc4kSU92MzGUYR/N5sBouH8=
```

The key *name* matches the one in every narinfo `Sig:` field, so Nix selects it,
attempts Ed25519 verification, fails, and discards the substitute — reporting it
as unsigned. Verifying the narinfo fingerprint by hand:

| Ed25519 public key | source | verifies the signature on `r0144dmh1c…-llvm-release-20.1.8`? |
|---|---|---|
| `JpCpoT4eXIKt0DH9HCkICc4kSU92MzGUYR/N5sBouH8=` | `/etc/nix/nix.conf` | **no** |
| `FvpZ8GzAj1mmJA5PnO9UgKxC6CQdmPutuIKtEpGmeig=` | Cachix API for the cache | **yes** |

`https://app.cachix.org/api/v1/cache/veridise-public` independently advertises
`publicSigningKeys: ["veridise-public.cachix.org-1:FvpZ8GzAj1mmJA5PnO9UgKxC6CQdmPutuIKtEpGmeig="]`,
i.e. exactly the key that verifies. The configured value is stale or mistyped.

This is the concrete form of the "rejected as unsigned by the local Nix
configuration" note in `ARCHITECTURE.md` §4.2. That note attributed it to the
substitute being unsigned; it is in fact signed, by a key the machine has
recorded incorrectly.

## Why the obvious workarounds do not apply

`trusted-users = root`, and this work runs as `alh`. A non-trusted user cannot
supply `trusted-public-keys`, `--no-check-sigs`, or an extra substituter to the
daemon — the daemon ignores all of them. So the key must be corrected in
`/etc/nix/nix.conf`, or the closure must be built from source.

## Reproduction

```bash
curl -s https://veridise-public.cachix.org/r0144dmh1cvy3d4dp33irwxbpyygl69x.narinfo
curl -s https://app.cachix.org/api/v1/cache/veridise-public
```

Build the fingerprint `1;<StorePath>;<NarHash>;<NarSize>;<comma-separated absolute References>`
and Ed25519-verify the `Sig:` payload against each candidate key.
