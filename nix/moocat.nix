# moocat, the MOO client, built from its GitHub repo at a pinned commit with
# the repo's own Nix package (packaging/nix/moocat.nix) and the tinyjs here.
# To update: push moocat, then set rev to the new commit and sha256 to
#   nix-prefetch-url --unpack https://github.com/jwmarsden/moocat/archive/<rev>.tar.gz
{ callPackage, tinyjs }:

let
  rev = "556935157c9e8c9f508ce64f37b83572987b5d17";
  src = builtins.fetchTarball {
    url = "https://github.com/jwmarsden/moocat/archive/${rev}.tar.gz";
    sha256 = "0ry8pp6blpb6bvjmwi3vrnd1qc3nr68hzqc44798ab4d254b8g5h";
  };
in
callPackage "${src}/packaging/nix/moocat.nix" { inherit tinyjs; }
