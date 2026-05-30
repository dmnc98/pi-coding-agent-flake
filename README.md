# pi-coding-agent-flake

A Nix flake that packages the [Pi Coding Agent](https://pi.dev) npm tarball and
ships a home-manager module for declaratively tracking pi's npm modules.

## Why this exists

- Upstream ships an `npm-shrinkwrap.json` at `lockfileVersion: 1`, which
  `prefetch-npm-deps` (used by `buildNpmPackage`) can't parse. A modern v3
  `package-lock.json` is regenerated on the fly inside a fixed-output
  derivation (`packageLock` in `default.nix`).
- The resulting `pi` binary is wrapped so that `${nodejs_22}/bin` is at the
  front of `$PATH`. Without this, `pi install npm:<module>` resolves to
  Windows `npm.cmd` via WSL interop and fails with cross-FS errors.

## Usage

### As a home-manager module (flake)

Add this flake as an input and import the module:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pi-coding-agent = {
      url = "github:dmnc98/pi-coding-agent-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, pi-coding-agent, ... }: {
    homeConfigurations."dominic" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      modules = [
        pi-coding-agent.homeManagerModules.default
        {
          programs.pi = {
            enable = true;
            packages = [
              "pi-lmstudio"
            ];
          };
        }
      ];
    };
  };
}
```

Inside an existing home-manager module file:

```nix
{ inputs, ... }:
{
  imports = [ inputs.pi-coding-agent.homeManagerModules.default ];

  programs.pi = {
    enable = true;
    packages = [ "pi-lmstudio" ];
  };
}
```

### Just the package

```nix
# In a NixOS or home-manager config that has the flake as an input
environment.systemPackages = [
  inputs.pi-coding-agent.packages.${pkgs.system}.default
];
```

Or as an overlay so `pkgs.pi-coding-agent` is available everywhere:

```nix
nixpkgs.overlays = [ inputs.pi-coding-agent.overlays.default ];
```

### Ad-hoc shell

```bash
nix run github:dmnc98/pi-coding-agent-flake -- --help
nix shell github:dmnc98/pi-coding-agent-flake
```

## Declarative npm modules

The `programs.pi` module keeps pi's npm modules
(`~/.pi/agent/npm/node_modules/*`) in sync with a declared list. Adding an
entry installs it on the next rebuild; removing one uninstalls it.

```nix
programs.pi = {
  enable = true;
  packages = [
    "pi-lmstudio"
  ];
};
```

Behind the scenes the module:

1. Adds `pi` and a `pi-packages-sync` helper to `home.packages`.
2. Writes the declared list to `~/.config/pi/packages.json`.
3. Runs `pi-packages-sync` on activation. The sync queries `pi list` for the
   current set, then calls `pi install npm:<name>` for any missing entries and
   `pi remove npm:<name>` for any extras. Going through pi's CLI (rather than
   raw `npm install`) ensures pi's own settings are updated and the extension
   is actually registered with the agent.

Run `pi-packages-sync` manually any time to re-reconcile (e.g. after restoring
the agent dir from backup).

Caveats:

- The sync calls `pi install` at runtime, so it needs network the first time
  a new module appears in the list.
- Versions are not pinned. If you need reproducibility, move to a
  `buildNpmPackage`-based node_modules derivation instead.

## Bumping the version

Three hashes rotate per version bump. Update them in this order:

### 1. `version` and `src.hash`

```bash
nix store prefetch-file --hash-type sha256 \
  https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-<NEW_VERSION>.tgz
```

Paste the printed `sha256-…` into `src.hash` and bump `version`.

### 2. `packageLock` `outputHash`

Set `outputHash = lib.fakeHash;` and rebuild:

```bash
nix build .#pi-coding-agent
```

The build fails with a hash mismatch on the `packageLock` FOD. Copy the
`got:` hash into `outputHash`.

### 3. `npmDepsHash`

Set `npmDepsHash = lib.fakeHash;` and rebuild again. Same drill — copy the
`got:` hash from the failure into `npmDepsHash`.

A final `nix build .#pi-coding-agent` should succeed.

## Files

- `flake.nix` — flake outputs: package, overlay, home-manager module.
- `default.nix` — the package derivation (consumed by the flake).
- `home-manager.nix` — home-manager module exposing `programs.pi`.

The v3 `package-lock.json` is generated at build time by the `packageLock`
derivation, not tracked in git.
