{ pkgs ? import <nixpkgs> { }, lib ? pkgs.lib
, ciHelperPkgs ?
  import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/" +
      "7815c86c104a99417db844791dcda34fe7a7965f.tar.gz";
    sha256 = "0k6ws2b2b6vrvq2g5h8fi8qscb0wk0wy097cnf36f9acd126k43j";
  }) { }
}:

let
  lib' = lib;
  inherit (lib') versionOlder;
  applyIf = f: p: x: if p x then f x else x;
  applyIf' = f: p: x: if p then f x else x;

  break = p: p.overrideAttrs (o: { meta = o.meta // { broken = true; }; });
  breakIf = applyIf break;
  breakIf' = applyIf' break;

  min-cargo-vendor = "0.1.23";
  packageOlder = p: v: versionOlder (lib'.getVersion p) v;
  cargoVendorTooOld = cargo-vendor: packageOlder cargo-vendor min-cargo-vendor;
  needsNewCargoVendor = p: breakIf' (cargoVendorTooOld p);
  needsNewCargoVendor' = needsNewCargoVendor pkgs.cargo-vendor;

  baseNameOf' = p: let p' = builtins.baseNameOf p; in
    if lib'.isStorePath p then (builtins.substring 32 (-1) p') else p';
in rec {
  lib = import ./lib { inherit pkgs; }; # functions
  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays

  # # applications

  # ## applications.graphics

  xcolor = needsNewCargoVendor'
    (pkgs.callPackage ./pkgs/applications/graphics/xcolor { });

  # ## applications.misc

  finalhe = pkgs.libsForQt5.callPackage ./pkgs/applications/misc/finalhe {
    buildPackages = pkgs.buildPackages.libsForQt5.callPackage ({
      pkgconfig, qmake, qttools
    } @ args: args) { };
  };

  qcma = pkgs.libsForQt5.callPackage ./pkgs/applications/misc/qcma {
    inherit libvitamtp;
    buildPackages = pkgs.buildPackages.libsForQt5.callPackage ({
      pkgconfig, qmake, qttools
    } @ args: args) { };
  };

  st-bb010g-unstable = ((st-unstable.overrideAttrs (o: rec {
    name = "${pname}-${version}";
    pname = "st-bb010g-unstable";
    version = "2019-05-04";
  })).override {
    conf = lib'.readFile ./pkgs/applications/misc/st/config.h;
    patches = [
      ./pkgs/applications/misc/st/bold-is-not-bright.diff
      ./pkgs/applications/misc/st/scrollback.diff
      ./pkgs/applications/misc/st/vertcenter.diff
    ];
  });

  st-unstable = pkgs.st.overrideAttrs (o: rec {
    name = "${pname}-${version}";
    pname = "st-unstable";
    version = "2019-04-04";
    src = pkgs.fetchgit {
      url = "https://git.suckless.org/st";
      rev = "f1546cf9c1f9fc52d26dbbcf73210901e83c7ecf";
      sha256 = "1hgs7q894bzh7gg6mx41dwf3csq9kznc8wp1g9r60v9r37hgbzn7";
    };
  });

  # ## applications.networking

  ipscan = (pkgs.callPackage ./pkgs/applications/networking/ipscan {
    swt = swt_4_6;
  }).overrideAttrs (o: {
    meta = if !(swt_4_6.meta.broken or false) then o.meta else
      o.meta // { broken = true; };
  });

  # ### applications.networking.p2p

  broca-unstable = pkgs.python3Packages.callPackage
    ./pkgs/applications/networking/p2p/broca { };

  receptor-unstable = pkgs.callPackage
    ./pkgs/applications/networking/p2p/receptor { };

  synapse-bt = needsNewCargoVendor'
    (pkgs.callPackage ./pkgs/applications/networking/p2p/synapse-bt {
      inherit (pkgs.darwin.apple_sdk.frameworks) Security;
    });

  # # development

  # ## development.libraries

  # ### development.libraries.java

  swt_4_6 = pkgs.swt.overrideAttrs (o: let
    inherit (pkgs) fetchzip stdenv;
    platformMap = {
      "x86_64-linux" =
        { platform = "gtk-linux-x86_64";
          sha256 = "1kdlnm1q0q3615nw56fwbck4h95mvyq8vja5ds2b60an84fpix3f"; };
      "i686-linux" =
        { platform = "gtk-linux-x86";
          sha256 = "0jmx1h65wqxsyjzs64i2z6ryiynllxzm13cq90fky2qrzagcw1ir"; };
      "x86_64-darwin" =
        { platform = "cocoa-macosx-x86_64";
          sha256 = "0h9ws9fr85zdi2b23qwpq5074pphn54izg8h6hyvn6xby7l5r9ly"; };
    };

    metadata = assert platformMap ? ${stdenv.hostPlatform.system};
      platformMap.${stdenv.hostPlatform.system};
  in rec {
    version = "4.6";
    fullVersion = "${version}-201606061100";

    src = fetchzip {
      url = "http://archive.eclipse.org/eclipse/downloads/drops4/" +
        "R-${fullVersion}/${o.pname}-${version}-${metadata.platform}.zip";
      sha256 = metadata.sha256;
      stripRoot = false;
      extraPostFetch = ''
        mkdir "$unpackDir"
        cd "$unpackDir"

        renamed="$TMPDIR/src.zip"
        mv "$out/src.zip" "$renamed"
        unpackFile "$renamed"
        rm -r "$out"

        mv "$unpackDir" "$out"
      '';
    };

    meta = if o ? pname then o.meta else (o.meta // { broken = true; });
  });

  libvitamtp = libvitamtp-codestation;

  # ### development.libraries.libvitamtp

  libvitamtp-codestation = pkgs.callPackage
    ./pkgs/development/libraries/libvitamtp/codestation.nix { };

  # ### development.libraries.libvitamtp.yifanlu

  libvitamtp-yifanlu = libvitamtp-yifanlu-stable;

  libvitamtp-yifanlu-stable = pkgs.callPackage
    ./pkgs/development/libraries/libvitamtp/yifanlu/stable.nix { };

  libvitamtp-yifanlu-unstable = pkgs.callPackage
    ./pkgs/development/libraries/libvitamtp/yifanlu/unstable.nix { };

  # ## development.python-modules

  pythonPackageOverrides = self: super: {
    namedlist = super.namedList or
      (super.callPackage ./pkgs/development/python-modules/namedlist { });
    wpull = self.callPackage ./pkgs/development/python-modules/wpull { };
  };

  wpull = (pkgs.python36.override {
    packageOverrides = pythonPackageOverrides;
  }).pkgs.wpull;

  # ## development.tools

  # ### development.tools.misc

  # pince = pkgs.callPackage ./pkgs/development/tools/misc/pince { };

  # # tools

  # ## tools.compression

  lz4json = pkgs.callPackage ./pkgs/tools/compression/lz4json { };

  mozlz4-tool = needsNewCargoVendor'
    (pkgs.callPackage ./pkgs/tools/compression/mozlz4-tool { });

  vita-pkg2zip = vita-pkg2zip-unstable;

  # ### tools.compression.vita-pkg2zip

  vita-pkg2zip-stable = pkgs.callPackage
    ./pkgs/tools/compression/vita-pkg2zip/stable.nix { };
  vita-pkg2zip-unstable = pkgs.callPackage
    ./pkgs/tools/compression/vita-pkg2zip/unstable.nix { };

  # ## tools.misc

  lorri = lorri-rolling;

  nur-ci-helper = let pkgs = ciHelperPkgs; in (pkgs.haskellPackages.override {
    overrides = self: super: {
      pangraph = pkgs.haskell.lib.overrideCabal super.pangraph (drv: {
        version = "0.3.0";
        # https://github.com/tuura/pangraph/pull/40
        src = pkgs.fetchFromGitHub {
          owner = "tuura";
          repo = "pangraph";
          rev = "e9cb33d9c50ec5980a7cc13d2fb8a67eca127274";
          sha256 = "16qdclvdqmlycjrpm8hvp1142vz0m8v2f39ynhrppcabyz855bpr";
        };
        broken = false;
      });
    };
  }).callPackage ./pkgs/tools/misc/nur-ci-helper { };

  psvimgtools = pkgs.callPackage ./pkgs/tools/misc/psvimgtools { };
  # TODO: needs arm-vita-eabi host
  # psvimgtools-dump_partials = pkgs.callPackage
  #   ./pkgs/tools/misc/psvimgtools/dump_partials.nix { };

  # ### tools.misc.lorri

  lorri-rolling = breakIf' (cargoVendorTooOld pkgs.cargo-vendor)
    (pkgs.callPackage ./pkgs/tools/misc/lorri/rolling.nix { });
  lorri-unstable = breakIf' (cargoVendorTooOld pkgs.cargo-vendor)
    (pkgs.callPackage ./pkgs/tools/misc/lorri/unstable.nix { });

  # ## tools.networking

  mosh-unstable = pkgs.mosh.overrideAttrs (o: rec {
    name = "${pname}-${version}";
    pname = "mosh-unstable";
    version = "2019-01-04";
    src = pkgs.fetchFromGitHub {
      owner = "mobile-shell";
      repo = "mosh";
      rev = "c3a2756065a0fb04cfd2681280123b362d862a5e";
      sha256 = "1g4ncphw0hkvswy4jw546prqg3kifc600zjzdlpxdbafa2yyq34v";
    };
  });

  # ## tools.security

  # bitwarden-desktop = pkgs.callPackage
  #   ./pkgs/tools/security/bitwarden/desktop { };

  # ## tools.text

  dwdiff = pkgs.callPackage ./pkgs/tools/text/dwdiff { };
  ydiff = pkgs.pythonPackages.callPackage ./pkgs/tools/text/ydiff { };
}

# vim:et:sw=2:tw=78
