#!/bin/bash
#
# spellcheck_xml.sh — Spell checking for x86-cpuid-db XML files
#
# SPDX-FileCopyrightText: 2025 Linutronix GmbH
# SPDX-License-Identifier: GPL-2.0-only
#
# Use hunspell instead of GNU aspell, codespell, or VScode cspell.
#
# Why?
#
#   - GNU aspell does not handle numbers embedded in words (e.g.,
#     CMPXCHG16B, x2APIC, IA32) through a private dictionary.
#
#   - codespell and VS Code cspell are overly permissive, allowing
#     informal words like "nr," "num," "regs," etc.
#
#   - hunspell(5) custom dictionary affix features allows precise
#     control over spelling, capitalization, and terminology usage.
#
# Through hunspell affix rules, this script also enforces:
#
#  - Capitalization of all x86 register names and opcodes.
#
#  - Standardized x86 byte units usage (DWORD, QWORD, etc.)
#
#  - Consistent x86-specific terms style (dTLB, iTLB, x2APIC, etc.)
#
#  - Uniform formatting for all hexadecimal digits (0xN)
#
# Given that codespell is used by the Linux kernel's checkpatch.pl, it
# can still be chosen in this script through the --codespell parameter.

set -o errtrace
set -o nounset
set -o pipefail
set -o errexit

SPELLCHECK_TOOL=hunspell
SCRIPT_DIR=$(dirname $0)
ABSOLUTE_SCRIPT_DIR="$(realpath ${SCRIPT_DIR})"

# Put all temp files under one directory to streamline cleanup
TMPDIR=`mktemp --quiet --directory`
MKTEMP="mktemp --quiet --tmpdir=${TMPDIR}"

function set_traps()
{
    trap 'err -ne "Script abrupt exit: cleaning up"; cleanup' ERR
    trap 'cleanup' EXIT
}

# Parameters:
#   -ne: Do not exit the script
#   -np: Do not print the 'Error' prefix
function err()
{
    local error_prefix="Error: "
    local exit_on_error=1
    local msg="$1"

    [[ "$#" == "2" ]] && msg="$2"
    case "$1" in
	"-ne")
            exit_on_error=0
	    ;;
	"-np")
	    error_prefix=""
	    ;;
    esac

    echo -e "${error_prefix}$msg" >&2
    (( exit_on_error )) && exit 1
    :
}

function parse_script_params()
{
    [[ $# -gt 1 ]] && err "Too many arguments provided"
    [[ $# -eq 0 ]] && return

    case "$1" in
	"--codespell")
	    SPELLCHECK_TOOL="codespell"
	    ;;
	"--hunspell")
	    # Already the default checker
	    ;;
	*)
	    err "unrecognized parameter '$1'"
	    ;;
    esac
}

function check_required_progs()
{
    local required="xmllint ${SPELLCHECK_TOOL}"

    for prog in $required; do
	if ! command -v $prog &>/dev/null; then
	    err "$prog is not installed"
	fi
    done
}

#
# Hunspell dictionary rules:
#
#   - Must be in "dict_name.{dic,aff}" file pairs
#   - When passed to hunspell, the {.dic,aff} suffixes must be stripped
#   - When passed to hunspell, absolute paths must be used
#

CUST_DICT_FILE="${TMPDIR}/hunspell_x86.dic"
CUST_AFF_FILE="${TMPDIR}/hunspell_x86.aff"

__EN_US_DICT="en_US"
__CUST_DICT="${CUST_DICT_FILE%.dic}"
HUNSPELL_DICTS="${__EN_US_DICT},${__CUST_DICT}"

DICT_FILES_DIR=${SCRIPT_DIR}/dict/
DICT_FILES="			\
	expression-suffixes.dic	\
	tech-terms.dic		\
	x86-opcodes.dic		\
	x86-registers.dic	\
	x86-terms.dic		\
	x86-trademarks.dic	\
"

# hunspell does not support comments or empty lines in its *.dic files.
# It also requires these files to start with an approximate word count.
# Sanitize all of the project's *.dic files beforehand, and prepare
# their corresponding affix files to be filename-matching.
function hunspell_build_dicts()
{
    local egrep_exp='^#|^\s*$'
    local tmpfile=`$MKTEMP`

    for _dict_f in $DICT_FILES; do
	grep -vE "$egrep_exp" ${SCRIPT_DIR}/dict/$_dict_f >> $tmpfile
    done

    { wc -l < $tmpfile; cat $tmpfile; } > $CUST_DICT_FILE
    cp ${DICT_FILES_DIR}/hunspell_main.aff $CUST_AFF_FILE
}

# Hunspell _silently_ ignores passed dictionaries if a relative path is
# given or the absolute path does not exist.  Manually validate all the
# hunspell dictionaries beforehand.
function hunspell_validate_dicts()
{
    local dicts="$(hunspell -D 2>&1)"

    if ! echo "$dicts" | grep -E --quiet "/${__EN_US_DICT}$"; then
	err -ne "hunspell has no $__EN_US_DICT dictionary available"
	err -np "Available dictionaries:\n${dicts}"
    fi

    for dict in ${HUNSPELL_DICTS//,/ }; do
	[[ "$dict" == "$__EN_US_DICT" ]] && continue
	[[ "$dict" != /* ]] && err "$dict is not an absolute path"

	for f in "${dict}.dic" "${dict}.aff"; do
	    [[ ! -e "$f" ]] && err "$f does not exist"
	    [[ ! -s "$f" ]] && err "$f is empty"
	    :
	done
    done
}

function spellcheck_xml()
{
    local xml_dir=${SCRIPT_DIR}/../db/xml
    local typos_file=`$MKTEMP`
    local spell_cmd

    case "$SPELLCHECK_TOOL" in
	"hunspell")
	    spell_cmd="hunspell -a -l -d $HUNSPELL_DICTS"
	    hunspell_build_dicts
	    hunspell_validate_dicts
	    ;;
	"codespell")
	    spell_cmd="codespell --stdin-single-line - 2>&1"
	    ;;
	*)
	    err "Unknown spellcheck tool: ${SPELLCHECK_TOOL}"
	    ;;
    esac

    for leaf in ${xml_dir}/leaf*.xml; do
	errors=$(xmllint --xpath '//@desc' ${leaf}		\
		| cut -d= -f2 | sed "s/'//g"			\
		| ${spell_cmd} || : )
	errors+=$(xmllint --xpath '/leaf/desc/text()' ${leaf}	\
		| ${spell_cmd} || : )
	errors=$(echo "$errors" | sort -u)

	if [[ -n "$errors" ]]; then
	    errors=$(paste -sd ',' <<< "$errors")
	    errors=$(echo "$errors" | sed 's/,/, /g')
	    echo "$(basename $leaf): $errors" >> $typos_file
	fi
    done

    if [[ -s $typos_file ]]; then
	err -ne 'cpuid bitfields descriptions have spelling errors'
	cat $typos_file >&2
	exit 1
    fi
}

function cleanup()
{
    rm -rf $TMPDIR
}

set_traps
parse_script_params "$@"
check_required_progs
spellcheck_xml
echo "Success: XML database has no typos or non-standard x86 terms"
