{
  description = "railgun's standalone Home Manager config for Debian (GNOME + i3)";

  inputs = {
    # CORE =====================================================================
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SECRETS ==================================================================
    sops-nix = {
      # Pinned to last commit compatible with Go 1.25 (nixpkgs 25.11).
      # Newer sops-nix requires Go 1.26 which 25.11 does not ship.
      url = "github:Mic92/sops-nix/13616fff713a9f94055c66f15687ebdc17a335df";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # THEMING ==================================================================
    stylix = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cozette.url = "github:railgun210/cozette";
    hm-ricing-mode.url = "github:Markus328/hm-ricing-mode/fix-hm-module";
    buuf-icon-theme.url = "github:railgun210/buuf-gnome";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    sops-nix,
    stylix,
    cozette,
    hm-ricing-mode,
    buuf-icon-theme,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        (final: prev: {
          cozette = cozette.packages.${system}.default;
          # CozetteVector patched with all Nerd Font glyphs for the i3 status bar.
          # Output family name: "CozetteVector Nerd Font Mono".
          cozetteNF = prev.runCommand "cozette-nerd-font" {
            nativeBuildInputs = [prev.nerd-font-patcher];
          } ''
            mkdir -p $out/share/fonts/truetype
            nerd-font-patcher --complete --mono \
              ${final.cozette}/share/fonts/truetype/CozetteVector.ttf \
              -o $out/share/fonts/truetype/
          '';
          buuf-icon-theme = buuf-icon-theme.packages.${system}.default;
        })
      ];
      config.allowUnfree = true;
      config.nvidia.acceptLicense = true; # for targets.genericLinux.gpu.nvidia
    };
  in {
    formatter.${system} = pkgs.alejandra;

    # Lets `nix flake check` (and CI) evaluate the whole Home Manager config;
    # it skips homeConfigurations on its own.
    checks.${system}.home = self.homeConfigurations."railgun".activationPackage;

    homeConfigurations."railgun" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        hm-ricing-mode.homeManagerModules.hm-ricing-mode
        sops-nix.homeModules.sops
        stylix.homeModules.stylix
        ./home-manager/home.nix
      ];
    };
  };
}
