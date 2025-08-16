{
  description = "Chatbox - Desktop client for ChatGPT, Claude and other LLMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        buildInputs = with pkgs; [
          nodejs_20
          python3
          # Required for native node modules and Electron
          pkg-config
          libsecret
          # Build tools
          git
        ] ++ lib.optionals stdenv.isLinux [
          # Linux-specific dependencies for Electron
          gtk3
          glib
          nss
          nspr
          at-spi2-atk
          cups
          drm
          mesa
          libxkbcommon
          libxss
          libgconf
          xorg.libXext
          xorg.libXfixes
          xorg.libXrandr
          xorg.libXcomposite
          xorg.libXcursor
          xorg.libXdamage
          xorg.libXi
          xorg.libXrender
          xorg.libXtst
          xorg.libXScrnSaver
          xorg.libxcb
          alsa-lib
        ];

        nativeBuildInputs = with pkgs; [
          makeWrapper
          nodePackages.electron
        ];

      in
      {
        packages.default = pkgs.buildNpmPackage rec {
          pname = "chatbox";
          version = "1.0.0";

          src = ./.;

          # You'll need to update this hash after first build attempt
          npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

          inherit buildInputs nativeBuildInputs;

          # Skip electron download as we provide it via nix
          preBuild = ''
            export ELECTRON_SKIP_BINARY_DOWNLOAD=1
          '';

          buildPhase = ''
            npm run build:main
            npm run build:renderer
          '';

          installPhase = ''
            mkdir -p $out/bin $out/share/chatbox

            # Copy application files
            cp -r dist/ $out/share/chatbox/
            cp -r node_modules/ $out/share/chatbox/
            cp package.json $out/share/chatbox/

            # Create wrapper script
            makeWrapper ${pkgs.electron}/bin/electron $out/bin/chatbox \
              --add-flags "$out/share/chatbox/dist/main/main.js" \
              --add-flags "--no-sandbox"

            # Install desktop file if it exists
            if [ -f assets/icon.png ]; then
              mkdir -p $out/share/icons/hicolor/256x256/apps
              cp assets/icon.png $out/share/icons/hicolor/256x256/apps/chatbox.png
            fi
          '';

          meta = with pkgs.lib; {
            description = "Desktop client for ChatGPT, Claude and other LLMs";
            homepage = "https://chatboxai.app/";
            license = licenses.gpl3Only;
            platforms = platforms.linux ++ platforms.darwin;
            maintainers = [ ];
          };
        };

        devShells.default = pkgs.mkShell {
          inherit buildInputs;
          
          shellHook = ''
            echo "Chatbox development environment"
            echo "Node.js version: $(node --version)"
            echo "npm version: $(npm --version)"
            echo ""
            echo "Available commands:"
            echo "  npm install          - Install dependencies"
            echo "  npm run dev          - Start development server"
            echo "  npm run build        - Build the application"
            echo "  npm run package      - Package for current platform"
            echo "  npm run package:all  - Package for all platforms"
          '';
        };

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.default;
          exePath = "/bin/chatbox";
        };
      });
}
