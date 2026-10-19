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
in
{
  imports =
    [ # Include the results of the hardware scan.
      /etc/nixos/hardware-configuration.nix
      (import "${home-manager}/nixos")
      ./macbook12-audio.nix
      ./power.nix
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

  programs.sway.enable = true;

  # Cooling/power: fanless MacBook, so throttle smartly and allow power-saver mode
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = true;

  # Set your time zone.
  time.timeZone = "Australia/Adelaide";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_AU.UTF-8";

  # Login screen that launches sway.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd sway";
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
    extraGroups = [ "networkmanager" "wheel" ];
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
      drawio # draw.io diagram editor
      flameshot
      fuzzel
      git-lfs
      google-chrome
      hunspellDicts.en_AU # spell checking for LibreOffice
      kdePackages.okular # PDF annotation/forms/signing (zathura is the default viewer)
      jetbrains.idea
      jetbrains.pycharm
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
    };
    # Also tell GTK4/libadwaita apps and portals to prefer dark.
    dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
    # Keyboard-driven PDF viewer (default for PDFs), Tokyo Night colours.
    # Copy selected text to the clipboard, and recolour pages with Ctrl+R.
    programs.zathura = {
      enable = true;
      options = {
        selection-clipboard = "clipboard";
        adjust-open = "width";
        font = "FiraCode Nerd Font Mono 10";
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
    alacritty
    btop
    claude-code
    nano
    pavucontrol
    waybar
    wget

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
  ];
  # Terminals (foot, alacritty) use "monospace"; point it at a Nerd Font so
  # prompt glyphs render instead of boxes.
  fonts.fontconfig.defaultFonts.monospace = [
    "FiraCode Nerd Font Mono"
    "Symbols Nerd Font Mono"
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
