#!/usr/bin/env -S gawk -f
#
# check_xml_style.awk — Project-wide XML coding-style enforcemenet
#
# SPDX-FileCopyrightText: 2023 Linutronix GmbH
# SPDX-License-Identifier: GPL-2.0-only
#
# The XML spec mandates that attributes' column alignment is semantically
# insignificant.  Such constraints cannot thus be encoded in an XML schema
# like W3C XSD or RELAX NG.
#
# Presenting the CPUID bitfields in a consistent tabular form drastically
# improves readability though.  Thus, check for a consistent <bitN>,
# <linux>, and <xen> attributes column alignment for all XML files in this
# project.
#
# Note: this script deals with *pure* XML coding style issues.  __NEVER__
# let it check for constraints that can be encoded within the XML schema.

BEGIN {
    while (("find db/ -name 'leaf_*.xml' | sort" | getline line) > 0) {
        ARGV[ARGC++] = line
    }

    # OS elements (<linux> and <xen>) expected attribute alignment
    os_align_attr[1] = 22
    os_align_attr[2] = 51
    os_align_attr[3] = 74
    os_align_attr[4] = 93

    # Bitfield elements (<bit0> to <bit31) expected attribute alignment
    bit_align_attr[1] = 13
    bit_align_attr[2] = 22
    bit_align_attr[3] = 51

    errors = 0
}

/<bit|<linux|<xen/ {
    match($0, /<bit|<linux|<xen/, arr)
    element = arr[0] ">"

    attr_index = 1
    match_from = 1
    while (match(substr($0, match_from), /([a-zA-Z0-9_]+)="[^"]*"/, arr)) {
        attribute = arr[1] "="
        attribute_col = index($0, attribute)

        if ($0 ~ /<bit/) {
            expected_col = bit_align_attr[attr_index]
        } else if ($0 ~ /<linux|<xen/) {
            expected_col = os_align_attr[attr_index]
        }

        if (attribute_col != expected_col + 1) {
            print FILENAME ": line " FNR ": " element                          \
                  " attribute '" attribute "' is at column " (attribute_col-1) \
                  "; expected column " expected_col "."
	    errors++
        }

        match_from += RSTART + RLENGTH - 1
        attr_index++
    }
}

END {
    if (errors == 0) {
        for (i = 1; i < ARGC; i++) {
            print ARGV[i], "passes coding style"
        }
    }
}
