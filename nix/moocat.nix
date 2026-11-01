# moocat, the MOO client, built from its GitHub repo at a pinned commit with
# the repo's own Nix package (packaging/nix/moocat.nix) and the tinyjs here.
# To update: push moocat, then set rev to the new commit and sha256 to
#   nix-prefetch-url --unpack https://github.com/jwmarsden/moocat/archive/<rev>.tar.gz
{ callPackage, tinyjs }:

let
  rev = "3b46a911d36b3b552ed7a454112689a0956aef75";
  src = builtins.fetchTarball {
    url = "https://github.com/jwmarsden/moocat/archive/${rev}.tar.gz";
    sha256 = "0cv6c42awccb5ys1gh6ngygjkx4x1r3nvky59fhwns8m6qsm9sk3";
  };
in
callPackage "${src}/packaging/nix/moocat.nix" { inherit tinyjs; }
