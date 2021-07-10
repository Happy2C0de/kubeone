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

provider "openstack" {
}

data "openstack_networking_network_v2" "external_network" {
  name     = var.external_network_name
  external = true
}

data "openstack_images_image_v2" "worker_image" {
  name        = var.worker.image
}

data "openstack_images_image_v2" "image" {
  name        = var.control_plane.image
}

resource "openstack_compute_keypair_v2" "deployer" {
  name       = "${var.cluster_name}-deployer-key"
  public_key = file(var.ssh_public_key_file)
}

# resource "openstack_compute_servergroup_v2" "control_plane_sg" {
#   name     = "${var.cluster_name}-cp-sg"
#   policies = ["anti-affinity"]
# }

resource "openstack_blockstorage_volume_v3" "control_plane" {
  count = 3
  name        = "cp-root-${count.index}"
  size        = var.control_plane.volume_size
  image_id    = data.openstack_images_image_v2.image.name
  volume_type =  var.control_plane.volume_type
}

resource "openstack_compute_instance_v2" "control_plane" {
  count = 3
  name  = "${var.cluster_name}-cp-${count.index}"

  flavor_name     = var.control_plane.flavor
  key_pair        = openstack_compute_keypair_v2.deployer.name
  security_groups = [openstack_networking_secgroup_v2.securitygroup.name]

  block_device {
    uuid             = openstack_blockstorage_volume_v3.control_plane[count.index].id
    source_type      = "volume"
    destination_type = "volume"
  }

  network {
    port = element(openstack_networking_port_v2.control_plane.*.id, count.index)
  }
  
  # scheduler_hints {
  #   group = openstack_compute_servergroup_v2.control_plane_sg.id
  # }
}

resource "openstack_networking_port_v2" "control_plane" {
  count = 3
  name  = "${var.cluster_name}-control_plane-${count.index}"

  admin_state_up     = "true"
  network_id         = openstack_networking_network_v2.network.id
  security_group_ids = [openstack_networking_secgroup_v2.securitygroup.id]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.subnet.id
    ip_address = cidrhost(var.subnet_cidr, 10 + count.index )
  }
}
