{
  description = "Support for the Unison programming language";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
    unison.url = "github:unisonweb/unison";
    unison.flake = false;
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    unison,
  }: let
    systems = flake-utils.lib.defaultSystems;

    localPackages = pkgs: let
      darwin-security-hack = pkgs.callPackage ./nix/darwin-security-hack.nix {};
    in {
      ucm = pkgs.callPackage ./nix/ucm.nix {inherit darwin-security-hack;};

      prep-unison-scratch = pkgs.callPackage ./nix/prep-unison-scratch {};

      vim-unison = pkgs.vimUtils.buildVimPlugin {
        name = "vim-unison";
        src = unison + "/editor-support/vim";
      };
    };
  in
    flake-utils.lib.eachSystem systems
    (
      system: let
        pkgs = import nixpkgs {inherit system;};
      in {
        packages =
          {default = self.packages.${system}.ucm;} // localPackages pkgs;

        ## Deprecated
        defaultPackage = self.packages.${system}.default;

        formatter = pkgs.alejandra;
      }
    )
    // {
      overlays = {
        default = final: prev: let
          localPkgs = localPackages final;
        in {
          inherit (localPkgs) prep-unison-scratch;

          ## Renamed to replace the `unison-ucm` included in Nixpkgs.
          unison-ucm = localPkgs.ucm;

          vimPlugins = prev.vimPlugins // self.overlays.vim final prev;
        };

        vim = final: prev: {inherit (localPackages final) vim-unison;};
      };

      ## Deprecated
      overlay = self.overlays.default;

      lib = let
        buildUnisonFromTranscript = pkgs:
          pkgs.callPackage ./nix/build-from-transcript.nix {
            inherit (localPackages pkgs) ucm;
          };
      in {
        inherit buildUnisonFromTranscript;

        buildUnisonShareProject = pkgs:
          pkgs.callPackage ./nix/build-share-project.nix {
            buildUnisonFromTranscript = buildUnisonFromTranscript pkgs;
          };
      };
    };
}
