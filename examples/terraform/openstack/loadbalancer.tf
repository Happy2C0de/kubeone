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
#################################### LB ###################################

resource "openstack_lb_loadbalancer_v2" "lb" {
  count         = var.lb.useLBaaS ? 1 : 0
  vip_subnet_id = openstack_networking_subnet_v2.subnet.id
}

resource "openstack_lb_listener_v2" "listener" {
  count           = var.lb.useLBaaS ? 1 : 0
  protocol        = "HTTPS"
  protocol_port   = 6443
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb[0].id

  insert_headers = {
    X-Forwarded-For = "true"
  }
}

resource "openstack_lb_pool_v2" "pool" {
  count       = var.lb.useLBaaS ? 1 : 0
  protocol    = "HTTPS"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.listener[0].id
}

resource "openstack_lb_member_v2" "members" {
  count         = var.lb.useLBaaS ? 3 : 0
  pool_id       = openstack_lb_pool_v2.pool[0].id
  address       = element(openstack_compute_instance_v2.control_plane.*.access_ip_v4, count.index)
  subnet_id     = openstack_networking_subnet_v2.subnet.id
  protocol_port = 6443
}

resource "openstack_networking_port_secgroup_associate_v2" "lb" {
  count   = var.lb.useLBaaS ? 1 : 0
  port_id = openstack_lb_loadbalancer_v2.lb[0].vip_port_id
  security_group_ids = [
    openstack_networking_secgroup_v2.kube_apiserver.id,
  ]
}

resource "openstack_networking_floatingip_v2" "lb" {
  pool = var.external_network_name
}

resource "openstack_networking_floatingip_associate_v2" "lbaas" {
  count       = var.lb.useLBaaS ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.lb.address
  port_id     = openstack_lb_loadbalancer_v2.lb[0].vip_port_id
  
  depends_on = [
    openstack_networking_floatingip_v2.lb,
    openstack_lb_loadbalancer_v2.lb,
    openstack_lb_member_v2.members
  ]
}

##### Loadbalancer without LBaaS #####
######################################
data "openstack_images_image_v2" "lb_image" {
  count = var.lb.useLBaaS ? 0 : 1
  name  = var.lb.image
}

resource "openstack_compute_instance_v2" "lb" {
  count      = var.lb.useLBaaS ? 0 : 1
  name       = "${var.cluster_name}-lb"
  image_name = data.openstack_images_image_v2.lb_image[0].name

  flavor_name     = var.lb.flavor
  key_pair        = openstack_compute_keypair_v2.deployer.name

  network {
    port = openstack_networking_port_v2.lb[0].id
  }

  connection {
    type = "ssh"
    host = openstack_networking_floatingip_v2.lb.address
    user = var.lb.user
  }

  provisioner "remote-exec" {
    script = "${path.module}/gobetween.sh"
  }
}

resource "openstack_networking_port_v2" "lb" {
  count = var.lb.useLBaaS ? 0 : 1
  name  = "${var.cluster_name}-lb"

  admin_state_up     = "true"
  network_id         = openstack_networking_network_v2.network.id
  security_group_ids = [openstack_networking_secgroup_v2.securitygroup.id]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.subnet.id
    ip_address = cidrhost(openstack_networking_subnet_v2.subnet.cidr, 9 )
  }
}

resource "openstack_networking_floatingip_associate_v2" "lb" {
  count       = var.lb.useLBaaS ? 0 : 1
  floating_ip = openstack_networking_floatingip_v2.lb.address
  port_id     = openstack_networking_port_v2.lb[0].id

  depends_on = [
    openstack_networking_floatingip_v2.lb,
    openstack_networking_port_v2.lb
  ]
}

locals {
  rendered_lb_config = templatefile("${path.module}/etc_gobetween.tpl", {
    lb_targets = openstack_compute_instance_v2.control_plane.*.access_ip_v4,
  })
}

resource "null_resource" "lb_config" {
  count    = var.lb.useLBaaS ? 0 : 1
  triggers = {
    cluster_instance_ids = join(",", openstack_compute_instance_v2.control_plane.*.id)
    config               = local.rendered_lb_config
  }

  depends_on = [
    openstack_compute_instance_v2.lb
  ]

  connection {
    host = openstack_networking_floatingip_v2.lb.address
    user = var.lb.user
  }

  provisioner "file" {
    content     = local.rendered_lb_config
    destination = "/tmp/gobetween.toml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/gobetween.toml /etc/gobetween.toml",
      "sudo systemctl restart gobetween",
    ]
  }
}

