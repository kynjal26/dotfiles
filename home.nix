{ config, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";
  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder (wired into zsh below)
    jq        # json on the command line
    zoxide    # smart cd that learns your dirs
    eza       # colorful ls with icons (pairs with Hack Nerd Font)
    bat       # colorful cat, also powers fzf previews
    lazygit
    neovim
    nodejs  # provides npm for the opt-in Pi install in README; pinned via flake.lock
    gh      # GitHub CLI; auth stays in your keyring via `gh auth login`, never in this repo
    # the font everything renders in
    nerd-fonts.hack
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";
  # Nix store is read-only, so npm -g needs a user-owned prefix;
  # this makes README's opt-in Pi install work with Nix-provided npm.
  home.sessionVariables.NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
  home.sessionPath = [ "${config.home.homeDirectory}/.npm-global/bin" ];

  # Fully automatic worktree hygiene: treehouse itself never deletes
  # anything unasked (no daemon, no TTL; destructive commands are
  # dry-run by default), so this nightly job runs the one operation
  # that is provably safe - pruning idle, clean, merged pools.
  # Anything leased, dirty, unmerged, or in use is always left alone,
  # including when the Mac is offline. Log kept for curiosity.
  launchd.agents.treehouse-prune = {
    enable = true;
    config = {
      ProgramArguments = [ "/opt/homebrew/bin/treehouse" "prune" "--all" "--yes" ];
      StartCalendarInterval = { Hour = 4; Minute = 0; };
      RunAtLoad = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/treehouse-prune.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/treehouse-prune.err";
    };
  };

  # Fuzzy finding and smart navigation, all in Monokai Pro to match
  # WezTerm, Neovim, and Pi. Ctrl-T finds files, Alt-C jumps into a
  # folder, Ctrl-R searches history, `z` jumps to frecent dirs.
  programs.fzf.enable = true;
  programs.fzf.enableZshIntegration = true;
  programs.zoxide.enable = true;
  programs.zoxide.enableZshIntegration = true;
  programs.eza.enable = true;
  programs.eza.enableZshIntegration = true;
  home.sessionVariables.FZF_DEFAULT_COMMAND = "fd --type f --hidden --exclude .git";
  home.sessionVariables.FZF_CTRL_T_COMMAND = "fd --type f --hidden --exclude .git";
  home.sessionVariables.FZF_ALT_C_COMMAND = "fd --type d --hidden --exclude .git";
  home.sessionVariables.FZF_ALT_C_OPTS = "--preview-window=hidden";
  home.sessionVariables.FZF_DEFAULT_OPTS =
    "--height=40% --layout=reverse --border "
    + "--color=fg:#fcfcfa,bg:#221f22,hl:#ffd866,fg+:#fcfcfa,bg+:#403e41,hl+:#ffd866,"
    + "info:#78dce8,prompt:#a9dc76,pointer:#ff6188,marker:#ffd866,spinner:#78dce8,header:#939293 "
    + "--preview='bat --color=always --style=numbers --line-range=:200 {}' --preview-window=right:60%:wrap";

  # Two GitHub accounts over HTTPS (no SSH in this repo).
  # kynjal26 is the fallback; anything under ~/work/ switches to KingJune28.
  # Emails are per-account noreply addresses so commits link without exposing real email.
  # Names are display text only; change the two `name` lines if you prefer your real name.
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "kynjal26";
        email = "289512778+kynjal26@users.noreply.github.com";
      };
      init.defaultBranch = "main";
      credential.helper = "osxkeychain";
      credential."https://github.com".username = "kynjal26";
    };
    includes = [
      {
        condition = "gitdir:~/work/";
        contents = {
          user = {
            name = "GhostBehindTheMachine";
            email = "48277658+KingJune28@users.noreply.github.com";
          };
          credential."https://github.com".username = "KingJune28";
        };
      }
    ];
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      bindkey '^f' autosuggest-accept
    '';
    shellAliases = {
      ".." = "cd ..";
      ls = "eza --icons --group-directories-first";
      ll = "eza -l --icons --git --group-directories-first";
      la = "eza -la --icons --git --group-directories-first";
      lt = "eza --tree --level=2 --icons";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      rebuild = "~/.dotfiles/rebuild.sh";  # re-apply this config
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](green)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  # Keep Pi's credential and runtime state local by linking only authored files and directories.
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes";
  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions";
  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/models.json";
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
