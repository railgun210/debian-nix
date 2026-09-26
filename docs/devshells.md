# Dev Shells

## What they're for

A dev shell is a temporary environment: run a command, get a shell with a
pinned set of tools, do your work, `exit`, and those tools are gone from
`PATH` again.

The everyday compilers (gcc, cargo, uv, ruff, node, ...) are installed
globally by `home-manager/utilities/development-tools.nix`. The dev shells
add the heavier or more specialised tools on top — valgrind, clippy,
rust-analyzer, pytest, the ML stack — pinned to this flake's nixpkgs.

---

## The built-in shells

After a `home-manager switch` (`nsr`), these commands are on your `PATH`:

| Command  | Environment | What you get |
|----------|-------------|-------------|
| `c-dev`  | C / C++     | gcc, gnumake, cmake, gdb, clang-tools, valgrind, pkg-config |
| `py-dev` | Python      | python3 with pip, virtualenv, pytest, numpy; uv, ruff, black |
| `rs-dev` | Rust        | rustc, cargo, clippy, rustfmt, rust-analyzer, cargo-edit |
| `ml-dev` | Python ML   | Python 3.12 with numpy, pandas, scipy, scikit-learn, matplotlib, seaborn, plotly, JupyterLab, ipywidgets, black |

```bash
$ c-dev
[nix-shell] $ which valgrind
/nix/store/...-valgrind-3.x/bin/valgrind
[nix-shell] $ exit
$ which valgrind
valgrind not found
```

The subshell is a normal interactive zsh, so your aliases, Powerlevel10k and
plugins all load inside it; only `PATH` and the build variables change.

`ml-dev`'s Python is also installed globally, so `jupyter lab` works outside
the shell and `.ipynb` files open in JupyterLab from the file manager (see
`utilities/default-apps.nix`).

### How it works

Each module in `home-manager/utilities/devshells/`:

1. Defines a `pkgs.mkShell` derivation with the package list.
2. Installs a wrapper (`pkgs.writeShellScriptBin`) that runs
   `nix-shell <that derivation> --command zsh`.

The wrapper is in `home.packages`, so it's always on `PATH` and pinned to the
same nixpkgs as the rest of the config.

---

## Project-specific shells

For a project that needs its own environment, put a `flake.nix` at the
project root:

```nix
# my-project/flake.nix
{
  description = "My C project";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

  outputs = {nixpkgs, ...}: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = with pkgs; [
        gcc
        cmake
        gdb
        libsodium # project-specific dependency
        openssl
      ];

      shellHook = ''
        export BUILD_DIR="$PWD/build"
      '';
    };
  };
}
```

Then:

```bash
cd my-project
nix develop
```

### Auto-loading with direnv

direnv and nix-direnv are already enabled (`development-tools.nix`). Add an
`.envrc` next to the flake and allow it once:

```bash
echo 'use flake' > .envrc
direnv allow
```

The environment now loads whenever you `cd` into the project and unloads when
you leave. nix-direnv caches it, so it's instant after the first load.

---

## Editor integration

### VS Code

The **direnv** extension (`mkhl.direnv`) is installed, so a project with an
`.envrc` gives VS Code the project's tools and LSPs automatically. Without
one, start VS Code from inside a dev shell (`c-dev`, then `code .`).

### Emacs / Neovim

Start them from inside a dev shell (or a direnv project) and the LSP servers
from that shell are on `PATH`:

```bash
rs-dev
nvim src/main.rs # rust-analyzer comes from the dev shell
```

---

## Adding tools to a shell

Add the package to the `packages` list of the relevant file in
`home-manager/utilities/devshells/`, then run `nsr`.

---

## Updating

Dev shell packages are pinned by `flake.lock` and only change when you update
the flake:

```bash
update # nix flake update && home-manager switch
```

---

## Troubleshooting

**`c-dev: command not found`** — the wrappers come from home-manager; run
`nsr` (or open a new shell after the first switch).

**First start is slow** — the first run downloads the shell's packages. After
that they're in the Nix store and it starts almost instantly (until the next
`cleanup` garbage-collects them).

**`command not found: <tool>`** — you're outside the dev shell; run `c-dev` /
`py-dev` / `rs-dev` / `ml-dev` first.
