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

# Copy to user's home, because we don't have write permissions on the source directory
cp -r validator-src ~

pushd ~/validator-src

echo "${PRIVATE_KEY}" > cf-validator.rsa_id
chmod 400 cf-validator.rsa_id

erb ci/assets/validator.yml.erb > validator.yml
cat validator.yml

cp extensions/dummy_extension_spec.sample.rb extensions/dummy_extension_spec.rb

bundle install --path .bundle

./validate -s ~/stemcell.tgz -c validator.yml

CONFIG_DRIVE='disk' erb ci/assets/validator.yml.erb > validator.yml
cat validator.yml

./validate -s ~/stemcell.tgz -c validator.yml
