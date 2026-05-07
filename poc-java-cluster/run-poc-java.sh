#!/usr/bin/env bash

set -Eeuo pipefail

mvn -q -DskipTests compile exec:java
