#!/bin/bash
set -e

pushd validator-src
bundle install
bundle exec rspec spec/