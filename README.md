# wenilla-host-flake

NixOS module and packages for `wenilla-host` from [wenilla](https://github.com/Arnesen/wenilla): play on a CMaNGOS Classic server in the browser. x86_64-linux only.

This flake is only for `wenilla-host`, not `wenilla-realm`. wenilla-realm is upstream's multi-user service with its own web login, admin panel and game accounts managed over SOAP, and it is not packaged here.

Status: early. Tested in the bundled test VM against a CMaNGOS Classic server. Not affiliated with wenilla or the CMaNGOS project.

wenilla-host runs next to realmd and mangosd. It serves the browser client and the game files from the client's MPQs, and it relays the game connection over WebSocket, because a browser can't open raw TCP sockets. In the browser, players get the game's own login screen and log in with their ordinary game accounts, much like with the stock client.

## With cmangos-flake

[cmangos-flake](https://github.com/kanatanssi/cmangos-flake) runs the server itself: realmd, mangosd, MariaDB, playerbots and declarative game accounts. The two are meant to run side by side on one host:

- the game accounts from `gameAccounts` log in on wenilla's login screen
- wenilla reads the client MPQs from cmangos-flake's data directory, through the `cmangos` group
- the relay connects to realmd and mangosd on `127.0.0.1`, so the game ports don't need to be open. Open them (`openPorts`) only if native clients should connect too

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    cmangos.url = "github:kanatanssi/cmangos-flake";
    wenilla-host.url = "github:kanatanssi/wenilla-host-flake";
  };

  outputs = { nixpkgs, cmangos, wenilla-host, ... }: {
    nixosConfigurations.server = nixpkgs.lib.nixosSystem {
      modules = [
        cmangos.nixosModules.default
        wenilla-host.nixosModules.default
        ({ config, ... }: {
          services.cmangos-server = {
            enable = true;
            dbPasswordFile = config.sops.secrets.cmangos-db.path;
            gameAccounts.perttupeikko = { passwordFile = config.sops.secrets.perttu.path; };
            # wenilla needs the anticheat off
            anticheatSettings.Anticheat_Enable = "0";
          };

          services.wenilla-host = {
            enable = true;
            # copy the client's MPQs here, next to the extracted maps and dbc
            dataDir = config.services.cmangos-server.cmangosDataDir;
            # the group cmangos-flake creates, it can read dataDir
            supplementaryGroups = [ config.services.cmangos-server.user ];
          };
        })
      ];
    };
  };
}
```

Then put a reverse proxy in front of `127.0.0.1:8090`, see [Security](#security).

## Usage

With any other CMaNGOS setup, on this host or another:

```nix
{
  inputs.wenilla-host.url = "github:kanatanssi/wenilla-host-flake";

  outputs = { nixpkgs, wenilla-host, ... }: {
    nixosConfigurations.server = nixpkgs.lib.nixosSystem {
      modules = [
        wenilla-host.nixosModules.default
        {
          services.wenilla-host = {
            enable = true;
            dataDir = "/srv/wow/Data";            # the client's Data directory, with the MPQs
            gameServerHost = "192.168.1.10";      # realmd and mangosd, default 127.0.0.1
            # supplementaryGroups = [ "games" ];  # a group that can read dataDir
            # listenAddress = "127.0.0.1";        # default, point your reverse proxy here
            # port = 8090;                        # default
          };
        }
      ];
    };
  };
}
```

The packages are built with this flake's own pinned nixpkgs. There's no binary cache, so the first deploy builds the browser client from source, which takes a while: a release build of the whole game client for wasm.

## Security

wenilla-host has no web login of its own. Playing still needs a game account, but everything before the game's login screen is open: anyone who reaches the port can download the game files and open connections to realmd and mangosd through the relay. Upstream calls wenilla-host a local testing tool for this reason.

The module listens on `127.0.0.1`. To let players in from elsewhere, put it behind a reverse proxy that does TLS and access control (forward auth, a VPN, …) and passes WebSockets. That part is outside this flake. The browser sends the proxy's auth cookie with the game file requests and the WebSocket upgrade as well, so cookie-based auth covers everything.

The page also accepts `?user=&pass=` links that log in directly. Tell players not to share them.

The service runs as a throwaway user (`DynamicUser`) and sees the rest of the system read-only.

## Client data

`dataDir` is the `Data` directory of an English 1.12.1 (build 5875) client, with the `.MPQ` files. These are not the extracted `maps`, `vmaps`, `mmaps` and `dbc` that the server uses. Both can live in the same directory, because wenilla only reads the MPQs.

The service needs read access to the directory and the files. cmangos-flake creates its data directory as `0550 cmangos:cmangos`, so with the MPQs there and readable by the group, `supplementaryGroups = [ "cmangos" ]` is enough. Anywhere else, use a group of your own, or make the files world-readable.

## Game server

The server must have its anticheat off. With cmangos-flake, use `anticheatSettings` as in the example above. On other setups, set `Enable = 0` in `anticheat.conf`.

The relay only connects to ports 3724 (realmd) and 8085 (mangosd). Upstream hardcodes both. It always dials `gameServerHost` and ignores the address realmd hands out, so cmangos-flake's `realmAddress` only matters for native clients.

## Browser

The game renders with WebGPU, which browsers only allow in a secure context: https, or `http://localhost`. Use a current Chrome or Edge. On Linux, Chrome also needs the `--enable-unsafe-webgpu` flag.

