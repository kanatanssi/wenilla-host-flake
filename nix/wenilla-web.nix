# the browser client: wasm with the WebGPU backend, wasm-bindgen glue and the page, built by
# upstream's own scripts/web-build.sh so its `cp` line decides what ships.
# heavy: a release build of the whole game client
{
  lib,
  stdenv,
  src,
  version,
  cargoDeps,
  rustPlatform,
  rustToolchain,
  wasi-sdk,
  wasm-bindgen-cli,
  binaryen,
  brotli,
}:
stdenv.mkDerivation {
  pname = "wenilla-web";
  inherit version src cargoDeps;

  nativeBuildInputs = [
    rustToolchain
    rustPlatform.cargoSetupHook
    wasm-bindgen-cli
    binaryen
    brotli
  ];

  env = {
    WEB_BACKEND = "webgpu";
    WEB_PROFILE = "release";
    WASI_SDK = "${wasi-sdk}";
    WASM_OPT = lib.getExe' binaryen "wasm-opt";
    # C for the browser target goes through wasi-sdk's clang, not the stdenv's gcc
    CC_wasm32_unknown_unknown = "${wasi-sdk}/bin/clang";
    AR_wasm32_unknown_unknown = "${wasi-sdk}/bin/llvm-ar";
  };

  postPatch = ''
    patchShebangs scripts
  '';

  buildPhase = ''
    runHook preBuild
    scripts/web-build.sh
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -r web/dist $out
    runHook postInstall
  '';

  # web assets only, nothing to strip or patch
  dontFixup = true;

  meta = {
    description = "wenilla's browser client";
    homepage = "https://github.com/Arnesen/wenilla";
    license = with lib.licenses; [
      mit
      asl20
    ];
    platforms = [ "x86_64-linux" ];
  };
}
