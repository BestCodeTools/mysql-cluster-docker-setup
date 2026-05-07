#!/usr/bin/env bash

set -Eeuo pipefail

mkdir -p ./build
g++ -std=c++17 -Wall -Wextra -pedantic \
  ./src/main.cpp \
  -o ./build/poc-cpp-cluster \
  $(pkg-config --cflags --libs libmariadb)

./build/poc-cpp-cluster
