{ pkgs, cfg }:
with cfg;
let
  boolToString = bool: if bool then "true" else "false";
  rest = with cfg.rest; with builtins;
    ''
      [rest]
      enabled = ${boolToString enabled}
      host = '${host}'
      port = ${toString port}
    '';

  telemetry = with cfg.telemetry;
    ''
      [telemetry]
      enabled = ${boolToString enabled}
      host = '${host}'
      port = ${toString port}
    '';

  chain-fold-op = accumulator: chain:
    with chain;
    accumulator +
    ''
      [[chains]]
      id = '${id}'
      rpc_addr = '${rpc-address}'
      grpc_addr = '${grpc-address}'
      websocket_addr = '${websocket-address}'
      rpc_timeout = '${toString rpc-timeout}'
      account_prefix = '${account-prefix}'
      key_name = '${key-name}'
      store_prefix = '${store-prefix}'
      max_gas = ${toString max-gas}
      gas_price = { price = ${toString gas-price}, denom = '${toString gas-denomination}' }
      gas_adjustment = ${toString gas-adjustment}
      max_msg_num = ${toString max-message-number}
      max_tx_size = ${toString max-transaction-size}
      clock_drift = '${clock-drift}'
      trusting_period = '${trusting-period}'
      trust_threshold = { numerator = '${toString trust-threshold-numerator}', denominator = '${toString trust-threshold-denominator}' }
    '';
  chains = builtins.foldl' chain-fold-op "" cfg.chains;
in
pkgs.writeTextFile {
  name = "config.toml";
  text = ''
    [global]
    strategy = '${strategy}'
    filter = ${boolToString filter}
    log_level = '${log-level}'
    clear_packets_interval = ${toString clear-packets-interval}
    tx_confirmation = ${boolToString tx-confirmation}
  ''
  + "\n"
  + rest
  + "\n"
  + telemetry
  + "\n"
  + chains;
}
