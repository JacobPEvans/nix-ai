# Nix quality checks - single source of truth for pre-commit and CI
{
  pkgs,
  src,
}:
{
  formatting =
    pkgs.runCommand "check-formatting"
      {
        nativeBuildInputs = [ pkgs.nixfmt-rfc-style ];
      }
      ''
        cp -r ${src} $TMPDIR/src
        chmod -R u+w $TMPDIR/src
        cd $TMPDIR/src
        ${pkgs.lib.getExe pkgs.treefmt} --fail-on-change --no-cache --formatters nixfmt .
        touch $out
      '';

  statix = pkgs.runCommand "check-statix" { } ''
    cd ${src}
    ${pkgs.lib.getExe pkgs.statix} check .
    touch $out
  '';

  deadnix = pkgs.runCommand "check-deadnix" { } ''
    cd ${src}
    ${pkgs.lib.getExe pkgs.deadnix} -L --fail .
    touch $out
  '';
}
