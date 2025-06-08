let
  fetchFromGitHub  =
    if (builtins ? "fetchTarball")
    then
      { owner, repo, rev, sha256 }: builtins.fetchTarball {
        inherit sha256;
        url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
      }
    else
      (import <nixpkgs> {}).fetchFromGitHub;
  srcFromGithubPin = name: fetchFromGitHub (builtins.fromJSON (builtins.readFile (./nix/pins + "/${name}.json")));
in
let
  default-compiler = import ./nix/default-compiler.nix;
in
let
  nixpkgsSrc       = srcFromGithubPin "nixpkgs";
  clashSrc         = srcFromGithubPin "clash";
  hintSrc          = srcFromGithubPin "hint";
in
let
  pkgs             = (import nixpkgsSrc {}).pkgs;
in
{ compiler         ? default-compiler
, buildFlags       ? []
, clashFromNixpkgs ? false             ## Use a clash.json-pinned version via cabal2nix if false.
                                       ## Ignore that pin and use the nixpkgs version if true.
}:
with pkgs.lib;
let
  ghcOrig          = pkgs.haskell.packages."${compiler}";   # :: nixpkgs/pkgs/development/haskell-modules/make-package-set.nix
in
let
  ghcOverrides =
    ghcVer: new: old:
      with pkgs.haskell.lib;
      ({
        ghc984 =
          {
          };
        ghc9122 =
          {
            Cabal = old.Cabal_3_14_2_0;
            ghc-tcplugins-extra = old.ghc-tcplugins-extra_0_5;
            ghc-typelits-extra = dontCheck old.ghc-typelits-extra;
            ghc-typelits-natnormalise = dontCheck old.ghc-typelits-natnormalise_0_7_11;
          };
      }).${ghcVer};

  clashPkgs =
    let
      clashPkg =
        with pkgs.haskell.lib;
        pkgSet: name:
        overrideCabal (if clashFromNixpkgs
                       then pkgSet.${name}
                       else pkgSet.callCabal2nix name (clashSrc + "/${name}") {})
          (drv: {
            doCheck   = false;
            doHaddock = false;
            jailbreak = true;
          } // optionalAttrs (buildFlags != []) {
            inherit buildFlags;
          });
    in
    pkgSet:
      flip genAttrs (clashPkg pkgSet)
        [ "clash-ghc"
          "clash-lib"
          "clash-prelude"
        ];
in
let
  ghc =
    ghcOrig.override {
      overrides =
        new: old:
        ghcOverrides compiler new old
        // clashPkgs old;
    };

### Attributes available for direct building:
##
##  nix-build -A foo
##
in {
  inherit srcFromGithubPin;
  inherit (ghc) clash-ghc clash-lib clash-prelude;

  "${compiler}" = pkgs.haskell.compiler.${compiler};
  ghc           = pkgs.haskell.compiler.${compiler};

  shell = ghc.shellFor {
    packages    = p: [p.clash-ghc];
    withHoogle  = true;

    ## Extra packages to provide.
    buildInputs =
      with ghc;
      [ cabal-install
        pkgs.jq
      ];
  };
}
