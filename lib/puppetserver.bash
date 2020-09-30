#!/bin/bash -v

export DEBIAN_FRONTEND=noninteractive

# These will be replace by openstack heat magic
DOMAIN='<%DOMAIN%>'
PUPPETSERVER='<%PUPPETSERVER%>'
ENVIRONMENT='<%ENVIRONMENT%>'

# Download deb for puppet repo
tempdeb=$(mktemp /tmp/puppet.XXXXXX.deb) || exit 1
wget https://apt.puppetlabs.com/puppet6-release-focal.deb -O "$tempdeb"
dpkg -i "$tempdeb"

# Update and install puppetserver
apt update && apt -y upgrade
apt install -y puppetserver

puppet='/opt/puppetlabs/bin/puppet'
puppetsrv='/opt/puppetlabs/bin/puppetserver'
$puppet resource service puppet ensure=stopped enable=true
$puppet resource service puppetserver ensure=stopped enable=true

# Set FQDN
echo "127.0.1.1 $(hostname).$DOMAIN $(hostname)" >> /etc/hosts

# Puppet conf
$puppet config set server "$PUPPETSERVER.$DOMAIN" --section main
$puppet config set runinterval 600 --section main
$puppet config set environment $ENVIRONMENT --section agent

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

# Do some hiera-conf
cat <<EOF > /etc/puppetlabs/puppet/hiera.yaml
---
# Hiera 5 Global configuration file

version: 5

defaults:
  datadir: data
  data_hash: yaml_data

hierarchy:
 - name: "Per-Node data"
   path: "nodes/%{trusted.certname}.yaml"
 - name: "Global data"
   glob: "*.yaml"
EOF

mkdir -p /etc/puppetlabs/puppet/data/nodes
ln -s /etc/puppetlabs/puppet/data /root/hieradata

cat <<EOF > /etc/puppetlabs/puppet/data/common.yaml
---
profile::puppet::environment: '$ENVIRONMENT'
profile::puppet::hostname: '$PUPPETSERVER.$DOMAIN'
profile::networking::searchdomain: '$DOMAIN'
profile::ntp::servers:
  - 'ntp.justervesenet.no'
  - 'ntp.se'
  - 'ntp.ntnu.no'
EOF

cat <<EOF > /etc/puppetlabs/puppet/data/packages.yaml
---
profile::baseconfig::packages:
 - 'apt-transport-https'
 - 'atop'
 - 'bc'
 - 'build-essential'
 - 'curl'
 - 'fio'
 - 'git'
 - 'gdisk'
 - 'htop'
 - 'iotop'
 - 'iperf3'
 - 'jq'
 - 'locate'
 - 'man-db'
 - 'ncdu'
 - 'pwgen'
 - 'screen'
 - 'software-properties-common'
 - 'sysstat'
 - 'tcpdump'
 - 'vim'
EOF

# Start puppet services
$puppet resource service puppetserver ensure=running enable=true
$puppet agent --test --waitforcert 10
$puppet resource service puppet ensure=running enable=true
