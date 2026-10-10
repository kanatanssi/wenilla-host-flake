{
  description = "wenilla-host for NixOS: play on a cmangos classic server in the browser";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # upstream pins its rust toolchain in rust-toolchain.toml and needs the wasm32 target
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wenilla = {
      url = "github:Arnesen/wenilla";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      wenilla,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ rust-overlay.overlays.default ];
      };
      wenillaPackages = import ./nix/packages.nix {
        inherit pkgs;
        src = wenilla;
      };
    in
    {
      packages.${system} = {
        inherit (wenillaPackages) wenilla-host wenilla-web;
        default = wenillaPackages.wenilla-host;
      };

      nixosModules.default = import ./nix/module.nix self;

      # vm for trying the module, see README
      nixosConfigurations.testVM = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.default
          ./nix/test-vm.nix
        ];
      };

      apps.${system}.testVM = {
        type = "app";
        program = "${self.nixosConfigurations.testVM.config.system.build.vm}/bin/run-wenilla-host-test-vm";
        meta.description = "Run the test VM";
      };

      checks.${system}.module = import ./nix/test.nix { inherit pkgs self; };

      formatter.${system} = pkgs.nixfmt;
    };
}
