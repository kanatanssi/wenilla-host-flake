# the official wasi-sdk release that upstream's scripts/web-setup.sh downloads.
# the lua build for the browser expects this exact layout, so not composed from nixpkgs
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
}:
stdenv.mkDerivation rec {
  pname = "wasi-sdk";
  # WASI_SDK_VERSION in upstream's scripts/web-setup.sh
  version = "27";

  src = fetchurl {
    url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${version}/wasi-sdk-${version}.0-x86_64-linux.tar.gz";
    hash = "sha256-t9TZRMiFA+TyHYSvB6wpPjRAsbYhC/1/544K/ZLCO8I=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    stdenv.cc.cc.lib
    zlib
  ];

  dontConfigure = true;
  dontBuild = true;
  # the sysroot is wasm, the host strip would break it
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r . $out
    runHook postInstall
  '';

  meta = {
    description = "WASI-enabled WebAssembly C/C++ toolchain (upstream binary release)";
    homepage = "https://github.com/WebAssembly/wasi-sdk";
    license = with lib.licenses; [
      asl20
      llvm-exception
      mit
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
