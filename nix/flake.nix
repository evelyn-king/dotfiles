{
  description = "nix-darwin system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    mac-app-util.url = "github:hraban/mac-app-util";
    mac-app-util.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, ... }:
  let
    configuration = { pkgs, ... }: {
      # Determinate Nix manages the daemon and /etc/nix/nix.conf itself.
      determinateNix.enable = true;

      nixpkgs.hostPlatform = "aarch64-darwin";

      # ~/.zshrc initializes completion after adding user site-functions.
      programs.zsh.enableGlobalCompInit = false;

      environment.systemPackages = with pkgs; [
        # --- shell and terminal ---
        atuin
        direnv
        keychain
        starship
        tmux
        zellij
        zoxide

        # --- search and file tools ---
        ast-grep
        bat
        dust
        duf
        eza
        fd
        fzf
        jq
        ripgrep
        tldr

        # --- git ---
        delta
        git
        git-lfs
        lazygit

        # --- languages, runtimes, package managers ---
        # Anything managed by mise is deliberately not here
        bun
        luarocks
        lua-language-server
        mise
        pixi
        uv

        # --- editors ---
        emacs-macport
        neovim
        vim

        # --- system and monitoring ---
        btop
        htop
        hyperfine
        pv

        # --- build and toolchain ---
        cmake
        coreutils
        gawk
        graphicsmagick
        graphviz
        libxml2
        pkgconf
        portaudio
        sccache
        shellcheck
        sqlite

        # --- documents, data and ML ---
        (aspellWithDicts (dicts: with dicts; [ en ]))
        llama-cpp
        pandoc
        poppler-utils
        tesseract

        # --- network and misc ---
        chezmoi
        cloudflared
        gnupg
        google-cloud-sdk
        lima
        pinentry_mac
        prettyping
        sshpass
        w3m
        wget

      ];

      # Homebrew remains the escape hatch for macOS applications that are not
      # a good fit for the read-only Nix store.
      homebrew = {
        enable = true;
        taps = [ "nikitabobko/tap" ];
        # 43 of the 47 casks below set `auto_updates`, so forcing Homebrew to
        # own every version means fighting each vendor's own updater on a
        # roughly fortnightly cycle, and re-running a pkg installer under sudo
        # for the Microsoft suite, google-drive, onedrive, cloudflare-warp,
        # tailscale-app, zoom and the Logitech pair. Let the apps update
        # themselves instead, and opt individual casks back in below.
        #
        # This does not stop `upgrade = true` from upgrading the four casks
        # that do not self-update (1password-cli, aerospace, basictex, dot);
        # non-greedy `brew upgrade` already covers those.
        greedyCasks = false;

        casks = [
          # --- security and credentials ---
          "bitwarden"

          # --- window management and launchers ---
          # bartender, notion-calendar and raindropio each sat between seven
          # months and two years out of date while installed by hand, despite
          # all three advertising `auto_updates`. Non-greedy would recreate the
          # conditions they rotted under, so Homebrew forces these three.
          "nikitabobko/tap/aerospace"
          { name = "bartender"; greedy = true; }
          "raycast"

          # --- browsers ---
          "brave-origin"
          "firefox"
          "google-chrome"
          "zen"

          # --- terminals and editors ---
          "ghostty"
          "iterm2"
          "visual-studio-code"
          "zed"

          # --- AI assistants ---
          "chatgpt"
          "claude"

          # --- notes, tasks and reference ---
          "dot"
          "notion"
          "obsidian"
          { name = "raindropio"; greedy = true; }
          "todoist-app"
          "zotero"

          # --- communication ---
          "discord"
          "proton-mail"
          "readdle-spark"
          "signal"
          "zoom"

          # --- office and documents ---
          "basictex"
          "microsoft-excel"
          "microsoft-powerpoint"
          "microsoft-word"

          # --- cloud storage and sync ---
          "dropbox"
          "google-drive"
          "onedrive"
          "proton-drive"

          # --- networking ---
          "cloudflare-warp"
          "tailscale-app"

          # --- hardware ---
          "logi-options+"
          "logitune"

          # --- containers ---
          "rancher"

          # --- media and games ---
          "spotify"
          "steam"
        ];

        # Mac App Store apps, installed with `mas`. nix-darwin puts `pkgs.mas`
        # on the activation PATH, so it is not declared as a formula.
        #
        # Two caveats from the Homebrew Bundle implementation:
        #   * the App Store account that owns these must be signed in, or
        #     activation cannot install or upgrade them;
        #   * removing an entry here does NOT uninstall the app, even with
        #     `cleanup = "uninstall"`. Delete those by hand.
        #
        # Ids come from `kMDItemAppStoreAdamID` on the installed bundle.
        masApps = {
          "Amazon Kindle" = 302584613;
          DaisyDisk = 411643860;
          Keynote = 409183694;
          Magnet = 441258766;
          Slack = 803453959;
          WireGuard = 1451685025;
          Xcode = 497799835;
        };

        onActivation = {
          autoUpdate = true;
          # This flake owns the Homebrew prefix. Remove any formula, cask, or
          # tap that is not declared above.
          cleanup = "uninstall";
          upgrade = true;
        };
      };

      fonts.packages = [
        pkgs.nerd-fonts.caskaydia-cove
        pkgs.nerd-fonts.fira-code
        pkgs.nerd-fonts.hack
      ];

      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Compatibility marker. Read `darwin-rebuild changelog` before changing.
      system.stateVersion = 6;
    };
  in
  {
    # darwin-rebuild switch --flake "$(chezmoi source-path)/nix#macbook"
    darwinConfigurations."macbook" = nix-darwin.lib.darwinSystem {
      modules = [
        inputs.determinate.darwinModules.default
        configuration
        inputs.mac-app-util.darwinModules.default
        # Host-specific account for user-scoped nix-darwin options.
        { system.primaryUser = "evelynking"; }
      ];
    };
  };
}
