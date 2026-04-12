#!/usr/bin/env bash
# Shared logging functions for cleanup scripts.
# Sourced by cleanup-*.sh scripts.

log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >&2; }
log_warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >&2; }
