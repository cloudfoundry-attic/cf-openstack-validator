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
  name       = "${var.name_prefix}${var.tenant_name}-validator"
  public_key = "${var.openstack_default_key_public_key}"
}

# networks

resource "openstack_networking_network_v2" "validator_net" {
  region         = "${var.region_name}"
  name           = "${var.name_prefix}validator"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "validator_sub" {
  region           = "${var.region_name}"
  network_id       = "${openstack_networking_network_v2.validator_net.id}"
  cidr             = "${var.net_cidr}"
  ip_version       = 4
  name             = "${var.name_prefix}validator_sub"
  allocation_pools = {
    start = "${var.allocation_pool_start}"
    end = "${var.allocation_pool_end}"
  }
  gateway_ip       = "${var.gateway_ip}"
  enable_dhcp      = "true"
  dns_nameservers = "${var.dns_nameservers}"
}

# router

resource "openstack_networking_router_v2" "default_router" {
  region           = "${var.region_name}"
  name             = "${var.name_prefix}validator-router"
  admin_state_up   = "true"
  external_network_id = "${var.ext_net_id}"
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

resource "openstack_networking_secgroup_v2" "validator_secgroup" {
  region      = "${var.region_name}"
  name        = "${var.name_prefix}validator"
  description = "validator security group"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_1" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  remote_group_id = "${openstack_networking_secgroup_v2.validator_secgroup.id}"
  security_group_id = "${openstack_networking_secgroup_v2.validator_secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_2" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "icmp"
  remote_group_id = "${openstack_networking_secgroup_v2.validator_secgroup.id}"
  security_group_id = "${openstack_networking_secgroup_v2.validator_secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_3" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"
  port_range_min = 22
  port_range_max = 22
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.validator_secgroup.id}"
}

