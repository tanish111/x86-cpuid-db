#!/bin/bash
#
# stats.sh — Statistics for the x86-cpuid.org project
#
# SPDX-FileCopyrightText: 2023 Linutronix GmbH
# SPDX-License-Identifier: GPL-2.0-only

set -o errtrace
set -o nounset
set -o pipefail
set -o errexit

XML_DIR=db/xml/

CPUID_LEAVES=$(git ls-files ${XML_DIR}/leaf_*.xml | wc -l)
CPUID_BITFIELDS=$(git grep '<bit' -- ${XML_DIR} | wc -l)
LINUX_FEATURE_FLAGS=$(git grep '<linux' -- ${XML_DIR} | wc -l)
XEN_FEATURE_FLAGS=$(git grep '<xen' -- ${XML_DIR} | wc -l)

echo "Project statistics"
echo "------------------"
echo "CPUID leaves:        ${CPUID_LEAVES} leaves"
echo "CPUID bitfields:     ${CPUID_BITFIELDS} entries"
echo "Linux feature flags: ${LINUX_FEATURE_FLAGS} entries"
echo "Xen feature flags:   ${XEN_FEATURE_FLAGS} entries"
