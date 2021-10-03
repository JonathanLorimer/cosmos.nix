{ lib, config, pkgs, ... }:
let
  cfg = config.services.hermes;
  hermes-toml = (import ./hermes-toml.nix) { inherit pkgs cfg; };
in
with lib; {
  options.services.hermes = {
    enable = mkEnableOption "hermes";
    package = mkOption {
      type = types.package;
      default = pkgs.hermes;
      description = ''
        The hermes (ibc-rs) software to run.
      '';
    };
    strategy = mkOption {
      type = types.enum [ "packets" "all" ];
      default = "packets";
      description = ''
      '';
    };
    filter = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Filter for all activities based on client state trust threshold; this filter
        is parametrized with (numerator = 1, denominator = 3), so that clients with
        thresholds different than this will be ignored.
      '';
    };
    clear-packets-interval = mkOption {
      type = types.ints.u32;
      default = 100;
      description = ''
        Parametrize the periodic packet clearing feature.
        Interval (in number of blocks) at which pending packets
        should be eagerly cleared. A value of '0' will disable it.
      '';
    };
    tx-confirmation = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Toggle the transaction confirmation mechanism.
        The tx confirmation mechanism periodically queries the `/tx_search` RPC
        endpoint to check that previously-submitted transactions
        (to any chain in this config file) have delivered successfully.
        Experimental feature. Affects telemetry if set to false.
      '';
    };

    # REST API submodule options
    rest = mkOption {
      description = ''
        The REST section defines parameters for Hermes' built-in RESTful API.
        <link xlink:href="https://hermes.informal.systems/rest.html">Rest option docs</link>.
      '';
      type = types.submodule {
        options = {
          enabled = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Where or not to enable the REST service.
            '';
          };
          host = mkOption {
            type = types.string;
            default = "127.0.0.1";
            description = ''
              Specify the IPv4/6 host over which the built-in HTTP server will serve the RESTful.
            '';
          };
          port = mkOption {
            type = types.port;
            default = 3000;
            description = ''
              Specify the port over which the built-in HTTP server will serve the restful API.
            '';
          };
        };
      };
    };

    # Telemetry API submodule options
    telemetry = mkOption {
      description = ''
        The telemetry section defines parameters for Hermes' built-in telemetry capabilities.
        <link xlink:href="https://hermes.informal.systems/telemetry.html">Telemetry option docs</link>.
      '';
      type = types.submodule {
        options = {
          enabled = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Whether or not to enable the telemetry service.
            '';
          };
          host = mkOption {
            type = types.string;
            default = "127.0.0.1";
            description = ''
              Specify the IPv4/6 host over which the built-in HTTP server will serve metrics.
            '';
          };
          port = mkOption {
            type = types.port;
            default = 3000;
            description = ''
              Specify the port over which the built-in HTTP server will serve the metrics gathered.
            '';
          };
        };
      };
    };

    # Chain submodule options
    chains = mkOption {
      description = ''
        A chains section includes parameters related to a chain and the full node to which
        the relayer can send transactions and queries.
      '';
      type = types.listOf (
        types.submodule {
          options = {
            # Required
            id = mkOption {
              type = types.string;
              description = ''
                Specify the chain ID.
              '';
            };
            rpc-address = mkOption {
              type = types.string;
              description = ''
                Specify the RPC address and port where the chain RPC server listens on.
              '';
            };
            grpc-address = mkOption {
              type = types.string;
              description = ''
                Specify the GRPC address and port where the chain GRPC server listens on.
              '';
            };
            websocket-address = mkOption {
              type = types.string;
              description = ''
                Specify the WebSocket address and port where the chain WebSocket server listens on.
              '';
            };
            account-prefix = mkOption {
              type = types.string;
              description = ''
                Specify the prefix used by the chain.
              '';
            };
            key-name = mkOption {
              type = types.string;
              description = ''
                Specify the name of the private key to use for signing transactions. Required
                <link xlink:href="https://hermes.informal.systems/commands/keys/index.html#adding-keys">
                  See the Adding Keys chapter
                </link>.
              '';
            };
            gas-price = mkOption {
              type = types.float;
              description = ''
                Specify the price per gas used of the fee to submit a transaction.
              '';
            };
            gas-denomination = mkOption {
              type = types.string;
              description = ''
                Specify the denomination of the fee to submit a transaction.
              '';
            };

            # Optional
            rpc-timeout = mkOption {
              type = types.string;
              default = "10s";
              description = ''
                Specify the maximum amount of time (duration) that the RPC requests should
                take before timing out.
              '';
            };
            store-prefix = mkOption {
              type = types.string;
              default = "ibc";
              description = ''
                Specify the store prefix used by the on-chain IBC modules.
              '';
            };
            max-gas = mkOption {
              type = types.ints.positive;
              default = 3000000;
              description = ''
                Specify the maximum amount of gas to be used as the gas limit for a transaction.
              '';
            };
            gas-adjustment = mkOption {
              type = types.float;
              default = 0.1;
              description = ''
                Specify by ratio to increase the gas estimate used to compute the fee,
                to account for potential estimation error.
              '';
            };
            max-message-number = mkOption {
              type = types.ints.positive;
              default = 30;
              description = ''
                Specify how many IBC messages at most to include in a single transaction.
              '';
            };
            max-transaction-size = mkOption {
              type = types.ints.positive;
              default = 2097152;
              description = ''
                Specify the maximum size, in bytes, of each transaction that Hermes will submit.
              '';
            };
            clock-drift = mkOption {
              type = types.string;
              default = "5s";
              description = ''
                Specify the maximum amount of time to tolerate a clock drift.
                The clock drift parameter defines how much new (untrusted) header's time
                can drift into the future.
              '';
            };
            trusting-period = mkOption {
              type = types.string;
              default = "14days";
              description = ''
                Specify the amount of time to be used as the light client trusting period.
                It should be significantly less than the unbonding period
                (e.g. unbonding period = 3 weeks, trusting period = 2 weeks).
              '';
            };
            trust-threshold-numerator = mkOption {
              type = types.ints.positive;
              default = 1;
              description = ''
                Specify the trust threshold for the light client, ie. the maximum fraction of validators
                which have changed between two blocks.
                Warning: This is an advanced feature! Modify with caution.
              '';
            };
            trust-threshold-denominator = mkOption {
              type = types.ints.positive;
              default = 3;
              description = ''
                Specify the trust threshold for the light client, ie. the maximum fraction of validators
                which have changed between two blocks.
                Warning: This is an advanced feature! Modify with caution.
              '';
            };
          };
        }
      );
    };
  };

  config = mkIf cfg.enable {
    systemd.services.hermes = {
      description = "Hermes Deamon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "notify";
        ExecStart = "${hermes}/bin/hermes -c ${hermes-toml} start";
      };
    };
  };
}