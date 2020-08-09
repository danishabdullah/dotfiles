#!/usr/bin/env bash

# Install command-line tools using Homebrew.

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Save Homebrew’s installed location.
BREW_PREFIX=$(brew --prefix)

# Install GNU core utilities (those that come with macOS are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils
ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

# Install some other useful utilities like `sponge`.
brew install moreutils
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils
# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed --with-default-names
# Install a modern version of Bash.
brew install bash
brew install bash-completion2

# Switch to using brew-installed bash as default shell
if ! fgrep -q "${BREW_PREFIX}/bin/bash" /etc/shells; then
  echo "${BREW_PREFIX}/bin/bash" | sudo tee -a /etc/shells;
  chsh -s "${BREW_PREFIX}/bin/bash";
fi;

# Install `wget` with IRI support.
brew install wget --with-iri

# Install GnuPG to enable PGP-signing commits.
brew install gnupg

# Install more recent versions of some macOS tools.
brew install vim --with-override-system-vi
brew install grep
brew install openssh
brew install screen

# Install font tools.
brew tap bramstein/webfonttools
brew install sfnt2woff
brew install sfnt2woff-zopfli
brew install woff2

# Install some CTF tools; see https://github.com/ctfs/write-ups.
brew install aircrack-ng
brew install bfg
brew install binutils
brew install binwalk
brew install cifer
brew install dex2jar
brew install dns2tcp
brew install fcrackzip
brew install foremost
brew install hashpump
brew install hydra
brew install john
brew install knock
brew install netpbm
brew install nmap
brew install pngcheck
brew install socat
brew install sqlmap
brew install tcpflow
brew install tcpreplay
brew install tcptrace
brew install ucspi-tcp # `tcpserver` etc.
brew install xpdf
brew install xz

# Install other useful binaries.
brew install ack
#brew install exiv2
brew install git
brew install git-lfs
brew install gs
brew install imagemagick --with-webp
brew install lua
brew install lynx
brew install p7zip
brew install pigz
brew install pv
brew install rename
brew install rlwrap
brew install ssh-copy-id
brew install tree
brew install vbindiff
brew install zopfli

# more useful things
brew install aria2
brew install awscli
brew install docker
brew install gcc
brew install git
brew install git-flow
brew install httpie
brew install hugo
brew install ncdu
brew install node@12
brew install packer
brew install rbenv
brew install terraform
brew install youtube-dl


# Casks

# brew cask install amazon-music
# brew cask install android-studio
# brew cask install colloquy
brew cask install docker
# brew cask install epic-games
brew cask install figma
brew cask install firefox
brew cask install flutter
# brew cask install freesmug-chromium
brew cask install google-chrome
# brew cask install insomnia
brew cask install iterm2
# brew cask install linkliar
brew cask install microsoft-edge
brew cask install microsoft-teams
brew cask install miniconda
brew cask install onedrive
brew cask install origin
brew cask install postgres
brew cask install postman
# brew cask install private-internet-access
brew cask install pycharm-ce
brew cask install qbittorrent
brew cask install sequel-pro
brew cask install signal
brew cask install skype
brew cask install slack
brew cask install spotify
brew cask install steam
brew cask install sublime-merge
brew cask install sublime-text
brew cask install telegram
brew cask install transmission
# brew cask install vagrant
# brew cask install virtualbox
brew cask install visual-studio-code
brewe cask install valentina-studio
brew cask install vlc
brew cask install vyprvpn
brew cask install whatsapp

# Remove outdated versions from the cellar.
brew cleanup
