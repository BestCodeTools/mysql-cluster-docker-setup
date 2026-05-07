#!/usr/bin/env bash

set -Eeuo pipefail

dotnet restore ./poc-csharp-cluster.csproj
dotnet run --project ./poc-csharp-cluster.csproj
