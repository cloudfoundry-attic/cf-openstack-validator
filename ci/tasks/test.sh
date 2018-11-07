#!/bin/bash
set -euxo pipefail

pushd validator-src-in
bundle install
bundle exec rspec ci/assets/config_renderer/
bundle exec rspec spec/
