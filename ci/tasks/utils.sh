#!/usr/bin/env bash
set -eo pipefail

optional_value() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "unsetting optional environment variable $name"
    unset $name
  fi
}

init_openstack_cli_env(){
    : ${BOSH_OPENSTACK_AUTH_URL:?}
    : ${BOSH_OPENSTACK_USERNAME:?}
    : ${BOSH_OPENSTACK_API_KEY:?}
    : ${BOSH_OPENSTACK_PROJECT:?}
    : ${BOSH_OPENSTACK_DOMAIN_NAME:?}
    : ${BOSH_OPENSTACK_INTERFACE:?}
    optional_value BOSH_OPENSTACK_CA_CERT

    export OS_DEFAULT_DOMAIN=$BOSH_OPENSTACK_DOMAIN_NAME
    export OS_AUTH_URL=$BOSH_OPENSTACK_AUTH_URL
    export OS_USERNAME=$BOSH_OPENSTACK_USERNAME
    export OS_PASSWORD=$BOSH_OPENSTACK_API_KEY
    export OS_PROJECT_NAME=$BOSH_OPENSTACK_PROJECT
    export OS_DOMAIN_NAME=$BOSH_OPENSTACK_DOMAIN_NAME
    export OS_IDENTITY_API_VERSION=3
    export OS_INTERFACE=$BOSH_OPENSTACK_INTERFACE

    if [ -n "$BOSH_OPENSTACK_CA_CERT" ]; then
      tmpdir=$(mktemp -dt "$(basename $0).XXXXXXXXXX")
      cacert="$tmpdir/cacert.pem"
      echo "Writing cacert.pem to $cacert"
      echo "$BOSH_OPENSTACK_CA_CERT" > $cacert
      export OS_CACERT=$cacert
    fi

}
