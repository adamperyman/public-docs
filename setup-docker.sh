#!/bin/bash

# A hacky little setup script to automate the creation of VMs.
# Author: Adam Peryman <adam.peryman@gmail.com>
# Tested on Ubuntu 16.04 LTS

if [ -z ${USER_NAME+x} ]; then
  echo "ENV var USER_NAME is undefined."

  echo -n "Please enter new username: "
  read USER_NAME
fi

if [ -z ${USER_EMAIL+x} ]; then
  echo "ENV var USER_EMAIL is undefined."

  echo -n "Please enter the new user's email: "
  read USER_EMAIL
fi

if [ -z ${USER_PASS+x} ]; then
  echo "ENV var USER_PASS is undefined."

  echo -n "Please enter new password: "
  read USER_PASS
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
    ssh-keygen -t ed25519 -a 100 -N "" -c $USER_EMAIL -f $HOME/.ssh/id_ed25519
  elif [ "$SSH_ENCRYPTION_ALGORITHM" == "rsa" ]; then
    echo "Creating SSH keys for ROOT user using RSA algorithm.."
    ssh-keygen -t rsa -b 4096 -o -a 100 -N "" -c $USER_EMAIL -f $HOME/.ssh/id_rsa
  else
    echo "Unknown SSH_ENCRYPTION_ALGORITHM, defaulting to RSA."
    echo "Creating SSH keys for ROOT user using RSA algorithm.."
    ssh-keygen -t rsa -b 4096 -o -a 100 -N "" -c $USER_EMAIL -f $HOME/.ssh/id_rsa
  fi

  echo "Finished creating SSH keys."
fi

# Install deps.
$apt_update_cmd && $apt_install_cmd whois git apt-utils

# Get password hash.
echo "Creating hashed password.."
HASHED_PASSWORD=$(mkpasswd -m sha-512 $USER_PASS)

if [ -z ${HASHED_PASSWORD+x} ]; then
  echo "Failed to create hashed password.."
  exit 1
fi

echo "Hashed password created successfully."

# Create user.
echo "Creating user: $USER_NAME.."
if useradd -m -p $HASHED_PASSWORD -s /bin/bash $USER_NAME; then
  echo "User: $USER_NAME created successfully."
else
  echo "Failed to create user: $USER_NAME."
  exit 1
fi

echo "Assigning group permissions.."
if usermod -aG sudo $USER_NAME; then
  echo "Successfully assigned $USER_NAME to sudo group."
else
  echo "Failed to assign $USER_NAME to sudo group."
  exit 1
fi

echo "Logging in as $USER_NAME.."
su $USER_NAME
sudo
if [ $? -eq 0 ]; then
  echo "Successfully logged in as $USER_NAME."
else
  echo "Failed to login as $USER_NAME, current user is $USER_NAME."
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

echo "Assigning $USER_NAME to docker group.."
sudo groupadd docker
if sudo usermod -aG docker $USER_NAME; then
  echo "Successfully added $USER_NAME to docker group."
else
  echo "Failed to add $USER_NAME to docker group."
  # Don't need to exit here, investigate manually.
fi

# Setup SSH, use Ed25519 (new) or RSA depending on your needs.
if [ "$SSH_ENCRYPTION_ALGORITHM" == "ed25519" ]; then
  echo "Creating SSH keys using $SSH_ENCRYPTION_ALGORITHM algorithm.."
  ssh-keygen -t ed25519 -a 100 -N "" -c $USER_EMAIL -f $HOME/.ssh/id_ed25519
elif [ "$SSH_ENCRYPTION_ALGORITHM" == "rsa" ]; then
  echo "Creating SSH keys using RSA algorithm.."
  ssh-keygen -t rsa -b 4096 -o -a 100 -N "" -c $USER_EMAIL -f $HOME/.ssh/id_rsa
else
  echo "Unknown SSH_ENCRYPTION_ALGORITHM, defaulting to RSA."
  echo "Creating SSH keys using RSA algorithm.."
  ssh-keygen -t rsa -b 4096 -o -a 100 -N "" -c $USER_EMAIL -f $HOME/.ssh/id_rsa
fi

echo "Finished creating SSH keys."

# Setup Vim.
# Installing vim-gnome is the lazy man's way of ensuring Vim was compiled with the +clipboard flag.
sudo $apt_update_cmd && sudo $apt_install_cmd vim-gnome

# Amix's .vimrc.
if git clone --depth=1 https://github.com/amix/vimrc.git $HOME/.vim_runtime; then
  bash $HOME/.vim_runtime/install_awesome_vimrc.sh

  # AP's custom settings.
  mkdir -p $HOME/dev
  git clone https://github.com/x0bile/vim-settings.git $HOME/dev/vim-settings
  bash $HOME/dev/vim-settings/setup.sh
else
  echo "Failed to get Amix's .vimrc, didn't setup AP's custom settings."
fi

# Output.
echo "You should add the following PUBLIC key to any services that require it, e.g. Github..\n"
cat $HOME/.ssh/id_$SSH_ENCRYPTION_ALGORITHM.pub

echo "We're done here, please logout and back in to refresh user groups for user: $USER_NAME."
echo "Have a wonderful day! :)"
