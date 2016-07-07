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
: ${INSTANCE_TYPE:?}
: ${TIMEHOST:?}

sudo apt-get update
sudo apt-get -y install wget make gcc zlib1g-dev libssl-dev ssh ruby # zlibc

wget -O cpi.tgz http://bosh.io/d/github.com/cloudfoundry-incubator/bosh-openstack-cpi-release?v=25
wget -O stemcell.tgz https://d26ekeud912fhb.cloudfront.net/bosh-stemcell/openstack/bosh-stemcell-3232.6-openstack-kvm-ubuntu-trusty-go_agent.tgz

echo "${PRIVATE_KEY}" > cf-validator.rsa_id
chmod 400 cf-validator.rsa_id

erb validator-src/ci/assets/validator.yml.erb > validator.yml

validator-src/validate cpi.tgz stemcell.tgz validator.yml