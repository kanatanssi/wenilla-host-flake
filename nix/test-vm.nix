# vm for trying the module: `nix run .#testVM`, then open http://localhost:8090/ on the host.
# http://localhost is a secure context, so WebGPU works without TLS
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

  system.stateVersion = "26.05";
  networking.hostName = "wenilla-host-test";
  services.getty.autologinUser = "root";

  virtualisation = {
    memorySize = 4096;
    cores = 4;
    graphics = false;
    # web ui on the host's loopback only
    forwardPorts = [
      {
        from = "host";
        host.address = "127.0.0.1";
        host.port = 8090;
        guest.port = 8090;
      }
    ];
    # the host's client Data directory (MPQs), the same host path cmangos-flake's test vm shares
    sharedDirectories.client-data = {
      source = lib.mkDefault "/var/lib/cmangos/data";
      target = config.services.wenilla-host.dataDir;
      # use the host's own permissions, not ones another vm (e.g. cmangos-flake's) stored in xattrs
      securityModel = "none";
    };
  };

  networking.firewall.allowedTCPPorts = [ 8090 ];

  services.wenilla-host = {
    enable = true;
    dataDir = lib.mkDefault "/var/lib/cmangos/data";
    # qemu forwards to the guest's own address, not its loopback
    listenAddress = "0.0.0.0";
    # the host as qemu sees it. reaches a game server on the host,
    # or in cmangos-flake's test vm, which forwards 3724 and 8085 to the host
    gameServerHost = lib.mkDefault "10.0.2.2";
  };

  # wait for the shared directory
  systemd.services.wenilla-host.unitConfig.RequiresMountsFor = [
    config.services.wenilla-host.dataDir
  ];
}
