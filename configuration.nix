{ user, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;
  # Strap-style hardening, done declaratively so it survives updates.
  security.pam.services.sudo_local.touchIdAuth = true;  # sudo with Touch ID
  networking.applicationFirewall.enable = true;          # macOS app firewall
  system.defaults = {
    screensaver.askForPassword = true;       # require password immediately
    screensaver.askForPasswordDelay = 0;
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      ApplePressAndHoldEnabled = false;  # long press repeats instead of accent menu
      AppleKeyboardUIMode = 3;           # full keyboard control in dialogs
      NSNavPanelExpandedStateForSaveMode = true;   # expanded save panel
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;      # expanded print panel
      PMPrintingExpandedStateForPrint2 = true;
      _HIHideMenuBar = true;  # auto-hide the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    dock.autohide-delay = 0.0;         # dock appears instantly
    dock.autohide-time-modifier = 0.0;
    dock.mru-spaces = false;           # spaces stay in place
    dock.show-recents = false;         # no recent apps clutter
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    finder.ShowPathbar = true;             # breadcrumb path at the bottom
    finder.ShowStatusBar = true;           # file count and disk space
    finder._FXShowPosixPathInTitle = true; # full path in window title
    menuExtraClock.Show24Hour = true;      # 24-hour clock with seconds
    menuExtraClock.ShowSeconds = true;
    menuExtraClock.ShowDayOfWeek = true;
    screencapture.location = "/Users/${user}/Pictures/Screenshots";  # out of the way
    screencapture.type = "png";
    trackpad.Clicking = true;              # tap to click
    trackpad.TrackpadRightClick = true;    # two-finger right click
  };
  # The screenshot folder above must exist or captures fail silently.
  # Activation runs as root, so create it as the user.
  system.activationScripts.screenshotsFolder.text = ''
    sudo -u ${user} mkdir -p "/Users/${user}/Pictures/Screenshots"
  '';
  nix-homebrew = {
    enable = true;
    inherit user;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    brews = [
      "herdr"
      "treehouse"  # pre-warmed git worktree pool for parallel AI agents
    ];
    casks = [
      "wezterm"
      "claude-code"
      "wallspace"  # live wallpapers, native Swift, free tier with no login
      "xnapper"    # beautiful screenshots; free tier stamps a watermark
    ];
  };
}
