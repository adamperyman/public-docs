#!/bin/bash

# A hacky little setup script to automate the creation of VMs.
# Author: Adam Peryman <adam.peryman@gmail.com>
# Tested on Ubuntu 16.04 LTS

# Install deps.
apt-get update
apt-get install \
  whois
  git

# Get new user data.
echo -n "Please enter new username: "
read NEW_USER

echo -n "Please enter new password: "
read NEW_PASSWORD

echo -n "Please enter SHH encryption algorithm (ed25519 or rsa): "
read SSH_ENCRYPTION_ALGORITHM

if HASHED_PASSWORD=mkpasswd -m sha-512 $NEW_PASSWORD; then
  echo "Successfully created hashed password.."
else
  echo "Failed to create hashed password.."
  exit 1
fi

# Create user.
echo "Creating user: $NEW_USER.."
if useradd -m -p $HASHED_PASSWORD -s /bin/bash $NEW_USER; then
  echo "User: $NEW_USER created successfully!"
else
  echo "Failed to create user: $NEW_USER."
  exit 1
fi

echo "Assigning group permissions.."
if usermod -aG sudo $NEW_USER; then
  echo "Successfully assigned $NEW_USER to sudo group.."
else
  echo "Failed to assign $NEW_USER to sudo group."
  exit 1
fi

echo "Logging in as $NEW_USER.."
su $NEW_USER && cd ~

echo "Let's just get the password out of the way early.."
sudo

# Get more deps.
echo "Gonna get some packages.."

# Clean up.
apt-get remove docker docker-engine docker.io

# Here we go.
sudo apt-get update
sudo apt-get install \
  linux-image-extra-$(uname -r) \
  linux-image-extra-virtual \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common

# Docker GPG key
echo "Adding Docker GPG key.."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

sudo apt-get update
sudo apt-get install docker-ce

sudo apt-key fingerprint 0EBFCD88
if [ $? -eq 0 ]; then
  echo "Docker installed successfully!"
else
  echo "Failed to get Docker GPG key.."
  exit 1
fi

echo "Installing docker-compose.."

sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

if docker-compose --version; then
  echo "docker-compose installed successfully!"
else
  echo "docker-compose install failed."
  exit 1
fi

echo "Finished installing docker!"

echo "Assigning $NEW_USER to docker group.."
sudo groupadd docker
sudo usermod -aG docker $NEW_USER

# Setup SSH, use Ed25519 (new) or RSA depending on your needs.
if [ "$SSH_ENCRYPTION_ALGORITHM" == "ed25519" ]; then
  echo "Creating SSH keys using $SSH_ENCRYPTION_ALGORITHM algorithm.."
  ssh-keygen -t ed25519 -a 100 -N "" -f id_ed25519 # Similar complexity to RSA 4096 but significantly smaller.
else
  echo "Creating SSH keys using RSA algorithm.."
  ssh-keygen -t rsa -b 4096 -o -a 100 -N "" -f id_rsa
fi

# Setup Vim.
sudo apt-get update
sudo apt-get install vim-gnome # Lazy man's way of ensuring Vim was compiled with the +clipboard flag.

# Amix's .vimrc.
if git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime; then
  sh ~/.vim_runtime/install_awesome_vimrc.sh

  # AP's custom settings.
  mkdir -p ~/dev
  git clone https://github.com/x0bile/vim-settings.git
  sh ~/dev/vim-settings/setup.sh
else
  echo "Failed to get Amix's .vimrc, didn't setup AP's custom settings."
  # Probably don't need to fail out here.
fi

# Output.
echo "You should add the following PUBLIC key to any services that require it, e.g. Github..\n"
cat ~/.ssh/id_$SSH_ENCRYPTION_ALGORITHM.pub

echo "We're done here, please logout and back in to refresh user groups for user: $NEW_USER."
echo "Have a wonderful day! :)"
