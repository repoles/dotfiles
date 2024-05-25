# My dotfiles

This directory contains the dotfiles for my system

## Requirements

Ensure you have the following installed on your system

* git
* stow

## Instalation

First, check out the dotfiles repo using `git`

```sh
git clone https://github.com/repoles/dotfiles.git
cd dotfiles
```

then use GNU `stow` to create symlinks

```sh
stow --verbose --target=$HOME */
```
