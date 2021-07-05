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

output "kubeone_api" {
  description = "kube-apiserver LB endpoint"

  value = {
    endpoint = openstack_networking_floatingip_v2.lb.address
    apiserver_alternative_names = var.apiserver_alternative_names
  }
}

output "ssh_commands" {
  value = var.lb.useLBaaS ? formatlist("ssh -J ${var.bastion.user}@${openstack_networking_floatingip_v2.bastion[0].address}:${var.bastion.port} ${var.control_plane.user}@%s -p ${var.control_plane.port}", openstack_compute_instance_v2.control_plane.*.access_ip_v4) : formatlist("ssh -J ${var.lb.user}@${openstack_networking_floatingip_v2.lb.address}:${var.lb.port} ${var.control_plane.user}@%s -p ${var.control_plane.port}", openstack_compute_instance_v2.control_plane.*.access_ip_v4)
}

output "kubeone_hosts" {
  description = "Control plane endpoints to SSH to"

  value = {
    control_plane = {
      cluster_name         = var.cluster_name
      cloud_provider       = "openstack"
      private_address      = openstack_compute_instance_v2.control_plane.*.access_ip_v4
      hostnames            = openstack_compute_instance_v2.control_plane.*.name
      ssh_agent_socket     = var.ssh_agent_socket
      ssh_port             = var.control_plane.port
      ssh_private_key_file = var.ssh_private_key_file
      ssh_user             = var.control_plane.user
      bastion              = var.lb.useLBaaS ? openstack_networking_floatingip_v2.bastion[0].address : openstack_networking_floatingip_v2.lb.address
      bastion_port         = var.lb.useLBaaS ? var.bastion.port : var.lb.port
      bastion_user         = var.lb.useLBaaS ? var.bastion.user : var.lb.user
    }
  }
}

output "kubeone_workers" {
  description = "Workers definitions, that will be transformed into MachineDeployment object"

  value = {
    # following outputs will be parsed by kubeone and automatically merged into
    # corresponding (by name) worker definition
    "${var.cluster_name}-pool1" = {
      replicas = var.worker.replicas
      providerSpec = {
        sshPublicKeys   = [file(var.ssh_public_key_file)]
        operatingSystem = var.worker.os
        operatingSystemSpec = {
          distUpgradeOnBoot = false
        }
        cloudProviderSpec = {
          # provider specific fields:
          # see example under `cloudProviderSpec` section at:
          # https://github.com/kubermatic/machine-controller/blob/master/examples/openstack-machinedeployment.yaml
          image          = data.openstack_images_image_v2.worker_image.name
          flavor         = var.worker.flavor
          securityGroups = [openstack_networking_secgroup_v2.securitygroup.name]
          network        = openstack_networking_network_v2.network.name
          subnet         = openstack_networking_subnet_v2.subnet.name
          floatingIpPool = var.external_network_name
          # Optional: If set, the rootDisk will be a volume.
          # Otherwise, the rootDisk will be on ephemeral storage and its size will
          # be derived from the flavor
          # rootDiskSizeGB = 50
          # Optional: limit how many volumes can be attached to a node
          nodeVolumeAttachLimit = 25
          instanceReadyCheckTimeout = "2m"
          tags = {
            "${var.cluster_name}-workers" = "pool1"
          }
        }
      }
    }
  }
}
