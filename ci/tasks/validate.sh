#!/bin/bash
set -euxo pipefail

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
: ${EXPECTED_FLAVORS:?}
: ${EXPECTED_QUOTAS:?}
: ${EXPECTED_ENDPOINTS:?}
: ${MTU_SIZE:?}
: ${AUTO_ANTI_AFFINITY:-""}

# terraform output variables
metadata=terraform-validator/metadata
export NETWORK_ID=$(cat ${metadata} | jq --raw-output ".validator_net_id")
export FLOATING_IP=$(cat ${metadata} | jq --raw-output ".validator_floating_ip")

report_performance_stats(){
  echo 'Stats:'
  cat ~/.cf-openstack-validator/logs/stats.log
  if [ ! -z ${INFLUXDB_IP:-} ] && [ ! -z ${INFLUXDB_PORT:-} ] && [ ! -z ${INFLUXDB_USER:-} ] && [ ! -z ${INFLUXDB_PASSWORD:-} ]; then
    echo 'Sending stats to performance database'
    ruby ci/ruby_scripts/influxdb-post/upload-stats.rb ~/.cf-openstack-validator/logs/stats.log
  fi
}

# Copy to user's home, because we don't have write permissions on the source directory
cp -r validator-src-cpi-bumped ~

pushd ~/validator-src-cpi-bumped

echo "${PRIVATE_KEY}" > cf-validator.rsa_id
chmod 400 cf-validator.rsa_id

ci/assets/config_renderer/render validator.template.yml > validator.yml
cat validator.yml

bundle install --path .bundle

./validate -s ~/stemcell.tgz -c validator.yml

#report_performance_stats

CONFIG_DRIVE='disk' ci/assets/config_renderer/render validator.template.yml > validator.yml
cat validator.yml

./validate -s ~/stemcell.tgz -c validator.yml

#report_performance_stats