## Options

| Option | Default | Notes |
|---|---|---|
| `enable` | `false` | |
| `dataDir` | required | The client's `Data` directory with the MPQs. See [Client data](#client-data). |
| `gameServerHost` | `127.0.0.1` | Host running realmd and mangosd. |
| `listenAddress` | `127.0.0.1` | Point your reverse proxy here. |
| `port` | `8090` | |
| `supplementaryGroups` | `[ ]` | Extra groups for the service, e.g. `[ "cmangos" ]` to read `dataDir`. |
| `package` / `webPackage` | this flake's `wenilla-host` / `wenilla-web` | Must be built from the same wenilla commit. |

## Test VM

```
nix run .#testVM
```

Then open http://localhost:8090/ on the host. The VM autologins as root, and `Ctrl-a x` quits. Its disk is `wenilla-host-test.qcow2` in the directory you launch from.

The VM shares the host's `/var/lib/cmangos/data` (put the MPQs there, world-readable). It connects to the game server at `10.0.2.2`, which is the host as QEMU sees it. That covers a server running on the host, and cmangos-flake's test VM, which forwards 3724 and 8085 to the host. Start that one first.

For another server or data path, extend the VM from your own flake:

```nix
nixosConfigurations.my-test-vm = wenilla-host.nixosConfigurations.testVM.extendModules {
  modules = [{
    services.wenilla-host.gameServerHost = "192.168.1.10";
    virtualisation.sharedDirectories.client-data.source = "/path/to/Data";
  }];
};
```

```
nix build .#nixosConfigurations.my-test-vm.config.system.build.vm
./result/bin/run-wenilla-host-test-vm
```

## Development

`nix flake check` builds wenilla-host and runs a NixOS VM test of the module. The test has no game data and uses a stub instead of the browser client, so it only checks that the service runs as configured. Before pushing, also try the real thing in the test VM.

wenilla is pinned in `flake.lock`. To update it:

```
nix flake update wenilla
```

If upstream moved its `wasm-bindgen` version, evaluation fails in `nix/wasm-bindgen-cli.nix`. Add the new version there with `lib.fakeHash`, and copy the real hashes from the build errors.

nixpkgs follows a stable NixOS release (`nixos-26.05`). For a new release, change the branch in `flake.nix`, then run `nix flake update nixpkgs`.

## License

The Nix code in this repository is licensed under the [MIT License](LICENSE).

This flake only fetches and builds upstream projects. Their code is not part of this repository and keeps its own license:

- [wenilla](https://github.com/Arnesen/wenilla): MIT or Apache-2.0
- [wasi-sdk](https://github.com/WebAssembly/wasi-sdk), used to build the browser client: Apache-2.0 with LLVM exception

Game client data is not included and remains the property of its owners.
