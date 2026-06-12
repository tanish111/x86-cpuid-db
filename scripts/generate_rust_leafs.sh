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

for file in db/xml/leaf_*.xml; do
    num=${file#db/xml/leaf_}
    num=${num%.xml}

    echo "Generating Rust source for CPUID leaf 0x${num}"
    poetry run cpuidgen --rustleaf "$num" > "${OUTPUT_DIR}/leaf_${num}.rs"
done
