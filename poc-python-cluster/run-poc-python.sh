#!/usr/bin/env bash

set -Eeuo pipefail

PYTHON_BIN="${PYTHON_BIN:-}"

if [[ -z "$PYTHON_BIN" ]]; then
  if command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
  else
    PYTHON_BIN="python3"
  fi
fi

if "$PYTHON_BIN" -m venv .venv >/dev/null 2>&1; then
  if [[ -f ".venv/bin/activate" ]]; then
    # Linux / WSL / containers
    # shellcheck disable=SC1091
    source .venv/bin/activate
  else
    # Git Bash on Windows
    # shellcheck disable=SC1091
    source .venv/Scripts/activate
  fi

  python -m pip install -r requirements.txt
  python app.py
else
  "$PYTHON_BIN" -m pip install --user -r requirements.txt
  "$PYTHON_BIN" app.py
fi
