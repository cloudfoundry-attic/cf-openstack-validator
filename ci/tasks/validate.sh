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
: ${AVAILABILITY_ZONE:-""}
: ${OBJECT_STORAGE:?}

# Copy to user's home, because we don't have write permissions on the source directory
cp -r validator-src ~

pushd ~/validator-src

echo "${PRIVATE_KEY}" > cf-validator.rsa_id
chmod 400 cf-validator.rsa_id

ci/assets/config_renderer/render validator.template.yml > validator.yml
cat validator.yml

bundle install --path .bundle

./validate -s ~/stemcell.tgz -c validator.yml

echo 'Stats:'
cat ~/.cf-openstack-validator/logs/stats.log

CONFIG_DRIVE='disk' ci/assets/config_renderer/render validator.template.yml > validator.yml
cat validator.yml

./validate -s ~/stemcell.tgz -c validator.yml

echo 'Stats:'
cat ~/.cf-openstack-validator/logs/stats.log
