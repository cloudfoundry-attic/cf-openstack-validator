# input variables

# access coordinates/credentials
variable "auth_url" {
  description = "Authentication endpoint URL for OpenStack provider (only scheme+host+port, but without path!)"
}

variable "domain_name" {
  description = "OpenStack domain name"
}

variable "user_name" {
  description = "OpenStack pipeline technical user name"
}

variable "password" {
  description = "OpenStack user password"
}

variable "tenant_name" {
  description = "OpenStack project/tenant name"
}

variable "insecure" {
   default = "false"
   description = "SSL certificate validation"
}

variable "name_prefix" {
   default = ""
   description = "Prefix for names of infrastucture components"
}

variable "net_cidr" {
   default = "10.0.1.0/24"
   description = "CIDR of validator subnet"
}

variable "allocation_pool_start" {
  default = "10.0.1.200"
  description = "Allocation pool start"
}

variable "allocation_pool_end" {
  default = "10.0.1.254"
  description = "Allocation pool end"
}

variable "gateway_ip" {
  default= "10.0.1.1"
  description = "Default gateway"
}

variable "cacert_file" {
  default = ""
  description = "CA File"
}

variable "dns_nameservers" {
   description = "list of DNS server IPs"
   type = "list"
}

# external network coordinates
variable "ext_net_name" {
  description = "OpenStack external network name to register floating IP"
}

variable "ext_net_id" {
  description = "OpenStack external network id to create router interface port"
}

# region/zone coordinates
variable "region_name" {
  description = "OpenStack region name"
}

variable "availability_zone" {
  description = "OpenStack availability zone name"
}

variable "openstack_default_key_public_key" {
}

output "validator_net_id" {
  value = "${openstack_networking_network_v2.validator_net.id}"
}

output "validator_floating_ip" {
  value = "${openstack_compute_floatingip_v2.validator_floating_ip.address}"
}

output "openstack_default_key_name" {
  value = "${openstack_compute_keypair_v2.openstack_default_key_name.name}"
}

output "security group" {
  value = "${openstack_networking_secgroup_v2.validator_secgroup.name}"
}
