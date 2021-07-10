# OpenStack Quickstart Terraform configs

The OpenStack Quickstart Terraform configs can be used to create the needed
infrastructure for a Kubernetes HA cluster. Check out the following
[Creating Infrastructure guide][docs-infrastructure] to learn more about how to
use the configs and how to provision a Kubernetes cluster using KubeOne.

## Kubernetes API Server Load Balancing

See the [Terraform loadbalancers in examples document][docs-tf-loadbalancer].

[docs-infrastructure]: https://docs.kubermatic.com/kubeone/master/infrastructure/terraform_configs/
[docs-tf-loadbalancer]: https://docs.kubermatic.com/kubeone/master/advanced/example_loadbalancer/

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| cluster\_name | Name of the cluster | string | n/a | yes |
| control\_plane\_flavor | OpenStack instance flavor for the control plane nodes | string | `"m1.small"` | no |
| external\_network\_name | OpenStack external network name | string | n/a | yes |
| image | image name to use | string | `"Ubuntu 18.04"` | no |
| lb\_flavor | OpenStack instance flavor for the LoadBalancer node | string | `"m1.micro"` | no |
| ssh\_agent\_socket | SSH Agent socket, default to grab from $SSH_AUTH_SOCK | string | `"env:SSH_AUTH_SOCK"` | no |
| ssh\_port | SSH port to be used to provision instances | string | `"22"` | no |
| ssh\_private\_key\_file | SSH private key file used to access instances | string | `""` | no |
| ssh\_public\_key\_file | SSH public key file | string | `"~/.ssh/id_rsa.pub"` | no |
| ssh\_username | SSH user, used only in output | string | `"root"` | no |
| subnet\_cidr | OpenStack subnet cidr | string | `"192.168.1.0/24"` | no |
| subnet\_dns\_servers |  | list | `<list>` | no |
| worker\_flavor | OpenStack instance flavor for the worker nodes | string | `"m1.small"` | no |
| worker\_os | OS to run on worker machines | string | `"ubuntu"` | no |

TODO: Improve Input documentation to the new format.

## Outputs

| Name | Description |
|------|-------------|
| kubeone\_api | kube-apiserver LB endpoint |
| ssh_commands | ssh_commands used to access the control plane nodes while bootstraping the cluster. Support gobetween LB and LBaaS. |
| kubeone\_hosts | Control plane endpoints to SSH to |
| kubeone\_workers | Workers definitions, that will be transformed into MachineDeployment object |

## Usage 
```
terraform init
terraform plan -var-file ./example.tfvars -out .terraform/apply.plan
terraform apply .terraform/apply.plan
```

## IPv6 Support
In order to bootstrap a dual-stack cluster, your underlying Openstack needs to support IPv4 and IPv6 tenant networks. Please check your situation before starting this project.

The whole Terraform manifests are dual-stack compatible and should not require any adjustments.

### Steps to bootstrap IPv4/IPv6 dual-stack cluster.
Note: This was tested with Ubuntu 18.04 & Ubuntu 20.04. Other distros should work as well but might require certain adjustments.

- Adjust your Terraform `.tfvars` file with:
```
# IPv6
ipv6 = {
  enabled    = true
  subnetpool = "IPV6_POOL"
  prefix_length = 112
  dns_nameservers = ["2001:4860:4860::8888"]
}
```
- Please, keep the IPv4 and the IPv6 dns_nameservers <= 3. CoreDNS only allows 3 nameservers and would throw errors.
  - You can assure that by log in to the control plane nodes once they are bootstrapped and run `systemd-resolve --status`. The interface hosting both private IPv4 and the IPv6 should have the configured nameservers. (no more than 3!)
- Run Terraform
```
source .openstackrc # see below
terraform init
terraform plan -var-file ./example.tfvars -out .terraform/apply.plan
terraform apply .terraform/apply.plan
```
- Check that all hosts got an IPv4 & IPv6 address assigned.
```
openstack server list
```
- Configure `kubeone.yaml`:
```
clusterNetwork:
  # Prefixes in the range fd00::/8 have similar characteristics as those of the IPv4 private address ranges: 
  # --> They are not guaranteed to be globally unique!
  podSubnet: "10.244.0.0/16,fd01::/48"
  serviceSubnet: "10.96.0.0/12,fd02::/108"
  cni:
    external: {}
addons:
  # See Calico `./ipv6/adddons/calico-ipv6.yaml`
  enable: true
  path: "./ipv6/addons"
```
- Assure that `versions.kubernetes: >= '1.21.0'`, `--feature-gates="IPv6DualStack=true"` is enabled by default for >= '1.21.0'
- build `kubeone` binary locally (as long as this features where not included within an official release.)
```
cd ../../../
make test
make build
cd examples/terraform/openstack/
```
- Run kubeone:
```
terraform output -json > tf.json
../../../dist/kubeone apply -y -v --manifest kubeone.yaml -t tf.json
```
- After kubeone has finished, you have a dual-stack k8s cluster.
- You can test the installation by applying the provided example:
```
export KUBECONFIG=
kubectl -n kube-system get all -o wide
# Comment out the LoadBalancers accordingly.
kubectl -n default apply -f ./ipv6/example-manifests/nginx-example.yaml
```


## Openstack Required Environment Variables
- Source file: `.openstackrc`
```
export OS_AUTH_URL=
export OS_IDENTITY_API_VERSION=3
export OS_USERNAME=
export OS_PASSWORD=
export OS_PROJECT_NAME=
export OS_REGION_NAME=
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_DOMAIN_NAME=Default
export OS_TENANT_NAME=$OS_PROJECT_NAME
```
