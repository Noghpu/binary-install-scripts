#!/bin/bash

# Latest fish version
VERSION="4.4.0"
ARCH="x86_64" # Change to "aarch64" for ARM64

# Download the standalone binary
curl -LO "https://github.com/fish-shell/fish-shell/releases/download/${VERSION}/fish-${VERSION}-linux-${ARCH}.tar.xz"

# Extract it
tar xf "fish-${VERSION}-linux-${ARCH}.tar.xz"

# Create ~/.local/bin if it doesn't exist
mkdir -p "$HOME/.local/bin"

# Copy fish binary to ~/.local/bin
mv "./fish" "$HOME/.local/bin/"

# Clean up
rm -rf "fish-${VERSION}-linux-${ARCH}.tar.xz"

# Add ~/.local/bin to PATH if not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.bashrc"
  echo "Added ~/.local/bin to PATH in .bashrc"
fi

echo "Fish ${VERSION} installed to ~/.local/bin/fish"
echo "Run 'source ~/.bashrc' or open a new terminal, then type 'fish' to start"
