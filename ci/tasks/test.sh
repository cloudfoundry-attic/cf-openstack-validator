#!/bin/bash
set -e

source /etc/profile.d/chruby-with-ruby-2.1.2.sh

pushd validator-src
bundle install
bundle exec rspec spec/