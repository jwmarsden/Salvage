# tinyjs, small desktop apps in JavaScript: a txiki.js backend (bin/tjs) and a
# native WebKitGTK window (native/launcher-linux). Not in nixpkgs; its
# installer drops prebuilt binaries in ~/.tinyjs, which NixOS can't run, so
# this patches the same release tarball. The CLI finds its files next to
# cli.js, so the whole tree goes to $out/share/tinyjs.
#
# `tinyjs build` copies the launcher into the app's dist/, still pointing at
# these store libraries: fine on this machine, not portable.
{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, libffi, webkitgtk_4_1
, libsoup_3, gtk3, glib, pango, cairo, gdk-pixbuf, libayatana-appindicator
, xorg, pipewire, glib-networking, gsettings-desktop-schemas }:

stdenv.mkDerivation rec {
  pname = "tinyjs";
  version = "0.68.0";

  src = fetchurl {
    url = "https://github.com/tarwin/tinyjsapp/releases/download/v${version}/tinyjs-linux-x86_64.tar.gz";
    hash = "sha256-pYbm9dmk4acS8GMEOLLWRPYOaHOuFhnAQB1qnk+AMy4=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [
    libffi stdenv.cc.cc.lib webkitgtk_4_1 libsoup_3 gtk3 glib pango cairo
    gdk-pixbuf libayatana-appindicator xorg.libX11 xorg.libXtst pipewire
  ];

  dontBuild = true;
  # strip would change the binaries cli.js checks against runtime/txiki.sha256
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/tinyjs $out/bin
    cp -r . $out/share/tinyjs/
    rm $out/share/tinyjs/install
    # TLS for the webview (https pages) comes from glib-networking's GIO module.
    # The GSettings schemas matter on Wayland: GTK reads the font DPI from
    # org.gnome.desktop.interface there, and without the schema it's -1, which
    # WebKitGTK 2.54 turns into a devicePixelRatio of -1/48 (page laid out at
    # half size, spilling off the window). wrapGAppsHook would add the same.
    makeWrapper $out/share/tinyjs/bin/tjs $out/bin/tinyjs \
      --add-flags "run $out/share/tinyjs/cli.js" \
      --prefix XDG_DATA_DIRS : ${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name} \
      --prefix GIO_EXTRA_MODULES : ${glib-networking}/lib/gio/modules
    runHook postInstall
  '';

  meta = {
    description = "Desktop apps in JavaScript on txiki.js and the system webview";
    homepage = "https://tinyjs.app/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
