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
        runtimeDeps = with pkgs; [ bun ripgrep ast-grep tmux ];

        bunPackages = import ./bun.nix {
          inherit (pkgs) fetchFromGitHub fetchgit fetchurl;
          copyPathToStore = path: pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = path;
          };
        };

        vendorDeps = pkgs.stdenvNoCC.mkDerivation {
          name = "${pname}-node-modules";
          nativeBuildInputs = [ pkgs.bun pkgs.nodejs ];
          src = ./.;

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall

            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            cp -r "$src" source
            chmod -R u+w source
            cd source
            cache_dir=.bun-cache
            mkdir -p "$cache_dir"
            ${pkgs.lib.concatStringsSep "\n" (
              builtins.map (name: ''
                tmpdir=$(mktemp -d)
                tar -xzf ${bunPackages.${name}} -C "$tmpdir"
                package_dir=$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d | head -n 1)
                pkg_name=$(node -p "require('$package_dir/package.json').name")
                pkg_version=$(node -p "require('$package_dir/package.json').version")
                mkdir -p "$cache_dir/$pkg_name@$pkg_version@@@1"
                cp -r "$package_dir/." "$cache_dir/$pkg_name@$pkg_version@@@1/"
                rm -rf "$tmpdir"
              '') (builtins.attrNames bunPackages)
            )}

            bun install --frozen-lockfile --cache-dir "$cache_dir" --offline

            mkdir -p $out
            cp -r node_modules $out/

            runHook postInstall
          '';
        };

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
            ln -s ${vendorDeps}/node_modules node_modules
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
            cp -r ${vendorDeps}/node_modules $out/lib/${pname}/

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
            bun2nix
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
