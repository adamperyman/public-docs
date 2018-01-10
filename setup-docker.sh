#!/bin/bash

# A hacky little setup script to automate the creation of VMs.
# Author: Adam Peryman <adam.peryman@gmail.com>
# Tested on Ubuntu 16.04 LTS

if [ -z ${NEW_USER+x} ]; then
  echo "ENV var NEW_USER is undefined."

  echo -n "Please enter new username: "
  read NEW_USER
fi

if [ -z ${NEW_PASSWORD+x} ]; then
  echo "ENV var NEW_PASSWORD is undefined."

  echo -n "Please enter new password: "
  read NEW_PASSWORD
fi

if [ -z ${SSH_ENCRYPTION_ALGORITHM+x} ]; then
  echo "ENV var SSH_ENCRYPTION_ALGORITHM is undefined."

  echo -n "Please enter SHH encryption algorithm (ed25519 or rsa): "
  read SSH_ENCRYPTION_ALGORITHM
fi

apt_switches="-qq -o=Dpkg::Use-Pty=0" # Silence all output except errors.
apt_update_cmd="apt-get $apt_switches update"
apt_install_cmd="apt-get $apt_switches install"

# Setup SSH for root if necessary, use Ed25519 (new) or RSA depending on your needs.
if [ -d "/root/.ssh/" ]; then
  if [ "$SSH_ENCRYPTION_ALGORITHM" == "ed25519" ]; then
    echo "Creating SSH keys for ROOT user using $SSH_ENCRYPTION_ALGORITHM algorithm.."
    ssh-keygen -t ed25519 -a 100 -N "" -f id_ed25519 # Similar complexity to RSA 4096 but significantly smaller.
  elif [ "$SSH_ENCRYPTION_ALGORITHM" == "rsa" ]; then
    echo "Creating SSH keys for ROOT user using RSA algorithm.."
    ssh-keygen -t rsa -b 4096 -o -a 100 -N "" -f id_rsa
  else
    echo "Unknown SSH_ENCRYPTION_ALGORITHM, defaulting to RSA."
    echo "Creating SSH keys for ROOT user using RSA algorithm.."
    ssh-keygen -t rsa -b 4096 -o -a 100 -N "" -f id_rsa
  fi

  echo "Finished creating SSH keys."
fi

# Install deps.
$apt_update_cmd && $apt_install_cmd whois git apt-utils

# Get password hash.
echo "Creating hashed password.."
HASHED_PASSWORD=$(mkpasswd -m sha-512 $NEW_PASSWORD)

if [ -z ${HASHED_PASSWORD+x} ]; then
  echo "Failed to create hashed password.."
  exit 1
fi

echo "Hashed password created successfully."

# Create user.
echo "Creating user: $NEW_USER.."
if useradd -m -p $HASHED_PASSWORD -s /bin/bash $NEW_USER; then
  echo "User: $NEW_USER created successfully."
else
  echo "Failed to create user: $NEW_USER."
  exit 1
fi

echo "Assigning group permissions.."
if usermod -aG sudo $NEW_USER; then
  echo "Successfully assigned $NEW_USER to sudo group."
else
  echo "Failed to assign $NEW_USER to sudo group."
  exit 1
fi

echo "Logging in as $NEW_USER.."
if su $NEW_USER && cd ~; then
  echo "Successfully logged in as $NEW_USER."
else
  echo "Failed to login as $NEW_USER, current user is $NEW_USER."
  exit 1
fi

# Clean up.
apt-get remove docker docker-engine docker.io

# Here we go.
sudo $apt_update_cmd && \
  sudo $apt_install_cmd \
    linux-image-extra-$(uname -r) \
    linux-image-extra-virtual \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

# Docker GPG key
echo "Adding Docker GPG key.."
if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -; then
  echo "Successfully added Docker GPG key."
else
  echo "Failed to add Docker GPG key."
  exit 1
fi

sudo add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

sudo $apt_update_cmd && sudo $apt_install_cmd docker-ce

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

echo "Finished installing docker."

echo "Assigning $NEW_USER to docker group.."
sudo groupadd docker
if sudo usermod -aG docker $NEW_USER; then
  echo "Successfully added $NEW_USER to docker group."
else
  echo "Failed to add $NEW_USER to docker group."
  # Don't need to exit here, investigate manually.
fi

# Setup SSH, use Ed25519 (new) or RSA depending on your needs.
if [ "$SSH_ENCRYPTION_ALGORITHM" == "ed25519" ]; then
  echo "Creating SSH keys using $SSH_ENCRYPTION_ALGORITHM algorithm.."
  ssh-keygen -t ed25519 -a 100 -N "" -f id_ed25519 # Similar complexity to RSA 4096 but significantly smaller.
elif [ "$SSH_ENCRYPTION_ALGORITHM" == "rsa" ]; then
  echo "Creating SSH keys using RSA algorithm.."
  ssh-keygen -t rsa -b 4096 -o -a 100 -N "" -f id_rsa
else
  echo "Unknown SSH_ENCRYPTION_ALGORITHM, defaulting to RSA."
  echo "Creating SSH keys using RSA algorithm.."
  ssh-keygen -t rsa -b 4096 -o -a 100 -N "" -f id_rsa
fi

echo "Finished creating SSH keys."

# Setup Vim.
# Installing vim-gnome is the lazy man's way of ensuring Vim was compiled with the +clipboard flag.
sudo $apt_update_cmd && sudo $apt_install_cmd vim-gnome

# Amix's .vimrc.
if git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime; then
  sh ~/.vim_runtime/install_awesome_vimrc.sh

  # AP's custom settings.
  mkdir -p ~/dev
  git clone https://github.com/x0bile/vim-settings.git ~/dev/vim-settings
  sh ~/dev/vim-settings/setup.sh
else
  echo "Failed to get Amix's .vimrc, didn't setup AP's custom settings."
fi

# Output.
echo "You should add the following PUBLIC key to any services that require it, e.g. Github..\n"
cat ~/.ssh/id_$SSH_ENCRYPTION_ALGORITHM.pub

echo "We're done here, please logout and back in to refresh user groups for user: $NEW_USER."
echo "Have a wonderful day! :)"
