#!/bin/bash
set -e -x

: ${AUTH_URL:?}
: ${USERNAME:?}
: ${API_KEY:?}
: ${DOMAIN:?}
: ${PROJECT:?}
: ${PROJECT_ID:?}
: ${DEFAULT_KEY_NAME:?}
: ${STATIC_IP:?}
: ${PRIVATE_KEY:?}
: ${INSTANCE_TYPE:?}
: ${NTP_SERVER:?}
: ${CA_CERT:-""}
: ${AVAILABILITY_ZONE:-""}
: ${OBJECT_STORAGE:?}
: ${MTU_SIZE:?}
: ${AUTO_ANTI_AFFINITY:-""}

# terraform output variables
metadata=terraform-validator/metadata
export NETWORK_ID=$(cat ${metadata} | jq --raw-output ".validator_net_id")
export FLOATING_IP=$(cat ${metadata} | jq --raw-output ".validator_floating_ip")

# Build CPI
# Copy to user's home, because we don't have write permissions on the source directory
cp -r bosh-cli ~
export BOSH_CLI=$(readlink -f ~/bosh-cli/*bosh-cli-*)
chmod +x $BOSH_CLI

# Copy to user's home, because we don't have write permissions on the source directory
cp -r openstack-cpi-src ~
pushd ~/openstack-cpi-src
  $BOSH_CLI create-release --force --tarball ~/cpi-release.tgz
popd

# Copy to user's home, because we don't have write permissions on the source directory
cp -r validator-src ~

pushd ~/validator-src

echo "${PRIVATE_KEY}" > cf-validator.rsa_id
chmod 400 cf-validator.rsa_id

ci/assets/config_renderer/render validator.template.yml > validator.yml
cat validator.yml

bundle install --path .bundle

./validate -s ~/stemcell.tgz -c validator.yml -r ~/cpi-release.tgz --tag cpi_api
