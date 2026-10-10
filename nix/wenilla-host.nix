# the server: serves the web client, game files from the MPQs and a websocket relay to realmd/mangosd
{
  lib,
  src,
  version,
  cargoDeps,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "wenilla-host";
  inherit version src cargoDeps;

  cargoBuildFlags = [
    "-p"
    "wenilla-host"
  ];
  # tests that need game data skip themselves
  cargoTestFlags = [
    "-p"
    "wenilla-host"
  ];

  meta = {
    description = "Server for wenilla's browser client";
    homepage = "https://github.com/Arnesen/wenilla";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "wenilla-host";
    platforms = [ "x86_64-linux" ];
  };
}
