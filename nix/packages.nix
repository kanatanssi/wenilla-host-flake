# packages built from the wenilla source, `src` is the wenilla flake input
{ pkgs, src }:
let
  inherit (pkgs) lib;

  # the exact toolchain upstream pins, plus the browser target
  toolchainChannel = (lib.importTOML "${src}/rust-toolchain.toml").toolchain.channel;
  rustToolchain = pkgs.rust-bin.stable.${toolchainChannel}.minimal.override {
    targets = [ "wasm32-unknown-unknown" ];
  };
  rustPlatform = pkgs.makeRustPlatform {
    cargo = rustToolchain;
    rustc = rustToolchain;
  };

  # nixpkgs convention for untagged sources, the exact commit is pinned in flake.lock
  version =
    let
      d = src.lastModifiedDate;
    in
    (lib.importTOML "${src}/Cargo.toml").workspace.package.version
    + "-unstable-${lib.substring 0 4 d}-${lib.substring 4 2 d}-${lib.substring 6 2 d}";

  # one vendored crate set for both builds, upstream has no git dependencies
  cargoDeps = rustPlatform.importCargoLock { lockFile = "${src}/Cargo.lock"; };

  wasi-sdk = pkgs.callPackage ./wasi-sdk.nix { };

  # the cli must match the wasm-bindgen crate in Cargo.lock exactly
  cargoLockPackages = (lib.importTOML "${src}/Cargo.lock").package;
  wasmBindgen = lib.findFirst (
    p: p.name == "wasm-bindgen"
  ) (throw "no wasm-bindgen in Cargo.lock") cargoLockPackages;
  wasm-bindgen-cli = pkgs.callPackage ./wasm-bindgen-cli.nix { inherit (wasmBindgen) version; };

  common = {
    inherit version cargoDeps rustPlatform;
    src = src.outPath;
  };
in
{
  wenilla-host = pkgs.callPackage ./wenilla-host.nix common;

  wenilla-web = pkgs.callPackage ./wenilla-web.nix (
    common
    // {
      inherit rustToolchain wasi-sdk wasm-bindgen-cli;
    }
  );
}
