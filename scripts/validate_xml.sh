#!/bin/bash
#
# stats.sh — Schema validation for x86-cpuid.org XML files
#
# SPDX-FileCopyrightText: 2023 Linutronix GmbH
# SPDX-License-Identifier: GPL-2.0-only

set -o errtrace
set -o nounset
set -o pipefail
set -o errexit

SCHEMA_DIR=db/schema
XML_DIR=db/xml

xmllint="xmllint --noout"

$xmllint --schema ${SCHEMA_DIR}/cpuvendors.xsd ${XML_DIR}/cpuvendors.xml
$xmllint --schema ${SCHEMA_DIR}/hypervisors.xsd ${XML_DIR}/hypervisors.xml

for leaf in ${XML_DIR}/leaf*.xml; do
    $xmllint --schema ${SCHEMA_DIR}/leaf.xsd $leaf
done
