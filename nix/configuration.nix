# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

let
  # Tracks master to match the unstable nixos channel.
  home-manager = builtins.fetchTarball https://github.com/nix-community/home-manager/archive/master.tar.gz;

  # `pycharm-<name>` (plus a launcher entry) opens a flake project in PyCharm
  # inside its `nix develop` shell, so compiled pip wheels find libstdc++ etc.
  # Add a line to pycharmProjects for each new project.
  pycharmProject = name: title: dir: [
    (pkgs.writeShellScriptBin "pycharm-${name}" ''
      cd ${lib.escapeShellArg dir} || exit 1
      log="''${XDG_RUNTIME_DIR:-/tmp}/pycharm-${name}.log"
      echo "PyCharm (${title}) starting; log: $log"
      setsid -f nix develop --command pycharm . "$@" >"$log" 2>&1 </dev/null
    '')
    (pkgs.makeDesktopItem {
      name = "pycharm-${name}";
      desktopName = "PyCharm (${title})";
      exec = "pycharm-${name}";
      icon = "pycharm";
      startupWMClass = "jetbrains-pycharm";
      categories = [ "Development" "IDE" ];
    })
  ];
  pycharmProjects = lib.concatLists [
    (pycharmProject "amischatter" "AMISChatter" "/home/jwm/Source/AMISChatter")
  ];

  # Games live in their own menu ("Games" in Super+D, or Super+Shift+G)
  # rather than the main launcher list. Add a line here per new game:
  # desktop-file id, label, icon, package holding the .desktop file.
  games = [
    { id = "org.gnome.Mines"; name = "Mines"; icon = "org.gnome.Mines"; pkg = pkgs.gnome-mines; }
    { id = "org.gnome.Sudoku"; name = "Sudoku"; icon = "org.gnome.Sudoku"; pkg = pkgs.gnome-sudoku; }
    { id = "shattered-pixel-dungeon"; name = "Shattered Pixel Dungeon"; icon = "shattered-pixel-dungeon"; pkg = pkgs.shattered-pixel-dungeon; }
    { id = "unciv"; name = "Unciv"; icon = "unciv"; pkg = pkgs.unciv; }
    { id = "org.wesnoth.Wesnoth"; name = "Battle for Wesnoth"; icon = "wesnoth-icon"; pkg = pkgs.wesnoth; }
    { id = "openttd"; name = "OpenTTD"; icon = "openttd"; pkg = pkgs.openttd; }
    { id = "steam"; name = "Steam"; icon = "steam"; pkg = pkgs.steam-unwrapped; }
  ];
  gamesMenu = pkgs.writeShellScriptBin "games-menu" ''
    ids=(${lib.concatMapStringsSep " " (g: g.id) games})
    i=$(printf '%s\0icon\x1f%s\n' \
      ${lib.concatMapStringsSep " " (g: "${lib.escapeShellArg g.name} ${lib.escapeShellArg g.icon}") games} \
      | ${pkgs.fuzzel}/bin/fuzzel --dmenu --index --prompt 'games> ') || exit 0
    exec ${pkgs.gtk3}/bin/gtk-launch "''${ids[$i]}"
  '';
