#!/bin/bash
set -e -x

: ${AUTH_URL:?}
: ${USERNAME:?}
: ${API_KEY:?}
: ${DOMAIN:?}
: ${PROJECT:?}
: ${PROJECT_ID:?}
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
: ${EXPECTED_FLAVORS:?}
: ${EXPECTED_QUOTAS:?}
: ${EXPECTED_ENDPOINTS:?}

report_performance_stats(){
  echo 'Stats:'
  cat ~/.cf-openstack-validator/logs/stats.log
  if [ ! -z ${INFLUXDB_IP} ] && [ ! -z ${INFLUXDB_PORT} ] && [ ! -z ${INFLUXDB_USER} ] && [ ! -z ${INFLUXDB_PASSWORD} ]; then
    echo 'Sending stats to performance database'
    ruby ci/ruby_scripts/influxdb-post/upload-stats.rb ~/.cf-openstack-validator/logs/stats.log
  fi
}

# Copy to user's home, because we don't have write permissions on the source directory
cp -r validator-src ~

pushd ~/validator-src

echo "${PRIVATE_KEY}" > cf-validator.rsa_id
chmod 400 cf-validator.rsa_id

ci/assets/config_renderer/render validator.template.yml > validator.yml
cat validator.yml

bundle install --path .bundle

./validate -s ~/stemcell.tgz -c validator.yml

report_performance_stats

CONFIG_DRIVE='disk' ci/assets/config_renderer/render validator.template.yml > validator.yml
cat validator.yml

./validate -s ~/stemcell.tgz -c validator.yml

report_performance_stats