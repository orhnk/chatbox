{
  description = "Chatbox development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        # Added: Libraries Electron expects at runtime on NixOS
        electronRuntimeLibs = with pkgs; [
          glib gtk3 gdk-pixbuf pango cairo libdrm mesa libgbm nspr nss
          at-spi2-core at-spi2-atk atk cups dbus expat libnotify libsecret
          libxkbcommon wayland alsa-lib libglvnd zlib openssl systemd
          stdenv.cc.cc.lib
          xorg.libX11 xorg.libXcomposite xorg.libXcursor xorg.libXdamage
          xorg.libXext xorg.libXfixes xorg.libXi xorg.libXrandr xorg.libXrender
          xorg.libXScrnSaver xorg.libXtst xorg.libxcb xorg.libxshmfence
          # Ensure proper font stack for Electron/GTK/Pango
          fontconfig
          freetype
        ];
        electronLDLibraryPath = pkgs.lib.makeLibraryPath electronRuntimeLibs;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs_20
            yarn
            nodePackages.typescript
            nodePackages.ts-node
            git

            # Added: toolchain for node-gyp/native Electron deps
            python3
            pkg-config
            gcc
            gnumake
            libtool
            autoconf
            automake

            # Convenience: electron rebuild tools
            nodePackages.node-gyp
          ];

          shellHook = ''
            echo "Chatbox development environment loaded"
            echo "Node.js version: $(node --version)"
            echo "Yarn version: $(yarn --version)"

            # Ensure node-gyp uses the right toolchain
            export npm_config_python="$(command -v python3)"
            export CC="${pkgs.gcc}/bin/cc"
            export CXX="${pkgs.gcc}/bin/c++"

            # Make npm-installed Electron find required system libs on NixOS
            export LD_LIBRARY_PATH="${electronLDLibraryPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

            # Fontconfig: force a known-good config and avoid host /etc/local.conf
            export FONTCONFIG_FILE="${pkgs.fontconfig}/etc/fonts/fonts.conf"
            export FONTCONFIG_PATH="${pkgs.fontconfig}/etc/fonts"
            # Create a per-shell sysroot with a minimal /etc/fonts/local.conf to prevent parse errors
            _fc_sysroot="$PWD/.dev-fontconfig-sysroot"
            mkdir -p "$_fc_sysroot/etc/fonts"
            if [ ! -s "$_fc_sysroot/etc/fonts/local.conf" ]; then
              cat >"$_fc_sysroot/etc/fonts/local.conf" <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig></fontconfig>
EOF
            fi
            export FONTCONFIG_SYSROOT="$_fc_sysroot"

            # Reduce portal noise in dev (no xdg-desktop-portal service)
            export GTK_USE_PORTAL=0
            export GTK_DIALOGS_USE_PORTAL=0
            _xdg_portal_empty="$PWD/.xdg-portal-empty"
            mkdir -p "$_xdg_portal_empty"
            export XDG_DESKTOP_PORTAL_DIR="$_xdg_portal_empty"

            # Ensure GSettings schemas are discoverable for GTK
            export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

            # Prefer stable software rendering
            export LIBGL_ALWAYS_SOFTWARE=1
            # Make Electron pass reliable software GL flags
            export ELECTRON_EXTRA_LAUNCH_ARGS="--disable-gpu --disable-gpu-compositing --use-gl=swiftshader ''${ELECTRON_EXTRA_LAUNCH_ARGS:-}"

            # Let Electron pick Wayland/X11 automatically
            export ELECTRON_OZONE_PLATFORM_HINT=auto

            # Convenience: run electron-rebuild via npx
            alias electron-rebuild="npx -y electron-rebuild"
          '';
        };
      });
}
