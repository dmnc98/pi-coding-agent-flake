{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.pi;
in
{
  options.programs.pi = {
    enable = lib.mkEnableOption "Pi Coding Agent with declarative module sync";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./default.nix { };
      description = "The pi package derivation.";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "pi-lmstudio" ];
      description = ''
        npm packages (bare names, without the npm: prefix) to keep installed in
        pi. Adding an entry runs `pi install npm:<name>` on the next rebuild;
        removing one runs `pi remove npm:<name>`.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    let
      syncTool = pkgs.writeShellApplication {
        name = "pi-packages-sync";
        runtimeInputs = [
          cfg.package
          pkgs.jq
        ];
        text = ''
          LIST_FILE="$HOME/.config/pi/packages.json"

          if [ -f "$LIST_FILE" ]; then
            mapfile -t declared < <(jq -r '.[]' "$LIST_FILE")
          else
            declared=()
          fi

          # Source of truth for what's installed is `pi list`. Extract any
          # `npm:<name>` tokens from its output and strip the prefix.
          mapfile -t installed < <(
            pi list 2>/dev/null \
              | grep -oE 'npm:[^[:space:]]+' \
              | sed 's/^npm://' \
              | sort -u \
              || true
          )

          for pkg in "''${declared[@]:-}"; do
            [ -z "$pkg" ] && continue
            if ! printf '%s\n' "''${installed[@]:-}" | grep -qFx "$pkg"; then
              echo "[pi-packages-sync] installing npm:$pkg"
              pi install "npm:$pkg"
            fi
          done

          for pkg in "''${installed[@]:-}"; do
            [ -z "$pkg" ] && continue
            if ! printf '%s\n' "''${declared[@]:-}" | grep -qFx "$pkg"; then
              echo "[pi-packages-sync] removing npm:$pkg"
              pi remove "npm:$pkg"
            fi
          done
        '';
      };
    in
    {
      home.packages = [
        cfg.package
        syncTool
      ];

      xdg.configFile."pi/packages.json".text = builtins.toJSON cfg.packages;

      home.activation.piPackagesSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${syncTool}/bin/pi-packages-sync || true
      '';
    }
  );
}
