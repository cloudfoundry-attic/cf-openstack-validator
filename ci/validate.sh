#!/bin/bash
set -e -x

: ${AUTH_URL:?}
: ${USERNAME:?}
: ${API_KEY:?}
: ${DOMAIN:?}
: ${PROJECT:?}
: ${DEFAULT_KEY_NAME:?}
: ${NETWORK_ID:?}
: ${FLOATING_IP:?}
: ${PRIVATE_KEY:?}
: ${BOOT_FROM_VOLUME:?}
: ${INSTANCE_TYPE:?}
: ${ROOT_DISK_SIZE:?}

sudo apt-get update
sudo apt-get -y install wget make gcc zlib1g-dev libssl-dev ssh # zlibc

wget -O cpi.tgz http://bosh.io/d/github.com/cloudfoundry-incubator/bosh-openstack-cpi-release?v=25
wget -O stemcell.tgz https://d26ekeud912fhb.cloudfront.net/bosh-stemcell/openstack/bosh-stemcell-3232.6-openstack-kvm-ubuntu-trusty-go_agent.tgz

echo "${PRIVATE_KEY}" > validator-src/cf-validator.rsa_id
chmod 400 validator-src/cf-validator.rsa_id

cat > cpi.json <<EOF
{
  "cloud": {
    "plugin": "openstack",
    "properties": {
      "openstack": {
        "auth_url": "$AUTH_URL",
        "username": "$USERNAME",
        "api_key": "$API_KEY",
        "domain": "$DOMAIN",
        "project": "$PROJECT",
        "default_key_name": "$DEFAULT_KEY_NAME",
        "default_security_groups": ["default"],
        "wait_resource_poll_interval": 5,
        "ignore_server_availability_zone": false,
        "endpoint_type": "publicURL",
        "state_timeout": 300,
        "stemcell_public_visibility": false,
        "connection_options": {
          "ssl_verify_peer": false
        },
        "boot_from_volume": $BOOT_FROM_VOLUME,
        "use_dhcp": true,
        "human_readable_vm_names": true
      },
      "registry": {
        "endpoint": "http://localhost:11111",
        "user": "fake",
        "password": "fake"
      },
      "ntp": [$NTP_SERVER]
    }
  },
  "validator": {
    "network_id": "$NETWORK_ID",
    "floating_ip": "$FLOATING_IP",
    "private_key_name": "cf-validator.rsa_id"
  },
  "cloud_config": {
    "vm_types": [
      { "name": "default",
        "cloud_properties": {
          "instance_type": "$INSTANCE_TYPE",
          "root_disk": {
            "size": $ROOT_DISK_SIZE
          }
        }
      }
    ]
  }
}
EOF

pushd validator-src
./validate ../cpi.tgz ../stemcell.tgz ../cpi.json