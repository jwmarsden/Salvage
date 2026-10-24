# tkMOO-light 0.3.32, Andrew Wilson's Tcl/Tk MOO client: its MCP 2.1 local
# editor (simpleedit) opens @edit'ed verbs, properties and notes in a pop-up
# editor window and sends them back to the MOO. Not in nixpkgs.
#
# The upstream build only writes a `#!wish` line and the plugin directory in
# front of source.tcl; the plugins are copied alongside. Its settings live in
# ~/.tkMOO-lite (worlds, preferences), created on first run.
#
# Licence: free for private, academic and non-commercial use only.
{ lib, stdenvNoCC, fetchurl, tk, makeDesktopItem, copyDesktopItems }:

stdenvNoCC.mkDerivation rec {
  pname = "tkmoo-light";
  version = "0.3.32";

  src = fetchurl {
    urls = [
      "http://www.awns.com/tkMOO-light/Source/tkMOO-light-${version}.tar.gz"
      # FreeBSD keeps a copy of every port's source (same file, same hash)
      "http://distcache.freebsd.org/ports-distfiles/tkMOO-light-${version}.tar.gz"
    ];
    hash = "sha256-jl9eLtdWWHvz9Gh8V03zERv3fv8VPxf+GADvmGYsS1s=";
  };

  nativeBuildInputs = [ copyDesktopItems ];

  buildPhase = ''
    runHook preBuild
    {
      echo "#!${tk}/bin/wish${lib.versions.majorMinor tk.version}"
      echo "set tkmooLibrary $out/share/tkmoo-light"
      cat source.tcl
    } > tkmoo
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 tkmoo $out/bin/tkmoo
    mkdir -p $out/share/tkmoo-light
    cp -r plugins $out/share/tkmoo-light/
    install -Dm644 -t $out/share/doc/tkmoo-light README LICENCE dot.tkmoolightrc
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "tkmoo-light";
      desktopName = "tkMOO-light";
      comment = "MOO client with a pop-up local editor";
      exec = "tkmoo";
      icon = "internet-chat";
      categories = [ "Network" "Chat" "Game" ];
    })
  ];

  meta = {
    description = "Tcl/Tk MOO client with MCP 2.1 and a local editor";
    homepage = "http://www.awns.com/tkMOO-light/";
    license = lib.licenses.unfree; # private, academic and non-commercial use
    mainProgram = "tkmoo";
    platforms = lib.platforms.unix;
  };
}
