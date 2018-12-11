#!/usr/bin/env bash

set -euo pipefail

source validator-src-in/ci/tasks/utils.sh

init_openstack_cli_env

if [[ $(openstack role list 2>&1) != *"HTTP 403"* ]]; then
  echo "Exiting the script, since it might be executed with admin rights!"
  exit 1
fi

OPENSTACK_PROJECT_ID=$(openstack project list --format json | jq --raw-output --arg project $BOSH_OPENSTACK_PROJECT '.[] | select(.Name == $project) | .ID')
if [ -z "$OPENSTACK_PROJECT_ID" ]; then
  echo "Error: Failed to get OpenStack project"
  exit 1
fi

exit_code=0

openstack_delete_entities() {
  local entity=${1:-}
  local list_args=${2:-}
  local delete_args=${3:-}
  id_list=$(openstack $entity list $list_args --format json | jq --raw-output '.[].ID')
  echo "Received list of all ${entity}s: ${id_list}"
  for id in $id_list
  do
    echo "Deleting $entity $id ..."
    openstack $entity delete $delete_args $id || exit_code=$?
  done
}

openstack_delete_ports() {
  for port in $(openstack port list --project=$OPENSTACK_PROJECT_ID -c ID -f value)
  do
    port_json=$(openstack port show --format json "$port")
    port_id_to_be_deleted=$(jq --raw-output '. | select( (.device_owner == "" or .device_owner == null or .device_owner =="compute:nova") and (.status == "DOWN") and (.device_id == "" or .device_id == null) ) | .id' <<< "$port_json")
    if [[ -n ${port_id_to_be_deleted} ]]; then
      echo "Deleting port ${port_id_to_be_deleted}"
      openstack port delete "${port_id_to_be_deleted}" || exit_code=$?
    fi
  done
}
# Destroy all images and snapshots and volumes

echo "Starting cleanup for project: $BOSH_OPENSTACK_PROJECT"
echo "openstack cli version:"
openstack --version

echo "Deleting servers #########################"
openstack_delete_entities "server"
echo "Deleting images #########################"
openstack_delete_entities "image" "--private --limit 1000 --property owner=$OPENSTACK_PROJECT_ID"
echo "Deleting snapshots #########################"
openstack_delete_entities "volume snapshot"
echo "Deleting volumes #########################"
openstack_delete_entities "volume"
echo "Deleting ports #########################"
openstack_delete_ports

if [ -d "${tmpdir:-}" ]; then
    echo "Deleting temp dir with cacert.pem"
    rm -rf "${tmpdir}"
fi

exit ${exit_code}
