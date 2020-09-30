# heat-core
Openstack Heat Teamplates for creating base infrastructure

## Howto
Start stack with
`openstack stack create -e <environment-file>.yaml -t ncr-top.yaml <stack-name>`

Your environment file has to include at least the following parameters:
```yaml
parameters:
  admin_networks_v4: "x.x.x.x/nn,y.y.y.y/nn"
  admin_networks_v6: "2001:DB8::/32"
  domain: <fqdn for your domain>
  key_name: <name of a keypair>
  ipv6_subnetpool: <ID of the default IPv6 subnet pool>
  public_net: <name of floating IP pool>
```
