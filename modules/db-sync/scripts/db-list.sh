#!/usr/bin/env bash
set -euo pipefail
du -sh "@dbRoot@"/*/ 2>/dev/null | sort -k2
