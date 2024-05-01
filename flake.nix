{
  description = "Support for the Unison programming language";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-23.11";
    flake-utils.url = "github:numtide/flake-utils";
    unison = {
      flake = false;
      url = "github:unisonweb/unison";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    unison,
  }: let
    systems = flake-utils.lib.defaultSystems;

    localPackages = final: let
      darwin-security-hack = final.callPackage ./nix/darwin-security-hack.nix {};
    in {
      ucm = final.callPackage ./nix/ucm.nix {inherit darwin-security-hack;};

      buildUnisonFromTranscript = final.callPackage ./nix/build-from-transcript.nix {};

      buildUnisonShareProject = final.callPackage ./nix/build-share-project.nix {};

      prep-unison-scratch = final.callPackage ./nix/prep-unison-scratch {};

      vim-unison = final.vimUtils.buildVimPlugin {
        name = "vim-unison";
        src = unison + "/editor-support/vim";
      };
    };
  in
    {
      overlays = {
        default = final: prev: let
          localPkgs = localPackages final;
        in {
          inherit
            (localPkgs)
            buildUnisonFromTranscript
            buildUnisonShareProject
            prep-unison-scratch
            ;

          ## This is the name `ucm` already has in Nixpkgs.
          unison-ucm = localPkgs.ucm;

          vimPlugins = prev.vimPlugins // self.overlays.vim final prev;
        };

        vim = final: prev: {inherit (localPackages final) vim-unison;};
      };

      ## Deprecated
      overlay = self.overlays.default;
    }
    // flake-utils.lib.eachSystem systems
    (
      system: let
        pkgs = import nixpkgs {inherit system;};
      in {
        packages =
          {
            default = self.packages.${system}.ucm;
          }
          // localPackages pkgs;

        ## Deprecated
        defaultPackage = self.packages.${system}.default;

        formatter = pkgs.alejandra;
      }
    );
}
