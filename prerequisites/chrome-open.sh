#!/usr/bin/env bash
# Ensures Chrome is running. Delegates to sapo browser open.
set -euo pipefail

exec sapo browser open
