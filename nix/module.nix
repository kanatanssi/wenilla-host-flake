# services.wenilla-host: runs wenilla-host (not wenilla-realm), which serves the browser client, the
# game files from the client's MPQs, and a websocket relay to realmd and mangosd.
# players log in with their game accounts, but there is no web login: anyone who reaches the port
# gets the game files and the relay. it listens on loopback by default, TLS and access control are
# left to a reverse proxy
self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.wenilla-host;
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    literalExpression
    ;
  flakePackages = self.packages.${pkgs.stdenv.hostPlatform.system};

  # ipv6 addresses need brackets
  bind =
    if lib.hasInfix ":" cfg.listenAddress then
      "[${cfg.listenAddress}]:${toString cfg.port}"
    else
      "${cfg.listenAddress}:${toString cfg.port}";
in
{
  options.services.wenilla-host = {
    enable = mkEnableOption "wenilla-host, a browser client for a cmangos classic server";

    package = mkOption {
      type = types.package;
      default = flakePackages.wenilla-host;
      defaultText = literalExpression "wenilla-host-flake.packages.\${system}.wenilla-host";
      description = "The wenilla-host server.";
    };

    webPackage = mkOption {
      type = types.package;
      default = flakePackages.wenilla-web;
      defaultText = literalExpression "wenilla-host-flake.packages.\${system}.wenilla-web";
      description = "The browser client. Must be built from the same wenilla commit as `package`.";
    };

    dataDir = mkOption {
      type = types.str;
      example = "/var/lib/cmangos/data";
      description = ''
        The `Data` directory of an English 1.12.1 (build 5875) client, with the MPQs. Not the
        extracted maps and dbc the server uses, though both can live in the same directory.
        Read-only for the service.
      '';
    };

    gameServerHost = mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "192.168.1.10";
      description = "Host running realmd (port 3724) and mangosd (port 8085). The ports are fixed upstream.";
    };

    listenAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen on. Point your reverse proxy here.";
    };

    port = mkOption {
      type = types.port;
      default = 8090;
      description = "Port to listen on.";
    };

    supplementaryGroups = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "cmangos" ];
      description = "Extra groups for the service, e.g. one that can read `dataDir`.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.wenilla-host = {
      description = "wenilla-host, browser client for the 1.12.1 realm";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          (lib.getExe cfg.package)
          "--bind"
          bind
          "--www"
          cfg.webPackage
          "--data"
          cfg.dataDir
          "--upstream"
          cfg.gameServerHost
        ];
        # throwaway user, gets read access to dataDir through supplementaryGroups
        DynamicUser = true;
        SupplementaryGroups = cfg.supplementaryGroups;
        Restart = "on-failure";
        RestartSec = 5;

        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        # no PrivateUsers, it would hide the supplementary groups
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        # AF_UNIX for name lookups through nscd, gameServerHost can be a hostname
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
      };
    };
  };
}
