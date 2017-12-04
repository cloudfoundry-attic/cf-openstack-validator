#!/bin/bash
set -e

pushd validator-src
bundle install
bundle exec rspec ci/assets/config_renderer/
bundle exec rspec spec/