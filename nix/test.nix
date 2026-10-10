# boots the module with the real wenilla-host and a stub web client, so the check skips the wasm build.
# there is no game data, so wenilla-host stops at upstream's "no MPQs" error. reaching that error
# proves it ran as configured and could list a dataDir that only the cmangos group can read
{ pkgs, self }:
pkgs.testers.runNixOSTest {
  name = "wenilla-host";

  nodes.machine = {
    imports = [ self.nixosModules.default ];
    # what a cmangos setup provides: a group that can read the client data
    users.groups.cmangos = { };
    systemd.tmpfiles.rules = [ "d /var/lib/cmangos/data 0750 root cmangos -" ];

    services.wenilla-host = {
      enable = true;
      dataDir = "/var/lib/cmangos/data";
      supplementaryGroups = [ "cmangos" ];
      webPackage = pkgs.runCommand "wenilla-web-stub" { } ''
        mkdir $out
        echo '<!doctype html><title>wenilla</title>' > $out/index.html
      '';
    };
  };

  testScript = ''
    machine.wait_until_succeeds(
        "journalctl -u wenilla-host | grep -q 'no known vanilla MPQs found in /var/lib/cmangos/data'"
    )
    unit = machine.succeed("systemctl cat wenilla-host")
    assert "--upstream 127.0.0.1" in unit and "--bind 127.0.0.1:8090" in unit, unit
    props = machine.succeed("systemctl show -p DynamicUser -p SupplementaryGroups wenilla-host")
    assert "DynamicUser=yes" in props and "SupplementaryGroups=cmangos" in props, props
  '';
}
