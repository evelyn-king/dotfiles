{
  description = "Lagrange — nix-darwin system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs }:
  let
    configuration = { pkgs, ... }: {
      # Determinate Nix manages the daemon and /etc/nix/nix.conf itself.
      nix.enable = false;

      nixpkgs.hostPlatform = "aarch64-darwin";

      # Every package in this closure is free, so no allowUnfree escape hatch is
      # configured. Adding an unfree package will fail the build until one is —
      # prefer a narrow `allowUnfreePredicate` allowlist over blanket
      # `allowUnfree` so each exception stays a deliberate edit.

      # Owner for user-scoped nix-darwin options.
      system.primaryUser = "evelynking";

      environment.systemPackages = with pkgs; [
        # --- shell and terminal ---
        atuin
        direnv
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
        delta            # brew: git-delta
        git
        git-filter-repo
        git-lfs
        lazygit

        # --- languages, runtimes, package managers ---
        bun
        go
        luarocks
        lua-language-server
        # micromamba — NOT from Nix. 2.6.2 has no Darwin substitute and fails to
        # build from source (libmamba fmt/libcxx-21 incompatibility). Install the
        # standalone binary instead; see docs/nix-darwin.md.
        nodejs           # brew: node
        pixi
        uv

        # --- editors ---
        emacs-macport    # brew cask: emacs-plus-app (different patch set)
        helix
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
        libxml2
        pkgconf
        portaudio
        sccache
        shellcheck

        # --- network and misc ---
        azure-cli
        chezmoi
        gnupg
        herdr
        ollama
        pinentry_mac     # brew: pinentry-mac
        prettyping
        slackdump
        sshpass
        w3m
        wget

        # No former Homebrew cask is managed here except emacs-macport above,
        # which is kept because it is the only one with no self-updater:
        #
        #   1Password, Tailscale   privileged helpers (code-signature-checked
        #                          browser integration; a network system
        #                          extension) that Nix repackaging can break.
        #   Zed, Obsidian, Zotero, self-updaters. The store is read-only, so the
        #   Ghostty, iTerm2, codex update always fails and the tool nags.
        #                          Ghostty would be `ghostty-bin` if reinstated —
        #                          the source build is Linux-only.
        #
        # See docs/nix-darwin.md.
      ];

      # GUI apps land in /Applications/Nix Apps as symlinks, which Spotlight and
      # the Dock handle poorly. mac-app-util writes real aliases instead. It is a
      # third-party flake, so it is left opt-in rather than enabled by default —
      # review it before adding:
      #
      #   inputs.mac-app-util.url = "github:hraban/mac-app-util";
      #   modules = [ configuration inputs.mac-app-util.darwinModules.default ];

      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Compatibility marker. Read `darwin-rebuild changelog` before changing.
      system.stateVersion = 6;
    };
  in
  {
    # darwin-rebuild switch --flake ~/.local/share/chezmoi/nix#lagrange
    darwinConfigurations."lagrange" = nix-darwin.lib.darwinSystem {
      modules = [ configuration ];
    };
  };
}
