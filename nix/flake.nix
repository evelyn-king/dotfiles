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
        git-filter-repo
        git-lfs
        lazygit

        # --- languages, runtimes, package managers ---
        # node, python and go are NOT here: mise owns the runtimes, pinned in
        # dot_config/mise/conf.d/10-dotfiles.toml. bun and uv stay because mise shells out
        # to them for its npm: and pipx: backends. micromamba is not here
        # either — nixpkgs has no aarch64-darwin build; mise fetches the
        # upstream standalone binary. See docs/nix-darwin.md.
        bun
        luarocks
        lua-language-server
        mise
        pixi
        rustup
        uv

        # --- editors ---
        emacs-macport
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
        google-cloud-sdk
        herdr
        ollama
        pinentry_mac
        prettyping
        slackdump
        sshpass
        w3m
        wget

        # emacs-macport is the only GUI app bundle in this closure, because it
        # is the only one with no self-updater. The apps deliberately left out:
        #
        #   Tailscale              installs a network system extension, whose
        #                          signature chain Nix repackaging can break.
        #   Zed, Obsidian, Zotero, self-updaters. The store is read-only, so the
        #   Ghostty, iTerm2        update always fails and the app nags.
        #                          Ghostty would be `ghostty-bin` here — the
        #                          source build is Linux-only.
        #
        # See docs/nix-darwin.md.
      ];

      # Ghostty pins "CaskaydiaCove Nerd Font" by name and starship and
      # `eza --icons` need the glyphs, so the font belongs to the system rather
      # than to whoever last dropped an .otf into ~/Library/Fonts.
      fonts.packages = [ pkgs.nerd-fonts.caskaydia-cove ];

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
