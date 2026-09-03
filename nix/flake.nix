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
        tealdeer

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
        gcc
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
        greedyCasks = true;

        casks = [
          "1password-cli"
          "adobe-acrobat-reader"
          "nikitabobko/tap/aerospace"
          "basictex"
          "bitwarden"
          "chatgpt"
          "claude"
          "firefox"
          "ghostty"
          "gimp"
          "iterm2"
          "klayout"
          "ltspice"
          "obsidian"
          "paraview"
          "rancher"
          "raycast"
          "spotify"
          "visual-studio-code"
          "zed"
          "zotero"
        ];

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
