# AGENTS.md

Guidance for AI agents working in this repository.

## What this project is

**tree-grepper** is a CLI tool that works like `grep` but uses [Tree-sitter](https://tree-sitter.github.io/) to query code by AST structure rather than by text pattern. Users write Tree-sitter S-expression queries against source files; the tool prints matching nodes with file/line/column info, optionally as JSON.

The repo is marked unmaintained by its original author but the code works fine and contributions are welcome.

## Build

The canonical build path is Nix:

```
nix build
```

This runs `cargo build`, `cargo test`, and `cargo clippy -- --deny warnings`.

For development without Nix, first populate the vendor directory (requires a Nix shell), then use cargo directly:

```
nix develop        # enter dev shell
update-vendor      # populate vendor/ symlinks from nix-treesitter grammar sources
cargo build
cargo test
cargo clippy -- --deny warnings
```

`vendor/` is `.gitignore`d and must be regenerated whenever grammar sources change. It is populated automatically during `nix build` via the `vendorPhase` in `flake.nix`.

## Test

```
cargo test
```

Tests use [trycmd](https://docs.rs/trycmd): each `.trycmd` file in `tests/cmd/` is a markdown document with fenced shell blocks that define a command and its expected output. `README.md` is also a trycmd test file — the code blocks in it are executed as tests.

To update snapshot output after an intentional change run the tests with:

```
TRYCMD=overwrite cargo test
```

## Linting

Clippy is run with `--deny warnings` — zero warnings are allowed. Fix all clippy suggestions before considering a change complete.

## Source layout

```
src/
  main.rs             entry point: CLI dispatch, parallel file walk, output formatting
  cli.rs              clap argument parsing; produces Invocation enum
  language.rs         Language enum + Tree-sitter FFI bindings
  extractor.rs        query execution; produces ExtractedFile / ExtractedMatch
  extractor_chooser.rs maps file paths to the right Extractor via ignore::Types
  tree_view.rs        AST pretty-printer (used by --show-tree)
  files.rs            legacy file iterator (currently unused)
tests/
  cli_tests.rs        trycmd runner
  cmd/                *.trycmd snapshot files + hello-world.js fixture
build.rs              compiles vendor/ C grammar sources into static libs via cc crate
flake.nix             Nix build; defines updateVendor and devShell
```

## Supported languages

The `Language` enum in `src/language.rs` lists all supported languages. **The enum variants must stay in alphabetical order** — the `FromStr` impl relies on this for binary search.

Current languages: C, C++, CUDA, Elixir, Elm, Go, Haskell, Java, JavaScript, Markdown, Nix, PHP, PowerShell, Python, Ruby, Rust, Sass/SCSS, TypeScript.

## Adding a new language

1. Add a `flake = false` input for the grammar source repo in `flake.nix` **and** a corresponding `ln -s` line in the `updateVendor` script — or rely on the existing `nix-treesitter` input if the grammar is already there (access it as `grammars.tree-sitter-<name>.src`).
2. Add a new variant to the `Language` enum in `src/language.rs` in alphabetical order. Add the `extern "C"` declaration and the `language()` match arm.
3. Add compile steps for `parser.c` (and `scanner.c` if present) in `build.rs`.
4. Register the file type in `ExtractorChooser::from_extractors` in `src/extractor_chooser.rs`. Use `types_builder.add_def` for non-standard extensions; standard ones (rust, python, …) are already known to the `ignore` crate.
5. Add a trycmd test case to `tests/cmd/query.trycmd` exercising the new language.

## Key conventions

- **Query composition**: when a user passes multiple `-q lang query` pairs for the same language, the CLI concatenates them into a single Tree-sitter query string before parsing. Queries are separated by whitespace in the combined string.
- **Underscore captures**: capture names that start with `_` are silently filtered from output. They can still be used inside a query as structural constraints.
- **1-indexed output**: `ExtractedMatch` serialises row/column as 1-indexed even though Tree-sitter uses 0-indexed internally.
- **Custom file types**: CUDA (`.cu`, `.cuh`, `.hpp`, inherits cpp) and PowerShell (`.ps1`) are registered with custom `add_def` calls because the `ignore` crate does not know them.
- **Clippy is hard-denied**: treat every clippy lint as a compile error when making changes.
- **Vendor symlinks**: `vendor/` contains symlinks to Nix store paths, not copies of files. Do not edit files under `vendor/`.

## Grammar sources

Grammar C sources come from [ratson/nix-treesitter](https://github.com/ratson/nix-treesitter) via the `nix-treesitter` flake input. Each grammar is accessed as `inputs.nix-treesitter.packages.${system}.tree-sitter-<name>.src` — the `.src` attribute points to the full grammar repository root, which is what `build.rs` expects (some grammars like PHP and TypeScript have their parser in a subdirectory of the repo).
