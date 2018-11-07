#!/bin/bash
set -ex
export TERM=xterm-256color

URL=$(cat ./bosh-openstack-cpi-release/url)
SHA=$(cat ./bosh-openstack-cpi-release/sha1)

cp -r validator-src-in/. validator-src-cpi-bumped
pushd validator-src-cpi-bumped

sed -i'' "/bosh-openstack-cpi/,+3s|url: .*$|url: $URL|" validator.template.yml
sed -i'' "/bosh-openstack-cpi/,+3s|sha1: .*$|sha1: $SHA|" validator.template.yml

git diff --exit-code validator.template.yml || exit_code=$?
if [ -v exit_code ]; then
  git config --global user.email cf-bosh-eng@pivotal.io
  git config --global user.name CI
  git add validator.template.yml
  git commit -m "auto-bump openstack CPI"
else
  echo "No new bosh-openstack-cpi-release version found"
fi
