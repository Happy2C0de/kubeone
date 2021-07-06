
# === Variables ===
# Global
cluster_name          = "test"
ssh_public_key_file   = "~/.ssh/id_rsa.pub"
subnet_cidr           = "192.168.1.0/24"
external_network_name = "public"

# IPv6
ipv6 = {
  enabled    = false
  subnetpool = "IPV6_POOL"
}

# Bastion
# Note: only applied if useLBaaS=true
bastion = {
  user   = "ubuntu"
  image  = "Ubuntu Bionic 18.04"
  flavor = "m1.small"
  port   = 22
}

# LoadBalancer Node
lb = {
  useLBaaS = false
  flavor   = "m1.small"
  image    = "Ubuntu Bionic 18.04"
  user     = "ubuntu"
  port     = 22
}

# Control Plane
control_plane = {
  image  = "Ubuntu Bionic 18.04"
  flavor = "m1.medium"
  user   = "ubuntu"
  port   = 22
}

# Workers
worker = {
  os       = "ubuntu"
  image    = "Ubuntu Bionic 18.04"
  flavor   = "m1.large"
  replicas = 1
}