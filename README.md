# My dotfiles

This directory contains the dotfiles for my system.

## Setup on a fresh macOS

### 1. Clone the repository

```sh
git clone https://github.com/repoles/dotfiles.git ~/Code/Dotfiles
cd ~/Code/Dotfiles
```

### 2. Install [Homebrew](https://brew.sh)

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After installation, follow the instructions printed in the terminal to add Homebrew to your PATH.

### 3. Install stow and create symlinks

```sh
brew install stow
stow --verbose --target=$HOME */
```

### 4. Set up fish as the default shell

```sh
brew install fish
```

Add fish to the list of allowed shells and set it as default:

```sh
echo "$(which fish)" | sudo tee -a /etc/shells
chsh -s "$(which fish)"
```

### 5. Install remaining programs

Open a new terminal (now running fish) and install everything from the Brewfile:

```sh
brew bundle --file=~/Code/Dotfiles/misc/Brewfile --no-upgrade --verbose
```
