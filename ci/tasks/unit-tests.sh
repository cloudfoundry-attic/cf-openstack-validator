#!/bin/bash
set -e -x

pushd validator-src/src
bundle install
bundle exec rspec formatter_spec.rb