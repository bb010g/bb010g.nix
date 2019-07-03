{ stdenv, rustPlatform, callPackage
, darwin ? null, direnv, nix, which
, pname ? "lorri", version, src, cargoSha256
}:

let
  inherit (stdenv.lib) optionals;
in rustPlatform.buildRustPackage rec {
  inherit pname version;

  inherit src;

  inherit cargoSha256;

  buildInputs = [
    direnv
    nix
    which
  ] ++ optionals stdenv.hostPlatform.isDarwin [
    darwin.cf-private
    darwin.security
    darwin.apple_sdk.frameworks.CoreServices
  ];

  doCheck = !stdenv.isDarwin;

  BUILD_REV_COUNT = src.revCount or 1;
  NIX_PATH = "nixpkgs=${src + "/nix/bogus-nixpkgs"}";
  RUN_TIME_CLOSURE = callPackage (src + "/nix/runtime.nix") {};
  USER = "bogus";

  preConfigure = ''
    source ${src + "/nix/pre-check.sh"}

    # Do an immediate, light-weight test to ensure logged-evaluation
    # is valid, prior to doing expensive compilations.
    nix-build --show-trace ./src/logged-evaluation.nix \
      --arg src ./tests/direnv/basic/shell.nix \
      --arg runTimeClosure "$RUN_TIME_CLOSURE" \
      --no-out-link
  '';

  meta = with stdenv.lib; {
    description = "Your project's nix-env";
    longDescription = ''
      lorri is a nix-shell replacement for project development. lorri is based
      around fast direnv integration for robust CLI and editor integration.

      The project is about experimenting with and improving the developer's
      experience with Nix. A particular focus is managing your project's
      external dependencies, editor integration, and quick feedback.
    '';
    homepage = https://github.com/target/lorri;
    license = with licenses; asl20;
    maintainers = with maintainers; [ bb010g ];
    platforms = platforms.unix;
  };
}