in
{
  imports =
    [ # Include the results of the hardware scan.
      /etc/nixos/hardware-configuration.nix
      (import "${home-manager}/nixos")
      ./macbook12-audio.nix
      ./power.nix
      ./boot-splash.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "salvage"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  # DNS: Cloudflare, with Google as fallback, encrypted (DNS-over-TLS) when the
  # server supports it. "~." makes these win over the router's DHCP DNS.
  services.resolved.enable = true;
  services.resolved.settings.Resolve = {
    DNS = [
      "1.1.1.1#cloudflare-dns.com"
      "1.0.0.1#cloudflare-dns.com"
      "2606:4700:4700::1111#cloudflare-dns.com"
      "2606:4700:4700::1001#cloudflare-dns.com"
    ];
    FallbackDNS = [ "8.8.8.8#dns.google" "8.8.4.4#dns.google" ];
    Domains = [ "~." ];
    DNSOverTLS = "opportunistic";
  };
  # Tray icon (waybar) for switching Wi-Fi and adding networks; the Wi-Fi
  # password is saved in the keyring. Started with the sway session.
  programs.nm-applet.enable = true;

  programs.sway.enable = true;

  # Cooling/power: fanless MacBook, so throttle smartly and allow power-saver mode
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = true;

  # Bluetooth; pair devices from the blueman tray icon (home-manager below).
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # mDNS: find printers/devices on the LAN and resolve *.local names;
  # this machine is reachable as salvage.local.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true; # UDP 5353
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # Printing (CUPS). Network printers like the Brother MFC-L3750CDW are
  # found via Avahi and use driverless IPP Everywhere, so no drivers needed.
  services.printing.enable = true;

  # Compressed swap in RAM for this 8 GB machine; used before the disk swap.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Docker. Not started at boot to save battery: the socket starts the
  # daemon on the first `docker` command. Includes `docker compose`.
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
    autoPrune.enable = true; # weekly cleanup of unused images/containers
  };

  # NordVPN (official client + daemon). One-time: `nordvpn login`, then
  # `nordvpn c` / `nordvpn d`, or the waybar VPN icon / "NordVPN" app.
  services.nordvpn.enable = true;
  networking.firewall.checkReversePath = "loose"; # needed for the VPN tunnel

  # Set your time zone.
  time.timeZone = "Australia/Adelaide";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_AU.UTF-8";

  # Login screen that launches sway.
  services.greetd = {
    enable = true;
    settings.default_session = {
      # Colours come from the Tokyo Night console palette (boot-splash.nix).
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks"
        + " --window-padding 2 --container-padding 2"
        + " --theme 'border=blue;title=blue;greet=cyan;text=white;time=cyan;container=black;prompt=magenta;input=white;action=blue;button=yellow'"
        + " --cmd sway";
      user = "greeter";
    };
  };

  # Keymap (also picked up by sway's default xkb settings)
  services.xserver.xkb = {
    layout = "au";
    variant = "";
  };

  security.sudo.wheelNeedsPassword = false;

  # Keyring (Secret Service) for saved logins: gh, VS Code, Chrome, etc.
  # Unlocked automatically with your password at the greetd login.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;
  programs.seahorse.enable = true; # GUI to view/manage saved passwords

  # Audio
  security.rtkit.enable = true;
  hardware.alsa.enablePersistence = true; # keep Master at 100% (speakers use soft volume)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  # Keep the laptop speakers (priority 1009) as the default output when
  # docked: USB outputs like the BT600 headset dongle drop below them.
  # They can still be picked by hand in pavucontrol.
  services.pipewire.wireplumber.extraConfig."52-prefer-builtin-output" = {
    "monitor.alsa.rules" = [{
      matches = [{ "node.name" = "~alsa_output.usb-.*"; }];
      actions.update-props = {
        "priority.session" = 900;
        "priority.driver" = 900;
      };
    }];
  };

  # Firmware updates
  services.fwupd.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.jwm = {
    isNormalUser = true;
    # description = "JWM";
    extraGroups = [ "networkmanager" "wheel" "docker" "nordvpn" ];
    shell = pkgs.zsh;
    # packages = with pkgs; [];
  };

  # Needed system-wide for zsh as a login shell (completions, /etc/shells).
  programs.zsh.enable = true;

  # Use the system nixpkgs (and its allowUnfree) for home-manager.
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.jwm = { pkgs, ... }: {
    # The state version is required and should stay at the version you
    # originally installed.
    home.stateVersion = "25.11";
    home.packages = with pkgs; [
      bat
      dbeaver-bin # database client (Community Edition)
      # Bitwarden: desktop app, plus rbw + rofi-rbw for Super+P (fuzzel
      # picker that types/copies logins into any app). One-time setup:
      # `rbw config set email <you>` then `rbw login`.
      bitwarden-desktop
      rbw
      rofi-rbw-wayland
      pinentry-gnome3 # master-password prompt for rbw
      drawio # draw.io diagram editor
      flameshot
      fuzzel
      git-lfs
      google-chrome
      hunspellDicts.en_AU # spell checking for LibreOffice
      kdePackages.okular # PDF annotation/forms/signing (zathura is the default viewer)
      jetbrains.idea
      jetbrains.pycharm
      jetbrains.rust-rover
      libreoffice-fresh
      maestral # open-source Dropbox client (CLI: `maestral status`, etc.)
      maestral-gui
      obsidian
      slack
      python3
      # Rust: rustup manages rustc/cargo toolchains; gcc provides the linker
      rustup
      gcc
      vscode
      vlc # video/audio player
      qbittorrent # torrents (bound to the nordlynx VPN interface)
      podman-desktop # container GUI (uses the Docker socket)
      lazydocker # container TUI
      # Spatial / GIS
      qgis # desktop GIS
      gdal # ogr2ogr, gdalinfo, gdal_translate...
      proj # coordinate transforms (cs2cs, projinfo)
      tippecanoe # vector tiles from GeoJSON
      duckdb # SQL on files; `INSTALL spatial; LOAD spatial;`
      postgresql_17 # psql client (+ shp2pgsql via the Docker image)
      gamesMenu
      # Games: casual and strategy
      gnome-mines
      gnome-sudoku
      shattered-pixel-dungeon # roguelike
      unciv # Civilization V-style 4X
      wesnoth # turn-based fantasy strategy
      openttd # transport tycoon
    ];
    programs.bash.enable = true;
    # Login shell: highlights commands as you type (green = valid, red = unknown)
    # and suggests from history in grey (press → to accept).
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      syntaxHighlighting.enable = true;
      autosuggestion.enable = true;
      historySubstringSearch.enable = true; # ↑/↓ search history for what's typed
      history = {
        size = 50000;
        save = 50000;
        ignoreDups = true;
        share = true;
      };
    };
    programs.git = {
      enable = true;
      settings = {
        user.name = "J.W.Marsden";
        user.email = "j.w.marsden@gmail.com";
        # Git LFS filters, written exactly as `git lfs install` would, since it
        # cannot write to this read-only config and complains about store paths.
        filter.lfs = {
          clean = "git-lfs clean -- %f";
          smudge = "git-lfs smudge -- %f";
          process = "git-lfs filter-process";
          required = true;
        };
      };
    };
    # Slightly see-through terminals so the wallpaper shows
    # (foot = Super+Enter, alacritty = bar launcher).
    # Both use the Tokyo Night palette (same blues as waybar and fuzzel).
    programs.foot = {
      enable = true;
      # Victor Mono's italic is a cursive script; use its plain slanted
      # (oblique) style for italic text instead.
      settings.main = {
        font-italic = "VictorMono Nerd Font Mono:style=Oblique";
        font-bold-italic = "VictorMono Nerd Font Mono:style=Bold Oblique";
      };
      settings.colors-dark = {
        alpha = 0.85;
        background = "1a1b26";
        foreground = "c0caf5";
        selection-background = "33467c";
        selection-foreground = "c0caf5";
        regular0 = "15161e"; regular1 = "f7768e"; regular2 = "9ece6a"; regular3 = "e0af68";
        regular4 = "7aa2f7"; regular5 = "bb9af7"; regular6 = "7dcfff"; regular7 = "a9b1d6";
        bright0 = "414868"; bright1 = "f7768e"; bright2 = "9ece6a"; bright3 = "e0af68";
        bright4 = "7aa2f7"; bright5 = "bb9af7"; bright6 = "7dcfff"; bright7 = "c0caf5";
      };
    };
    programs.alacritty = {
      enable = true;
      settings.window.opacity = 0.85;
      settings.colors = {
        primary = { background = "#1a1b26"; foreground = "#c0caf5"; };
        selection = { background = "#33467c"; text = "#c0caf5"; };
        normal = {
          black = "#15161e"; red = "#f7768e"; green = "#9ece6a"; yellow = "#e0af68";
          blue = "#7aa2f7"; magenta = "#bb9af7"; cyan = "#7dcfff"; white = "#a9b1d6";
        };
        bright = {
          black = "#414868"; red = "#f7768e"; green = "#9ece6a"; yellow = "#e0af68";
          blue = "#7aa2f7"; magenta = "#bb9af7"; cyan = "#7dcfff"; white = "#c0caf5";
        };
      };
    };
    # Super+D launcher: blue theme matching the waybar colours (RRGGBBAA).
    programs.fuzzel = {
      enable = true;
      settings = {
        colors = {
          background = "1a1b26f0";
          text = "c0caf5ff";
          prompt = "7aa2f7ff";
          input = "c0caf5ff";
          placeholder = "565f89ff";
          match = "7dcfffff";
          selection = "3d59a1ff";
          selection-text = "ffffffff";
          selection-match = "7dcfffff";
          border = "7aa2f7ff";
        };
        border = {
          width = 2;
          radius = 8;
        };
        # Same icons as GTK apps; also finds VS Code's icon, which only
        # ships in a 1024px size that the default (hicolor) lookup misses.
        main.icon-theme = "Papirus-Dark";
      };
    };
    # Dropbox: start the Maestral tray app with sway. It runs the sync daemon
    # and, on first launch, walks through linking the account.
    systemd.user.services.maestral-gui = {
      Unit = {
        Description = "Maestral Dropbox client";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.maestral-gui}/bin/maestral_qt";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "sway-session.target" ];
    };
    # Terminal file manager (Super+Y). Typing `y` in zsh opens it and leaves the
    # shell in whatever directory you quit from.
    programs.yazi = {
      enable = true;
      enableZshIntegration = true;
      settings.mgr.sort_dir_first = true;
      # Tokyo Night colours, matching foot/alacritty/waybar/fuzzel.
      flavors.tokyo-night = pkgs.fetchFromGitHub {
        owner = "BennyOe";
        repo = "tokyo-night.yazi";
        rev = "8e6296f14daff24151c736ebd0b9b6cd89b02b03";
        hash = "sha256-LArhRteD7OQRBguV1n13gb5jkl90sOxShkDzgEf3PA0=";
      };
      theme.flavor = { dark = "tokyo-night"; light = "tokyo-night"; };
    };
    # GitHub CLI. `gh auth login` once; it also acts as git's credential
    # helper, so pushes to github.com over HTTPS use that login.
    programs.gh = {
      enable = true;
      settings.git_protocol = "https";
    };
    # Launcher (Super+D) tidy-up: entries in ~/.local/share/applications
    # override the installed ones with the same file name. Apps stay
    # installed; this only changes what fuzzel lists and what it's called.
    xdg.dataFile =
      let
        hide = id: {
          name = "applications/${id}.desktop";
          value.text = "[Desktop Entry]\nType=Application\nName=${id}\nNoDisplay=true\n";
        };
        # Hide, but keep the original entry so its file types (MimeType)
        # still work, e.g. nvim for text files.
        hideKeep = id: pkg: {
          name = "applications/${id}.desktop";
          value.source = pkgs.runCommand "${id}.desktop" { } ''
            sed -e '/^NoDisplay=/d' \
                -e '0,/^\[Desktop Entry\]/s||[Desktop Entry]\nNoDisplay=true|' \
              ${pkg}/share/applications/${id}.desktop > $out
          '';
        };
        rename = id: pkg: newName: {
          name = "applications/${id}.desktop";
          value.source = pkgs.runCommand "${id}.desktop" { } ''
            sed '0,/^Name=/s|^Name=.*|Name=${newName}|' \
              ${pkg}/share/applications/${id}.desktop > $out
          '';
        };
      in
      builtins.listToAttrs (map hide [
        "footclient" "foot-server"
        "thunar-bulk-rename" "thunar-settings" "thunar-volman-settings"
        "nm-connection-editor" "nixos-manual"
        "org.flameshot.Flameshot" "Alacritty" "btop" "maestral" "blueman-adapters"
        "qt5ct" "qt6ct" # Qt theme settings (managed here)
      ] ++ [
        (hideKeep "nvim" config.programs.neovim.finalPackage)
        (hideKeep "base" pkgs.libreoffice-fresh)
        (hideKeep "math" pkgs.libreoffice-fresh)
        # Still open files/folders, just not listed (Super+Y runs yazi;
        # archives open from Thunar).
        (hideKeep "yazi" pkgs.yazi)
        (hideKeep "org.gnome.FileRoller" pkgs.file-roller)
        (rename "vlc" pkgs.vlc "VLC")
        (rename "dbeaver" pkgs.dbeaver-bin "DBeaver")
        (rename "drawio" pkgs.drawio "draw.io")
        (rename "thunar" pkgs.thunar "Files (Thunar)")
        (rename "nordvpn-gui" pkgs.nordvpn "NordVPN")
        # One "Games" entry opens the games menu; the games themselves are
        # hidden here but still launchable from it.
        {
          name = "applications/games-menu.desktop";
          value.text = "[Desktop Entry]\nType=Application\nName=Games\nIcon=applications-games\nExec=games-menu\nCategories=Game;\n";
        }
      ] ++ map (g: hideKeep g.id g.pkg) games);
    # Tokyo Night for all GTK apps (Thunar, pavucontrol, file dialogs, ...),
    # with Papirus icons in matching indigo folders.
    gtk = {
      enable = true;
      theme = {
        name = "Tokyonight-Dark";
        package = pkgs.tokyonight-gtk-theme;
      };
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme.override { color = "indigo"; };
      };
      # Interface font (menus, dialogs, Thunar); monospace is Victor Mono.
      font = {
        name = "IBM Plex Sans";
        size = 10;
        package = pkgs.ibm-plex;
      };
    };
    # Also tell GTK4/libadwaita apps and portals to prefer dark.
    dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

    # Qt apps (VLC, Okular, DBeaver dialogs...): Fusion style with a Tokyo
    # Night palette through qt5ct/qt6ct, Papirus icons, the same fonts as GTK.
    # Takes effect for apps started after logging in again.
    qt = {
      enable = true;
      platformTheme.name = "qtct";
    };
    xdg.configFile =
      let
        # Roles in qtct order: WindowText Button Light Midlight Dark Mid Text
        # BrightText ButtonText Base Window Shadow Highlight HighlightedText
        # Link LinkVisited AlternateBase NoRole ToolTipBase ToolTipText
        # PlaceholderText
        palette = active: disabled: lib.concatMapStringsSep ", " (c: "#ff${c}") [
          active "292e42" "3b4261" "2f3549" "16161e" "24283b" active
          "ffffff" active "16161e" "1a1b26" "000000" "7aa2f7" "1a1b26"
          "7aa2f7" "bb9af7" "1f2335" "1a1b26" "24283b" "c0caf5" disabled
        ];
        colors = pkgs.writeText "TokyoNight.conf" ''
          [ColorScheme]
          active_colors=${palette "c0caf5" "565f89"}
          inactive_colors=${palette "c0caf5" "565f89"}
          disabled_colors=${palette "565f89" "414868"}
        '';
        qtct = name: {
          "${name}/colors/TokyoNight.conf".source = colors;
          "${name}/${name}.conf".text = lib.generators.toINI { } {
            Appearance = {
              style = "Fusion";
              custom_palette = true;
              color_scheme_path = "/home/jwm/.config/${name}/colors/TokyoNight.conf";
              icon_theme = "Papirus-Dark";
              standard_dialogs = "default";
            };
            Fonts = {
              general = ''"IBM Plex Sans,10"'';
              fixed = ''"VictorMono Nerd Font Mono,10"'';
            };
          };
        };
      in
      qtct "qt5ct" // qtct "qt6ct";
    # Keyboard-driven PDF viewer (default for PDFs), Tokyo Night colours.
    # Copy selected text to the clipboard, and recolour pages with Ctrl+R.
    programs.zathura = {
      enable = true;
      options = {
        selection-clipboard = "clipboard";
        adjust-open = "width";
        font = "VictorMono Nerd Font Mono 10";
        default-bg = "#1a1b26";
        default-fg = "#c0caf5";
        statusbar-bg = "#24283b";
        statusbar-fg = "#c0caf5";
        inputbar-bg = "#1a1b26";
        inputbar-fg = "#c0caf5";
        notification-bg = "#1a1b26";
        notification-fg = "#c0caf5";
        notification-error-bg = "#1a1b26";
        notification-error-fg = "#f7768e";
        notification-warning-bg = "#1a1b26";
        notification-warning-fg = "#e0af68";
        highlight-color = "rgba(122,162,247,0.4)";
        highlight-active-color = "rgba(187,154,247,0.5)";
        completion-bg = "#24283b";
        completion-fg = "#c0caf5";
        completion-highlight-bg = "#3d59a1";
        completion-highlight-fg = "#ffffff";
        recolor-lightcolor = "#1a1b26";
        recolor-darkcolor = "#c0caf5";
        recolor-keephue = true;
      };
    };
    # Terminal git UI (Super+G, or `lazygit` inside a repo).
    programs.lazygit = {
      enable = true;
      settings.notARepository = "skip"; # outside a repo, show recent repos
    };

    # Per-project environments: a `.envrc` containing `use nix` (or
    # `use flake`) loads that project's shell.nix/flake on `cd`.
    # Run `direnv allow` once in each project.
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Image viewer (default for images in Thunar).
    programs.imv = {
      enable = true;
      settings.options.background = "1a1b26";
    };

    # Notifications, Tokyo Night colours. `makoctl dismiss -a` clears them.
    services.mako = {
      enable = true;
      settings = {
        font = "IBM Plex Sans 10";
        background-color = "#1a1b26";
        text-color = "#c0caf5";
        border-color = "#7aa2f7";
        progress-color = "over #414868";
        border-size = 2;
        border-radius = 6;
        padding = 10;
        margin = 10;
        width = 350;
        default-timeout = 8000;
        "urgency=critical" = {
          border-color = "#f7768e";
          default-timeout = 0;
        };
      };
    };

    # Lock screen (swaylock-effects: blurred screenshot, Tokyo Night ring).
    programs.swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
      settings = {
        screenshots = true;
        effect-blur = "8x4";
        effect-vignette = "0.4:0.8";
        clock = true;
        timestr = "%H:%M";
        datestr = "%A %e %B";
        font = "IBM Plex Sans";
        indicator = true;
        indicator-radius = 110;
        indicator-thickness = 8;
        fade-in = 0.2;
        ignore-empty-password = true;
        show-failed-attempts = true;
        inside-color = "1a1b26cc";
        inside-clear-color = "1a1b26cc";
        inside-ver-color = "1a1b26cc";
        inside-wrong-color = "1a1b26cc";
        ring-color = "414868";
        ring-clear-color = "e0af68";
        ring-ver-color = "7aa2f7";
        ring-wrong-color = "f7768e";
        key-hl-color = "7dcfff";
        bs-hl-color = "f7768e";
        line-color = "00000000";
        line-clear-color = "00000000";
        line-ver-color = "00000000";
        line-wrong-color = "00000000";
        separator-color = "00000000";
        text-color = "c0caf5";
        text-clear-color = "e0af68";
        text-ver-color = "7aa2f7";
        text-wrong-color = "f7768e";
      };
    };

    # Lock after 5 min idle, screen off after 10 min. Super+Escape (or
    # `loginctl lock-session`) locks straight away. There's no suspend on
    # this machine (power.nix), so there's no before-sleep hook.
    services.swayidle =
      let
        lock = "${pkgs.swaylock-effects}/bin/swaylock -f";
      in
      {
        enable = true;
        timeouts = [
          { timeout = 300; command = lock; }
          {
            timeout = 600;
            command = "${pkgs.sway}/bin/swaymsg 'output * power off'";
            resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * power on'";
          }
        ];
        events.lock = lock;
      };

    # Clipboard history; Super+Shift+V picks an earlier entry.
    services.cliphist.enable = true;

    # Warmer screen colours from sunset to sunrise (Adelaide).
    services.wlsunset = {
      enable = true;
      latitude = -34.9;
      longitude = 138.6;
      temperature.night = 4000;
    };

    # Bluetooth tray icon.
    services.blueman-applet.enable = true;
    programs.home-manager.enable = true;
    programs.java.enable = true;
    programs.oh-my-posh = {
      enable = true;
      useTheme = "robbyrussell";
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Archive manager (also Thunar's "Extract here" / "Create archive"),
    # with 7-Zip for .7z and .rar.
    file-roller
    _7zz-rar
    libnotify # notify-send
    alacritty
    btop
    claude-code
    nano
    pavucontrol
    waybar
    wget

    # Waybar VPN indicator: prints status JSON; `waybar-vpn toggle`
    # connects/disconnects (signal 8 refreshes the icon straight away).
    (writeShellScriptBin "waybar-vpn" ''
      if [ "''${1:-}" = toggle ]; then
        if nordvpn status 2>/dev/null | grep -q 'Status: Connected'; then
          nordvpn disconnect >/dev/null 2>&1
        else
          ${pkgs.libnotify}/bin/notify-send -t 3000 NordVPN "Connecting…"
          nordvpn connect New_Zealand >/dev/null 2>&1 || ${pkgs.libnotify}/bin/notify-send NordVPN "Couldn't connect (run: nordvpn login)"
        fi
        pkill -RTMIN+8 waybar
        exit 0
      fi
      s=$(nordvpn status 2>/dev/null | tr -d '\r')
      field() { sed -n "s/.*$1: //p" <<<"$s" | head -1; }
      if grep -q 'Status: Connected' <<<"$s"; then
        tip="$(field Server)\n$(field City), $(field Country)\n$(field 'Current technology')\nClick: disconnect  Right-click: NordVPN app"
        printf '{"text":"\uf023","class":"connected","tooltip":"%s"}\n' "$tip"
      else
        printf '{"text":"\uf09c","class":"disconnected","tooltip":"NordVPN off\\nClick: connect  Right-click: NordVPN app"}\n'
      fi
    '')

    # Waybar OneDrive indicator: reads the onedrive@onedrive service log and
    # prints status JSON (up to date / syncing / error / stopped).
    (writeShellScriptBin "waybar-onedrive" ''
      unit=onedrive@onedrive
      jq=${pkgs.jq}/bin/jq
      if ! systemctl --user is-active -q "$unit"; then
        $jq -cn '{text:"󰅤", class:"stopped", tooltip:"OneDrive sync is stopped\nRight-click: start it"}'
        exit 0
      fi
      journalctl --user -u "$unit" -n 80 -o json --no-pager 2>/dev/null |
      $jq -sc --argjson now "$(date +%s)" '
        def hm: localtime | strftime("%H:%M");
        map({t: ((.__REALTIME_TIMESTAMP | tonumber) / 1000000), m: (.MESSAGE | tostring)}) as $l
        | "Sync with Microsoft OneDrive is complete|No changes or items" as $donere
        | ($l | map(select(.m | test($donere))) | last) as $done
        | ($l | map(select(.m | test("ERROR|Unable to|failed"))) | last) as $err
        | ($l | last) as $latest
        | ($l | map(select(.m | test("^(Uploading|Downloading|Deleting|Moving)")))
             | reverse
             | map((if (.m | startswith("Uploading")) then "↑ "
                    elif (.m | startswith("Downloading")) then "↓ " else "✕ " end)
                   + (.m | sub(" \\.\\.\\..*$"; "") | sub(".*/"; "") | sub("^[^:]*: "; "")))
             | reduce .[] as $f ([]; if index([$f]) then . else . + [$f] end)
             | .[0:4]) as $files
        | (if $files == [] then "" else "\n\nRecent:\n" + ($files | join("\n")) end) as $recent
        | ("\nClick: live log  Right-click: restart sync") as $help
        | if $err != null and $err.t > ($done.t // 0) then
            {text: "󰧠", class: "error",
             tooltip: ("OneDrive error at " + ($err.t | hm) + ":\n" + ($err.m | .[0:120]) + $recent + $help)}
          elif $latest != null and ($latest.m | test($donere) | not) and ($now - $latest.t) < 20 then
            {text: "󰘿", class: "syncing", tooltip: ("OneDrive syncing…\n" + ($latest.m | .[0:120]) + $recent + $help)}
          else
            {text: "󰅠", class: "idle",
             tooltip: ("OneDrive up to date" + (if $done then " (checked " + ($done.t | hm) + ")" else "" end) + $recent + $help)}
          end'
    '')

    # Screenshots: `screenshot area` (drag a box) or `screenshot full`.
    # Saves to ~/Pictures/Screenshots and copies the image to the clipboard.
    grim
    slurp
    wl-clipboard
    (writeShellScriptBin "screenshot" ''
      set -eu
      dir="$HOME/Pictures/Screenshots"
      mkdir -p "$dir"
      file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
      case "''${1:-area}" in
        area) geom="$(slurp)" || exit 0; grim -g "$geom" "$file" ;;
        full) grim "$file" ;;
        *) echo "usage: screenshot [area|full]" >&2; exit 1 ;;
      esac
      wl-copy --type image/png < "$file"
      echo "$file"
    '')
  ] ++ pycharmProjects;

  # Firefox via the NixOS module: installs the wrapFirefox-wrapped build and
  # lets us set policies/prefs/extensions declaratively (programs.firefox.*).
  programs.firefox.enable = true;

  # Bitwarden browser extension, installed automatically in Firefox and
  # Chrome (programs.chromium writes Chrome's policies too).
  programs.firefox.policies.ExtensionSettings."{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
    installation_mode = "normal_installed";
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
  };
  programs.chromium = {
    enable = true;
    extensions = [ "nngceckbapebfimnlniiiahkandclblb" ]; # Bitwarden
  };

  # OneDrive (abraunegg client): syncs ~/OneDrive in the background from login.
  # One-time setup: run `onedrive` and follow the sign-in prompt, then
  # `systemctl --user start onedrive@onedrive`.
  services.onedrive.enable = true;

  # Steam (also enables 32-bit graphics libraries for games).
  programs.steam.enable = true;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-volman
      thunar-archive-plugin
    ];
  };
  services.gvfs.enable = true;    # mounting, trash, volman
  services.tumbler.enable = true; # thumbnails
  programs.xfconf.enable = true;  # persist Thunar settings
  programs.dconf.enable = true;   # GTK/dark-mode settings from home-manager

  fonts.packages = with pkgs; [
    #jetbrainsmono
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    fira-code-symbols
    nerd-fonts.symbols-only # prompt icons for oh-my-posh
    # Narrower monospace candidates (try: foot -f "<name>:size=11")
    nerd-fonts.iosevka        # "Iosevka Nerd Font Mono"
    nerd-fonts.jetbrains-mono # "JetBrainsMono Nerd Font Mono"
    nerd-fonts.victor-mono    # "VictorMono Nerd Font Mono"
    nerd-fonts.blex-mono      # "BlexMono Nerd Font Mono" (IBM Plex Mono)
    ibm-plex                  # IBM Plex Mono/Sans/Serif, original names
  ];
  # Terminals (foot, alacritty) use "monospace"; point it at a Nerd Font so
  # prompt glyphs render instead of boxes.
  fonts.fontconfig.defaultFonts.monospace = [
    "VictorMono Nerd Font Mono"
    "Symbols Nerd Font Mono"
  ];
  # Default proportional font for apps that ask for "sans-serif"
  # (Qt apps like Okular, web pages without their own font, etc.).
  fonts.fontconfig.defaultFonts.sansSerif = [
    "IBM Plex Sans"
    "Noto Sans"
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
