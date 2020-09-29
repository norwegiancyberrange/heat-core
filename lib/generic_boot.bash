#!/bin/bash -v

export DEBIAN_FRONTEND=noninteractive

# These will be replace by openstack heat magic
DOMAIN='<%DOMAIN%>'
PUPPETSERVER='<%PUPPETSERVER%>'

# Download deb for puppet repo
tempdeb=$(mktemp /tmp/puppet.XXXXXX.deb) || exit 1
wget https://apt.puppetlabs.com/puppet6-release-focal.deb -O "$tempdeb"
dpkg -i "$tempdeb"

# Update and install puppetserver
apt update && apt -y upgrade
apt install -y puppet-agent

# Set FQDN
echo "127.0.1.1 $(hostname).$DOMAIN $(hostname)" >> /etc/hosts

# Configure puppet agent
puppet='/opt/puppetlabs/bin/puppet'
$puppet config set server "$PUPPETSERVER.$DOMAIN" --section main
$puppet config set runinterval 600 --section main
$puppet resource service puppet ensure=running enable=true
