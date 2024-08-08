#!/bin/bash
#
# generate_kernel_headers.sh — Linux kernel CPUID headers generation
#
# SPDX-FileCopyrightText: 2023 Linutronix GmbH
# SPDX-License-Identifier: GPL-2.0-only

set -o errtrace
set -o nounset
set -o pipefail
set -o errexit

OUTPUT_DIR=${OUTPUT_DIR:-output}

mkdir -p $OUTPUT_DIR

for file in db/xml/leaf_*.xml; do
    num=${file#db/xml/leaf_}
    num=${num%.xml}

    echo "Generating kernel C header for CPUID leaf 0x${num}"
    poetry run cpuidgen --kheader $num > ${OUTPUT_DIR}/leaf_${num}.h
done
