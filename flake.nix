{
  description = "qmk";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # gcc-arm-embedded-14.3.rel1 not available anymore on x86_64-darwin\
    # https://github.com/NixOS/nixpkgs/pull/428874
    qmk117.url = "github:nixos/nixpkgs/3d1f29646e4b57ed468d60f9d286cde23a8d1707";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (
      system: let
        compile = pkgs.writeShellApplication {
          name = "compile";
          text = ''
            echo "Compiling sofle pd"
            qmk compile -kb keebart/sofle_choc_pro -km pd --compiledb
          '';
        };

        flash = pkgs.writeShellApplication {
          name = "flash";
          text = ''
            echo "Compiling sofle pd"
            qmk flash -kb keebart/sofle_choc_pro -km pd
          '';
        };

        pkgs = nixpkgs.legacyPackages.${system};

        qmk =
          if system == flake-utils.lib.system.x86_64-darwin
          then inputs.qmk117.legacyPackages.${system}.qmk
          else pkgs.qmk;

        qmkPackages = [
          pkgs.python3
          pkgs.dos2unix
          pkgs.pkgsCross.avr.buildPackages.gcc
          qmk

          compile
          flash
        ];
      in {
        devShells.default = pkgs.mkShell {
          packages = qmkPackages;

          shellHook = ''
            set -e

            # XDG defaults
            : "''${XDG_STATE_HOME:=$HOME/.local/state}"

            QMK_STATE_DIR="$XDG_STATE_HOME/qmk"
            QMK_HOME="$QMK_STATE_DIR/qmk_firmware"
            CONFIG_MARKER="$QMK_STATE_DIR/.configured"

            mkdir -p "$QMK_STATE_DIR"

            if [ ! -d "$QMK_HOME/.git" ]; then
              echo "Cloning QMK firmware into $QMK_HOME"
              git clone https://github.com/qmk/qmk_firmware.git "$QMK_HOME"
            fi

            export QMK_HOME

            if [ ! -f "$CONFIG_MARKER" ]; then
              echo "Running initial QMK setup"
              qmk setup -H "$QMK_HOME" -y
              qmk config user.overlay_dir="$(realpath .)"
              touch "$CONFIG_MARKER"
            fi

            echo "QMK firmware: $QMK_HOME"
            echo "QMK userspace overlay: $(realpath .)"
          '';
        };
      }
    );
}
