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
#################################### BASTION ###################################

data "openstack_images_image_v2" "bastion_image" {
  count       = var.lb.useLBaaS ? 1 : 0
  name        = var.bastion.image
  most_recent = true
}

resource "openstack_networking_port_v2" "bastion" {
  count = var.lb.useLBaaS ? 1 : 0
  name  = "${var.cluster_name}-bastion"

  admin_state_up     = "true"
  network_id         = openstack_networking_network_v2.network.id
  security_group_ids = [openstack_networking_secgroup_v2.securitygroup.id]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.subnet.id
    ip_address = cidrhost(openstack_networking_subnet_v2.subnet.cidr, 9 )
  }
}

resource "openstack_networking_floatingip_v2" "bastion" {
  count = var.lb.useLBaaS ? 1 : 0
  pool  = var.external_network_name
}

resource "openstack_networking_floatingip_associate_v2" "bastion" {
  count       = var.lb.useLBaaS ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.bastion[0].address
  port_id     = openstack_networking_port_v2.bastion[0].id

  depends_on = [
    openstack_networking_floatingip_v2.bastion,
    openstack_networking_port_v2.bastion,
    # Assure that assignemnt is not too early, wait until bastion is created.
    openstack_compute_instance_v2.bastion
  ]
}

resource "openstack_compute_instance_v2" "bastion" {
  count      = var.lb.useLBaaS ? 1 : 0
  name       = "${var.cluster_name}-bastion"
  image_name = data.openstack_images_image_v2.bastion_image[0].name

  flavor_name     = var.bastion.flavor
  key_pair        = openstack_compute_keypair_v2.deployer.name
  security_groups = [openstack_networking_secgroup_v2.securitygroup.name]

  network {
    port = openstack_networking_port_v2.bastion[0].id
  }

  connection {
    type = "ssh"
    host = openstack_networking_floatingip_v2.bastion[0].address
    user = var.bastion.user
  }
}
