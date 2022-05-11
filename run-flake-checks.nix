# Runs Nix flake checks individually with group markers for GitHub Actions.
# Invoke with `nix-shell run-flake-checks.nix --argstr branch "8.1"`
{
  # PHP attribute to run checks for. `null` for all checks.
  branch ? null,
}:

let
  self = import ./.;

  pkgs = self.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
  inherit (self.inputs.nixpkgs) lib;

  checks = self.outputs.checks.${builtins.currentSystem};

  phpName =
    assert lib.assertMsg (builtins.match "[0-9]+.[0-9]+" branch != null) "Branch name “${builtins.toString branch}” does not match a version number.";

    "php${lib.versions.major branch}${lib.versions.minor branch}";

  relevantChecks =
    if branch == null
    then checks
    else lib.filterAttrs (key: value: lib.hasPrefix "${phpName}-" key) checks;
in

assert lib.assertMsg (relevantChecks != { }) "No checks found for branch “${builtins.toString branch}”.";

pkgs.stdenv.mkDerivation {
  name = "run-flake-checks";

  buildCommand = ''
    echo 'Please run `nix-shell run-flake-checks.nix`, `nix-build` cannot be used.' > /dev/stderr
    exit 1
  '';

  shellHook =
    ''
      set -o errexit
    ''
    + builtins.concatStringsSep
      "\n"
      (
        lib.mapAttrsToList
          (
            name:
            value:

            let
              description =
                lib.optionalString (branch == null) "PHP ${value.phpBranch} – "
                + value.description;
            in
            ''
              echo "::group::${description}"
              echo Run nix-build -A outputs.checks.${builtins.currentSystem}.${name}
              nix-build --no-out-link -A outputs.checks.${builtins.currentSystem}.${name}
              echo "::endgroup::"
            ''
          )
          relevantChecks
      )
    + ''
      exit 0
    ''
    ;
}
