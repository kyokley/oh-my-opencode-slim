{
  description = "Pure Nix package for oh-my-opencode-slim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        pname = "oh-my-opencode-slim";
        version = "0.8.0";

        runtimeDeps = with pkgs; [
          bun
          ripgrep
          ast-grep
          tmux
        ];

        pkg = pkgs.stdenv.mkDerivation {
          inherit pname version;
          src = ./.;

          nativeBuildInputs = with pkgs; [
            bun
            nodejs
            typescript
            makeWrapper
          ];

          buildPhase = ''
            runHook preBuild
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            bun install --frozen-lockfile
            bun run build
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/lib/${pname}
            cp -r dist $out/lib/${pname}/
            mkdir -p $out/lib/${pname}/src
            cp -r src/skills $out/lib/${pname}/src/
            cp package.json README.md LICENSE $out/lib/${pname}/

            mkdir -p $out/bin
            makeWrapper ${pkgs.bun}/bin/bun $out/bin/${pname} \
              --add-flags "$out/lib/${pname}/dist/cli/index.js" \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps} \
              --set OH_MY_OPENCODE_SLIM_PURE 1

            runHook postInstall
          '';
        };
      in {
        packages.default = pkg;
        packages.${pname} = pkg;

        apps.default = {
          type = "app";
          program = "${pkg}/bin/${pname}";
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            bun
            nodejs
            typescript
            biome
            ripgrep
            ast-grep
            tmux
          ];
        };

        checks.build = pkg;
      });
}
