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

######### GLOBAL ##########
############################
variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "apiserver_alternative_names" {
  description = "subject alternative names for the API Server signing cert."
  default     = []
  type        = list(string)
}

variable "worker_os" {
  description = "OS to run on worker machines"

  # valid choices are:
  # * ubuntu
  # * centos
  default = "ubuntu"
  type    = string
}

variable "ssh_public_key_file" {
  description = "SSH public key file"
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_file" {
  description = "SSH private key file used to access instances"
  default     = ""
}

variable "ssh_agent_socket" {
  description = "SSH Agent socket, default to grab from $SSH_AUTH_SOCK"
  default     = "env:SSH_AUTH_SOCK"
}

variable "subnet_cidr" {
  default     = "192.168.1.0/24"
  description = "OpenStack subnet cidr"
}

variable "external_network_name" {
  description = "OpenStack external network name"
}

variable "subnet_dns_servers" {
  type    = list(string)
  default = ["8.8.8.8", "8.8.4.4"]
}

variable "ipv6" {
  type = object({
    enabled         = bool
    subnetpool      = string
    prefix_length   = number
    dns_nameservers = list(string)
  })
  description = "Enable and configure IPv6."
}

##### CONTROL PLANE ########
############################
variable "control_plane" {
  type = object({
    flavor      = string
    image       = string
    user        = string
    port        = number
    volume_size = number
    volume_type = string
  })
  description = "Control plane configuration."
}

######### BASTION ##########
############################
variable "bastion" {
  type = object({
    user   = string
    image  = string
    flavor = string
    port   = number
  })
  description = "Information about bastion host (only if LBaaS is enabled)"
}

###### LOADBALANCER ########
############################
variable "lb" {
  type = object({
    useLBaaS = bool
    flavor   = string
    image    = string
    user     = string
    port     = number
  })
}

######## WORKERS ###########
############################
variable "worker" {
  # valid choices are:
  # worker.os:
  #   * flatcar
  #   * ubuntu
  #   * centos
  type = object({
    os = string
    image = string
    flavor = string
    replicas = number
  })
  description = "Settings for the initial worker nodes deployed with a MachineDeployment. (0 by default)"
}
