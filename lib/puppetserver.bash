#!/bin/bash -v

export DEBIAN_FRONTEND=noninteractive

# Download deb for puppet repo
tempdeb=$(mktemp /tmp/puppet.XXXXXX.deb) || exit 1
wget https://apt.puppetlabs.com/puppet6-release-focal.deb -O "$tempdeb"
dpkg -i "$tempdeb"

# Update and install puppetserver
apt update && apt -y upgrade
apt install -y puppetserver

$puppet='/opt/puppetlabs/bin/puppet'
$puppetsrv='/opt/puppetlabs/bin/puppetserver'
$puppet resource service puppet ensure=stopped enable=true
$puppet resource service puppetserver ensure=stopped enable=true

# Set FQDN
echo "127.0.1.1 $(hostname).<%DOMAIN%> $(hostname)" >> /etc/hosts

# Puppet conf
$puppet config set server "<%PUPPETSERVER%>.<%DOMAIN%>" --section main
$puppet config set runinterval 600 --section main

# Auto-sign
$puppet config set autosign true --section master
$puppetsrv ca setup

# r10k is nice
$puppet module install puppet-r10k
cat <<EOF > /var/tmp/r10k.pp
class { 'r10k':
  sources => {
    'puppet' => {
      'remote'  => 'https://github.com/norwegiancyberrange/r10k.git',
      'basedir' => '/etc/puppetlabs/code/environments',
      'prefix'  => false,
    },
  },
}
EOF

$puppet apply /var/tmp/r10k.pp
r10k deploy environment -p

# Start puppet services
$puppet resource service puppetserver ensure=running enable=true
$puppet agent --test --waitforcert 10
$puppet resource service puppet ensure=running enable=true
