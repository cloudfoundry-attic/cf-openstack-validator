# provider configuration

provider "openstack" {
  auth_url    = "${var.auth_url}"
  user_name   = "${var.user_name}"
  password    = "${var.password}"
  tenant_name = "${var.tenant_name}"
  domain_name = "${var.domain_name}"
  insecure    = "${var.insecure}"
  cacert_file = "${var.cacert_file}"
}

# key pairs

resource "openstack_compute_keypair_v2" "openstack_default_key_name" {
  region     = "${var.region_name}"
  name       = "${var.tenant_name}-validator"
  public_key = "${var.openstack_default_key_public_key}"
}

# networks

resource "openstack_networking_network_v2" "validator_net" {
  region         = "${var.region_name}"
  name           = "validator"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "validator_sub" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.validator_net.id}"
  cidr             = "10.0.1.0/24"
  ip_version       = 4
  name             = "validator_sub"
  allocation_pools = {
    start = "10.0.1.200"
    end   = "10.0.1.254"
  }
  gateway_ip       = "10.0.1.1"
  enable_dhcp      = "true"
  dns_nameservers = ["${compact(split(",",var.dns_nameservers))}"]
}

# router

resource "openstack_networking_router_v2" "default_router" {
  region           = "${var.region_name}"
  name             = "validator-router"
  admin_state_up   = "true"
  external_gateway = "${var.ext_net_id}"
}

resource "openstack_networking_router_interface_v2" "validator_port" {
  region    = "${var.region_name}"
  router_id = "${openstack_networking_router_v2.default_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.validator_sub.id}"
}

# floating ips

resource "openstack_compute_floatingip_v2" "validator_floating_ip" {
  region = "${var.region_name}"
  pool   = "${var.ext_net_name}"
}

resource "openstack_compute_secgroup_v2" "validator_secgroup" {
  region      = "${var.region_name}"
  name        = "validator"
  description = "validator security group"

  # Allow anything from own sec group (Any was not possible)

  rule {
    ip_protocol = "tcp"
    from_port   = "1"
    to_port     = "65535"
    self        = true
  }

  rule {
    ip_protocol = "udp"
    from_port   = "1"
    to_port     = "65535"
    self        = true
  }

  rule {
    ip_protocol = "icmp"
    from_port   = "-1"
    to_port     = "-1"
    self        = true
  }

  rule {
    ip_protocol = "tcp"
    from_port   = "22"
    to_port     = "22"
    cidr        = "0.0.0.0/0"
  }

}
