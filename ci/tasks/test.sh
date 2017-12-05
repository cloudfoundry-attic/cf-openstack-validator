#!/bin/bash
set -e

pushd validator-src
BUNDLE_CACHE_PATH="vendor/package" bundle install --local --deployment --path .bundle
bundle exec rspec ci/assets/config_renderer/
bundle exec rspec spec/