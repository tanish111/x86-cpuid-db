#!/bin/bash
#
# generate_rust_leafs.sh — Rust CPUID leaf sources generation
#
# SPDX-FileCopyrightText: 2024 Linutronix GmbH
# SPDX-License-Identifier: GPL-2.0-only

set -o errtrace
set -o nounset
set -o pipefail
set -o errexit

OUTPUT_DIR=${OUTPUT_DIR:-output}

mkdir -p "$OUTPUT_DIR"

echo "Generating Rust common module"
poetry run cpuidgen --rustcommon > "${OUTPUT_DIR}/common.rs"

echo "Generating Rust module for all CPUID leaves"
poetry run cpuidgen --rustleaves > "${OUTPUT_DIR}/leaves.rs"
