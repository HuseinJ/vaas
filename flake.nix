{
  description = "A flake for easy development of the multi-language Verdict-as-a-Service librarie";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) lib;

        tools = [
          pkgs.just
          pkgs.lazygit
        ];

        rustDeps = [
          pkgs.cargo
          pkgs.rustc
          pkgs.clippy
          pkgs.rustfmt
        ] ++ lib.optional pkgs.stdenv.isDarwin [
          pkgs.darwin.apple_sdk.frameworks.Cocoa
          pkgs.libiconv
          pkgs.iconv
        ];

        typeScriptDeps = [
          pkgs.nodejs
        ];

        dotnetDeps = [
          pkgs.dotnet-sdk_8
        ];

      in
      with pkgs;
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkg-config
            openssl
          ] ++ tools
          ++ rustDeps
          ++ typeScriptDeps
          ++ dotnetDeps;

          shellHook = ''
                        	alias c=cargo
                        	alias j=just
                        	alias lg=lazygit
            		'';

          DOTNET_CLI_HOME = "/tmp/.dotnet";
        };
      }
    );
}
