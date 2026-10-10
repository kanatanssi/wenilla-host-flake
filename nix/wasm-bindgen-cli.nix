# wasm-bindgen-cli at the version wenilla's Cargo.lock pins.
# when upstream bumps it, evaluation fails here: add the new version with lib.fakeHash
# and copy the real hashes from the build errors
{
  lib,
  buildWasmBindgenCli,
  fetchCrate,
  rustPlatform,
  version,
}:
let
  hashes = {
    "0.2.122" = {
      src = "sha256-vO4RSxi/sMWxmsEs3GuljdMfIRSu75A+Q+c5wgYToRU=";
      cargoDeps = "sha256-Inup6vvJSG5ghNyeDPyZbfZo4d0LsMG2OJfStoaeDBs=";
    };
  };
  hash =
    hashes.${version}
      or (throw "nix/wasm-bindgen-cli.nix: no hashes for wasm-bindgen-cli ${version}, add them");
  src = fetchCrate {
    pname = "wasm-bindgen-cli";
    inherit version;
    hash = hash.src;
  };
in
buildWasmBindgenCli {
  inherit src version;
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit src version;
    pname = "wasm-bindgen-cli";
    hash = hash.cargoDeps;
  };
}
