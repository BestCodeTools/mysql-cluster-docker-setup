#!/usr/bin/env bash

set -Eeuo pipefail

bundle install
bundle exec ruby app.rb
