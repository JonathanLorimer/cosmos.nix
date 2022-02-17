{ pkgs, thor-src, tags ? "testnet" }:
let
  pname = "thor";
  version = "v0.80.0";
in
pkgs.buildGoModule {
  inherit pname version;
  src = "${thor-src}";
  buildInputs = with pkgs; [ pkg-config gcc libusb1 ];
  nativBuildInputs = with pkgs; [ pkg-config gcc libusb1 ];
  propagatedBuildInputs = with pkgs; [ pkg-config gcc libusb1 ];
  CGO_ENABLED = "1";
  CGO_CFLAGS = [
    "-I ${pkgs.libusb1}/include"
  ];

  CGO_LDFLAGS = [
    "-L ${pkgs.libusb1}/lib"
  ];
  GO_NO_VENDOR_CHECKS = "1";
  proxyVendor = true;
  vendorSha256 = "sha256-8SV7qww1ueVHKdS6jahLxaORMi/DknPiYaP2VIcDvH8=";
  buildFlags = "-tags ${tags}";
  postBuild = "ls vendor";
  postConfigure = "ls vendor/github.com/zondax/hid";
  buildFlagsArray = ''
    -ldflags=
    -X gitlab.com/thorchain/thornode/constants.Version=${version} \
    -X gitlab.com/thorchain/thornode/constants.GitCommit=${thor-src.rev} \
    -X github.com/cosmos/cosmos-sdk/version.Name=THORChain \
    -X github.com/cosmos/cosmos-sdk/version.AppName=thornode \
    -X github.com/cosmos/cosmos-sdk/version.Version=${version} \
    -X github.com/cosmos/cosmos-sdk/version.Commit=${thor-src.rev} \
    -X github.com/cosmos/cosmos-sdk/version.BuildTags=${tags}
  '';
}

