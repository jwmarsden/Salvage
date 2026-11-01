# moocat, the MOO client, built from its GitHub repo at a pinned commit with
# the repo's own Nix package (packaging/nix/moocat.nix) and the tinyjs here.
# To update: push moocat, then set rev to the new commit and sha256 to
#   nix-prefetch-url --unpack https://github.com/jwmarsden/moocat/archive/<rev>.tar.gz
{ callPackage, tinyjs }:

let
  rev = "7dae43b77ffd2a51ec3d07658847f4d5445adc56";
  src = builtins.fetchTarball {
    url = "https://github.com/jwmarsden/moocat/archive/${rev}.tar.gz";
    sha256 = "16pq8v3hw2xb3564kdxsbbkii1gvqzq88ad4rrq4d2izq0060fy8";
  };
in
callPackage "${src}/packaging/nix/moocat.nix" { inherit tinyjs; }
