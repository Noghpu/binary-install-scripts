#!/usr/bin/env fish
# Install the latest git-delta (dandavison/delta) from GitHub releases into ~/.local/bin.

set -l repo dandavison/delta
set -l api_url "https://api.github.com/repos/$repo/releases/latest"
set -l install_dir ~/.local/bin

mkdir -p $install_dir

# Fetch latest version tag ("version" is reserved in fish, so use "ver")
echo "Fetching latest release info..."
set -l ver (curl -sL $api_url | string match -r '"tag_name":\s*"([^"]+)"' | tail -1)

if test -z "$ver"
    echo "Error: could not determine latest version." >&2
    exit 1
end

echo "Latest version: $ver"

# Detect OS and architecture → pick release target triple
set -l os (uname -s)
set -l arch (uname -m)

# Declare target before the switch so it's visible after
set -l target

switch "$os/$arch"
    case Linux/x86_64
        set target x86_64-unknown-linux-gnu
    case Linux/aarch64
        set target aarch64-unknown-linux-gnu
    case Darwin/arm64
        set target aarch64-apple-darwin
    case Darwin/x86_64
        set target x86_64-apple-darwin
    case '*'
        echo "Unsupported platform: $os/$arch" >&2
        exit 1
end

set -l tar_url "https://github.com/$repo/releases/download/$ver/delta-$ver-$target.tar.gz"
set -l tmpdir (mktemp -d /tmp/git-delta-XXXXXX)

echo "Downloading $tar_url..."
curl -fSL -o "$tmpdir/delta.tar.gz" "$tar_url"

if test $status -ne 0
    echo "Error: download failed." >&2
    rm -rf $tmpdir
    exit 1
end

tar xzf "$tmpdir/delta.tar.gz" -C $tmpdir --strip-components=1

install -m 755 "$tmpdir/delta" "$install_dir/delta"
rm -rf $tmpdir

# Ensure ~/.local/bin is in PATH
if not contains $install_dir $PATH
    echo "Warning: $install_dir is not in your \$PATH."
    echo "Add it with:  fish_add_path $install_dir"
end

# Verify
if command -q delta
    echo "Installed:" (delta --version)
else if test -x "$install_dir/delta"
    echo "Installed:" ($install_dir/delta --version)
    echo "Run 'fish_add_path $install_dir' to make it available as 'delta'."
else
    echo "Error: delta not found after installation." >&2
    exit 1
end
