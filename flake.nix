{
  description = "Strata — the best file manager on Linux (exact upstream packaging)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        strata = pkgs.rustPlatform.buildRustPackage rec {
          pname = "strata";
          version = "1.0.0";

          src = pkgs.fetchFromGitHub {
            owner = "lgse";
            repo = "strata";
            rev = "v${version}";
            hash = "sha256-dFNsFCnkeZs0VwmYRyu+6Jh8XxJzv+agUlP70Fdxa5Q=";
          };

          cargoLock = {
            lockFile = "${src}/Cargo.lock";
          };

          nativeBuildInputs = with pkgs; [
            pkg-config
            rustPlatform.bindgenHook
            wrapGAppsHook4
            desktop-file-utils
            shared-mime-info
            glib
          ];

          buildInputs = with pkgs; [
            gtk4
            gtksourceview5
            glib
            cairo
            pango
            gdk-pixbuf
            poppler
            gst_all_1.gstreamer
            gst_all_1.gst-plugins-base
            gst_all_1.gst-plugins-good
            gst_all_1.gst-libav
            ffmpeg
            fontconfig
            freetype
            bubblewrap
            libseccomp
            openssl
            zlib
          ];

          env.STRATA_TRUSTED_COMMAND_PATH = pkgs.lib.makeBinPath (with pkgs; [
            bubblewrap
            ffmpeg
            ffmpegthumbnailer
            gvfs
          ]);

          doCheck = false;

          postInstall = ''
            install -Dm644 data/io.github.lgse.Strata.desktop \
              $out/share/applications/io.github.lgse.Strata.desktop

            install -Dm644 data/icons/scalable/apps/io.github.lgse.Strata.svg \
              $out/share/icons/hicolor/scalable/apps/io.github.lgse.Strata.svg

            install -Dm644 data/io.github.lgse.Strata.FileManager1.service \
              $out/share/strata/io.github.lgse.Strata.FileManager1.service

            mkdir -p $out/share/strata
            cat > $out/share/strata/install-source.toml <<EOF
            manager = "nix"
            package = "strata"
            channel = "stable"
            EOF

            substituteInPlace $out/share/strata/io.github.lgse.Strata.FileManager1.service \
              --replace-fail "/usr/bin/strata" "$out/bin/strata"
          '';

          meta = with pkgs.lib; {
            description = "A fast, keyboard-first file manager for modern Linux desktops";
            homepage = "https://github.com/lgse/strata";
            changelog = "https://github.com/lgse/strata/releases/tag/v${version}";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.linux;
            mainProgram = "strata";
          };
        };
      in
      {
        packages.default = strata;
        packages.strata = strata;

        apps.default = flake-utils.lib.mkApp {
          drv = strata;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ strata ];
          packages = with pkgs; [
            rust-analyzer
            cargo-watch
            clippy
            rustfmt
            cargo-deny
          ];
        };
      }
    ) // {
      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let cfg = config.programs.strata; in
        {
          options.programs.strata = {
            enable = mkEnableOption "Strata file manager (exact upstream packaging)";
            package = mkPackageOption pkgs "strata" {
              default = self.packages.${pkgs.system}.default;
            };
          };

          config = mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
          };
        };

      overlays.default = final: prev: {
        strata = self.packages.${prev.system}.default;
      };
    };
}
