{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    naersk.inputs.nixpkgs.follows = "nixpkgs";
    naersk.url = "github:nmattia/naersk";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-treesitter = {
      url = "github:ratson/nix-treesitter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import inputs.nixpkgs { inherit system; };
        naersk-lib = inputs.naersk.lib."${system}";
        darwinInputs = if pkgs.stdenv.isDarwin then [ pkgs.xcbuild ] else [ ];
        grammars = inputs.nix-treesitter.packages.${system};

        updateVendor = pkgs.writeShellScriptBin "update-vendor" ''
          set -euo pipefail

          rm -rf vendor
          mkdir vendor

          set -x
          ln -s ${grammars.tree-sitter-c.src} vendor/tree-sitter-c
          ln -s ${grammars.tree-sitter-cpp.src} vendor/tree-sitter-cpp
          ln -s ${grammars.tree-sitter-elixir.src} vendor/tree-sitter-elixir
          ln -s ${grammars.tree-sitter-elm.src} vendor/tree-sitter-elm
          ln -s ${grammars.tree-sitter-go.src} vendor/tree-sitter-go
          ln -s ${grammars.tree-sitter-haskell.src} vendor/tree-sitter-haskell
          ln -s ${grammars.tree-sitter-java.src} vendor/tree-sitter-java
          ln -s ${grammars.tree-sitter-javascript.src} vendor/tree-sitter-javascript
          ln -s ${grammars.tree-sitter-markdown.src} vendor/tree-sitter-markdown
          ln -s ${grammars.tree-sitter-nix.src} vendor/tree-sitter-nix
          ln -s ${grammars.tree-sitter-php.src} vendor/tree-sitter-php
          ln -s ${grammars.tree-sitter-python.src} vendor/tree-sitter-python
          ln -s ${grammars.tree-sitter-ruby.src} vendor/tree-sitter-ruby
          ln -s ${grammars.tree-sitter-rust.src} vendor/tree-sitter-rust
          ln -s ${grammars.tree-sitter-scss.src} vendor/tree-sitter-scss
          ln -s ${grammars.tree-sitter-typescript.src} vendor/tree-sitter-typescript
          ln -s ${grammars.tree-sitter-cuda.src} vendor/tree-sitter-cuda
          ln -s ${grammars.tree-sitter-powershell.src} vendor/tree-sitter-powershell
        '';
      in rec {
        # `nix build`
        packages.tree-grepper = naersk-lib.buildPackage {
          root = ./.;
          buildInputs = [ pkgs.libiconv pkgs.rustPackages.clippy ]
            ++ darwinInputs;

          preBuildPhases = [ "vendorPhase" ];
          vendorPhase = "${updateVendor}/bin/update-vendor";

          doCheck = true;
          checkPhase = ''
            cargo test
            cargo clippy -- --deny warnings
          '';
        };
        defaultPackage = packages.tree-grepper;
        overlay = final: prev: { tree-grepper = packages.tree-grepper; };

        # `nix develop`
        devShell = pkgs.mkShell {
          nativeBuildInputs = with pkgs;
            [
              cargo
              cargo-edit
              # https://github.com/NixOS/nixpkgs/issues/146349
              # cargo-watch
              rustPackages.clippy
              rustc
              rustfmt
              rust-analyzer

              updateVendor

              # for some reason this seems to be required, especially on macOS
              libiconv
            ] ++ darwinInputs;
        };
      });
}
