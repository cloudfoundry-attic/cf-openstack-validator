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
: ${STATIC_IP:?}
: ${PUBLIC_IMAGE_ID:?}
: ${PRIVATE_KEY:?}
: ${INSTANCE_TYPE:?}
: ${NTP_SERVER:?}
: ${CA_CERT:-""}

sudo apt-get update
sudo apt-get -y install wget make gcc zlib1g-dev libssl-dev ssh ruby # zlibc

wget -O cpi.tgz http://bosh.io/d/github.com/cloudfoundry-incubator/bosh-openstack-cpi-release?v=27
wget -O stemcell.tgz https://d26ekeud912fhb.cloudfront.net/bosh-stemcell/openstack/bosh-stemcell-3262.9-openstack-kvm-ubuntu-trusty-go_agent.tgz

echo "${PRIVATE_KEY}" > cf-validator.rsa_id
chmod 400 cf-validator.rsa_id

erb validator-src/ci/assets/validator.yml.erb > validator.yml
cat validator.yml

mkdir -p extensions
cp validator-src/extensions/dummy_extension_spec.sample.rb extensions/dummy_extension_spec.rb

validator-src/validate cpi.tgz stemcell.tgz validator.yml $(pwd)/target

CONFIG_DRIVE='disk' erb validator-src/ci/assets/validator.yml.erb > validator.yml
cat validator.yml

validator-src/validate cpi.tgz stemcell.tgz validator.yml $(pwd)/target