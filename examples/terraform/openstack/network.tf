/*
Copyright 2019 The KubeOne Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
#################################### Network ###################################
resource "openstack_networking_network_v2" "network" {
  name           = "${var.cluster_name}-cluster"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet" {
  name            = "${var.cluster_name}-cluster"
  network_id      = openstack_networking_network_v2.network.id
  cidr            = var.subnet_cidr
  ip_version      = 4
  dns_nameservers = var.subnet_dns_servers
}

data "openstack_networking_subnetpool_v2" "subnetpool_v6" {
  count = var.ipv6.enabled ? 1 : 0
  name  = var.ipv6.subnetpool
}

resource "openstack_networking_subnet_v2" "subnet_v6" {
  count             = var.ipv6.enabled ? 1 : 0
  name              = "${var.cluster_name}-cluster-v6"
  network_id        = openstack_networking_network_v2.network.id
  ip_version        = 6
  ipv6_ra_mode      = "dhcpv6-stateless"
  ipv6_address_mode = "dhcpv6-stateless"
  subnetpool_id     = data.openstack_networking_subnetpool_v2.subnetpool_v6[0].id
}

resource "openstack_networking_router_v2" "router" {
  name                = "${var.cluster_name}-cluster"
  admin_state_up      = "true"
  external_network_id = data.openstack_networking_network_v2.external_network.id
}

resource "openstack_networking_router_interface_v2" "router_subnet_link" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet.id
}

resource "openstack_networking_router_interface_v2" "router_subnet_link_v6" {
  count     = var.ipv6.enabled ? 1 : 0
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet_v6[0].id
}
