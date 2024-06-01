.. SPDX-FileCopyrightText: 2023 Linutronix GmbH
.. SPDX-License-Identifier: CC0-1.0

x86-cpuid-db
============

A machine-readable x86 CPUID data repository and code generator.

Preamble
--------

On x86 CPUs, the ``CPUID`` instruction is used for runtime identification
of CPU features.  It takes as input a *leaf* number in the EAX register
and an optional *subleaf* number in the ECX register.  According to the
set leaf and subleaf, certain information regarding CPU identification
and supported features will be returned as output through the EAX, EBX,
ECX, and EDX registers.

Due to the extensiveness and long history of the x86 architecture, the
amount of information that can be queried through CPUID is huge: now up
to *800+* bitfields, scattered over *15+* CPU manuals and *52* CPUID
leaves.  The returned bitfields can differ according to the x86 CPU
vendor and include multiple flags related to *CPU vulnerabilities*.

With the above in mind, this project aims to:

1. Standardize a *machine-readable* language/syntax for describing the
   CPUID instruction output.

2. Build an extensive database, in that machine-readable syntax,
   describing *all* the publicly-known CPUID bitfields output.  Such a
   database will be properly maintained and act as the standard
   information source for multiple open-source projects downstream.

3. Augment such a CPUID database with usage hints for significant
   open-source projects like the Linux Kernel and the Xen hypervisor.
   Usage hints for other projects can be easily added in the future.

4. Provide multiple code/data generators utilizing that CPUID database.

Specification language
----------------------

Several languages (JSON, YAML, TOML, S-expressions, and XML) were
evaluated for the machine-readable CPUID specification format.  To ensure
hierarchical extensibility without excessive vertical lines, a data
format that is natively capable of representing an *extensible annotated
tree* was desired.

Among the evaluated candidates, only XML and S-expressions fulfilled this
requirement.  XML was ultimately picked due to its mature ecosystem,
especially its well-developed schema (XSD), querying (XPath), and
transformation (XSLT) capabilities.

Code Navigation
===============

CPUID database
--------------

All of the *publicly-known* CPUID leaves' bitfields are described under
`db/xml/leaf_*.xml`_, where each file describes a single leaf and all its
possible subleaves.

For examples, check `leaf_04.xml`_, `leaf_07.xml`_, `leaf_0a.xml`_,
`leaf_12.xml`_, `leaf_18.xml`_, `leaf_1c.xml`_, `leaf_8000001d.xml`_, and
`leaf_80000026.xml`_.

Schemas
-------

Schemas for the project's XML files are under `db/schema/*.xsd`_.

The primary schema is `leaf.xsd`_, which is the CPUID leaves XML files
schema.  Beside correctness, a global XML coding style is enforced
throughout the project using `scripts/check_xml_style.awk`_.

Transformers
------------

Code and data generators are built on top of the CPUID XML database using
the XSLT transformers under `db/xslt/*.xslt`_.

XSLT, at the core of it, is a *recursive-descent rule-based
transformation engine*.  `kcpuid.xslt`_ generates a Linux kernel kcpuid
CSV file, while `kheader.xslt`_ generates a Linux kernel header file with
C structures and C99 bitfields for a certain CPUID leaf.  More
transformers shall be added in the future.

Utilities
---------

The XSLT transformers earlier mentioned are invoked through a very thin,
zero-logic, Python wrapper.  The primary example is `tools/cpuidgen.py`_.

.. _`tools/cpuidgen.py`: tools/cpuidgen.py

Other
-----

Finally, you can also check:

- `CONTRIBUTING`_ for contribution guidelines.
- `CHANGELOG`_ for a high-level summary of each release.
- `LICENSE`_ for a licensing note regarding generated code and data files.
- `gitlab-ci.yml`_ for the project's CI/CD pipeline.
- `x86-cpuid.org`_ for development updates and a *big-picture* rationale.

Dependencies Installation
=========================

Poetry
------

We exclusively use Poetry in this project for all tasks related to
packaging and dependencies resolution.  It is a modern python dependency
management and packaging tool, compatible with PEP 517's setup.py
deprecation, PEP 518's pyproject.toml, PEP 440's packages versioning
scheme, PEP 503's package API repositories like PyPI, PEP 508's project
dependencies declarations, and PEP 610's project metadata.  It also has a
very active community in the Python ecosystem.

Poetry is already packaged on modern distributions like ArchLinux, Debian
(Bookworm+), and Fedora (32+).  You should do something similar to:

.. code-block:: shell

    sudo pacman -Syu python-poetry
    sudo apt -y install python3-poetry
    sudo dnf install poetry

*On older distributions*, first install ``pipx``, then do:

.. code-block:: shell

    pipx ensurepath
    pipx install poetry==1.5.0

Dependencies
------------

First, verify that poetry is available::

    poetry about

Then, install the project's required dependencies by running below
command from the project's directory:

.. code-block:: shell

    poetry install

Afterwards, optionally verify the installed dependencies using:

.. code-block:: shell

    poetry show --tree

Usage
=====

After installing the project dependencies as shown earlier, enter a
poetry shell::

    poetry shell

This will spawn a shell, according to ``$SHELL``, within the Python
virtual environment where all the vendored dependencies were previously
installed.

Then, you can use this project's available tooling:

.. code-block:: shell

    cpuidgen -h
    usage: cpuidgen.py [-h] [--kcpuid] [--kheader CPUID_LEAF]

    CPUID leaves bitfield generator

    options:
      -h, --help            show this help message and exit
      --kcpuid, -k          Generate a linux-kernel "kcpuid" CSV file
      --kheader CPUID_LEAF, -l CPUID_LEAF
                            Generate a linux-kernel C header for the given CPUID LEAF

    Generate CPUID data structures in different output formats

For example, to generate a Linux-kernel kcpuid CSV file, do:

.. code-block:: shell

    $ cpuidgen --kcpuid

    # SPDX-License-Identifier: CC0-1.0
    # Generator: x86-cpuid-db v1.0

    # The basic row format is:
    #     LEAF, SUBLEAVES,  reg,    bits,    short_name             , long_description

    # Leaf 0H
    # Maximum standard leaf number + CPU vendor string

             0,         0,  eax,    31:0,    max_std_leaf           , Highest cpuid standard leaf supported
             0,         0,  ebx,    31:0,    cpu_vendorid_0         , CPU vendor ID string bytes 0 - 3
             0,         0,  ecx,    31:0,    cpu_vendorid_2         , CPU vendor ID string bytes 8 - 11
             0,         0,  edx,    31:0,    cpu_vendorid_1         , CPU vendor ID string bytes 4 - 7

    # Leaf 1H
    # CPU FMS (Family/Model/Stepping) + standard feature flags

             1,         0,  eax,     3:0,    stepping               , Stepping ID
             1,         0,  eax,     7:4,    base_model             , Base CPU model ID
             1,         0,  eax,    11:8,    base_family_id         , Base CPU family ID
             1,         0,  eax,   13:12,    cpu_type               , CPU type
             1,         0,  eax,   19:16,    ext_model              , Extended CPU model ID
             …

    # Leaf 4H
    # Intel deterministic cache parameters

             4,      31:0,  eax,     4:0,    cache_type             , Cache type field
             4,      31:0,  eax,     7:5,    cache_level            , Cache level (1-based)
             4,      31:0,  eax,       8,    cache_self_init        , Self-initializing cache level
             4,      31:0,  eax,       9,    fully_associative      , Fully-associative cache
             4,      31:0,  eax,   25:14,    num_threads_sharing    , Number logical CPUs sharing this cache
             …
    …

To generate C structures describing a certain CPUID leaf, through C99
bitfield listings, do:

.. code-block:: c

    $ cpuidgen --kheader 7

    struct {
     	// eax
     	u32	leaf7_n_subleaves	: 32; // Number of cpuid 0x7 subleaves
     	// ebx
     	u32	fsgsbase		:  1, // FSBASE/GSBASE read/write support
     		tsc_adjust		:  1, // IA32_TSC_ADJUST MSR supported
     		sgx			:  1, // Intel SGX (Software Guard Extensions)
     		bmi1			:  1, // Bit manipulation extensions group 1
     		hle			:  1, // Hardware Lock Elision
     		avx2			:  1, // AVX2 instruction set
		…;
     	// ecx
     	u32	prefetchwt1		:  1, // PREFETCHWT1 (Intel Xeon Phi only)
     		avx512vbmi		:  1, // AVX-512 Vector byte manipulation instrs
     		umip			:  1, // User mode instruction protection
     		pku			:  1, // Protection keys for user-space
		…;
     	// edx
     	u32				:  1, // Reserved
     		sgx_keys		:  1, // Intel SGX attestation services
     		avx512_4vnniw		:  1, // AVX-512 neural network instructions
     		avx512_4fmaps		:  1, // AVX-512 multiply accumulation single precision
     		fsrm			:  1, // Fast short REP MOV
     		uintr			:  1, // CPU supports user interrupts
     					:  2, // Reserved
		…;
    } leaf7_sl0;

    struct {
     	// eax
     	u32				:  4, // Reserved
     		avx_vnni		:  1, // AVX-VNNI instructions
     		avx512_bf16		:  1, // AVX-512 bFloat16 instructions
     		lass			:  1, // Linear address space separation
     		cmpccxadd		:  1, // CMPccXADD instructions
		…;
     	// ebx
     	u32	intel_ppin		:  1, // Protected processor inventory number (PPIN{,_CTL} MSRs)
     					: 31; // Reserved
     	// ecx
     	u32				: 32; // Reserved
     	// edx
     	u32				:  4, // Reserved
     		avx_vnni_int8		:  1, // AVX-VNNI-INT8 instructions
     		avx_ne_convert		:  1, // AVX-NE-CONVERT instructions
     					:  2, // Reserved
		…;
    } leaf7_sl1;

    struct {
     	// eax
     	u32				: 32; // Reserved
     	// ebx
     	u32				: 32; // Reserved
     	// ecx
     	u32				: 32; // Reserved
     	// edx
     	u32	intel_psfd		:  1, // Intel predictive store forward disable
     		ipred_ctrl		:  1, // MSR bits IA32_SPEC_CTRL.IPRED_DIS_{U,S}
     		rrsba_ctrl		:  1, // MSR bits IA32_SPEC_CTRL.RRSBA_DIS_{U,S}
     		ddp_ctrl		:  1, // MSR bit  IA32_SPEC_CTRL.DDPD_U
     		bhi_ctrl		:  1, // MSR bit  IA32_SPEC_CTRL.BHI_DIS_S
     		mcdt_no			:  1, // MCDT mitigation not needed
     		uclock_disable		:  1, // UC-lock disable is supported
     					: 25; // Reserved
    } leaf7_sl2;

Similarly:

.. code-block:: shell

    cpuidgen --kheader 0x12
    cpuidgen --kheader 0x80000001

where the list of known CPUID leaves can be found by checking the
``db/xml/leaf_*.xml`` list of files.

The project also contains some internal developer tooling that was
created to help generating the XML CPUID leaves database itself.  For
more information, do:

.. code-block:: shell

    xmlgen --help

CPUID Data Coverage
===================

To the best of our knowledge, we've specified *all publicly-known*
CPUID register bitfields in the included XML database. The covered
data was collected from multiple x86 CPU vendors programming mauals —
representing both current CPUs and possible future instruction set
extensions and future features.

We have also specified *all* of the Linux kernel's ``X86_FEATURE_`` and
``/proc/cpuinfo`` flags_ as well as *all* of the Xen hypervisor's
featuresets_ and attached attributes.

.. _flags: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/arch/x86/include/asm/cpufeatures.h?h=v6.6
.. _featuresets: https://github.com/xen-project/xen/blob/RELEASE-4.18.0/xen/include/public/arch-x86/cpufeatureset.h

Further statistics can be queried through:

.. code-block:: shell

    $ ./scripts/stats.sh

    Project statistics
    ------------------
    CPUID leaves:        52 leaves
    CPUID bitfields:     835 entries
    Linux feature flags: 274 entries
    Xen feature flags:   198 entries

References
==========

Origin story and development context:

  -  `Standardizing CPUID Data for the Open-source x86 Ecosystem
     <https://lpc.events/event/17/contributions/1511/attachments/1324/2735/lpc_2023_standardizing_CPUID_data_across_x86_ecosystem.pdf>`_,
     Linux Plumbers Conference 2023

Intel manuals:

  - Intel® 64 and IA-32 Architectures Software Developer's Manual
  - Intel® Architecture Instruction Set Extensions and Future Features
  - Intel® CPUID Enumeration and Architectural MSRs
  - Intel® X86-S External Architectural Specification
  - Intel® Key Locker Specification
  - Intel® Architecture Memory Encryption Technologies Specification
  - Intel® Trust Domain CPU Architectural Extensions
  - Intel® Architecture Specification: Intel® Trust Domain Extensions (TDX)

AMD manuals:

  - AMD64 Architecture Programmer’s Manual, Volumes 1–5
  - Preliminary Processor Programming Reference (PPR) for AMD Family 19h
    Model 11h, Revision B1 Processors
  - Open-Source Register Reference For AMD Family 17h Processors Models
    00h-2Fh

XML ecosystem specifications and manuals:

  - `XSLT 3.0 Specification <https://www.w3.org/TR/xslt-30/>`_

  - `XPath 3.1 Specification <https://www.w3.org/TR/xpath-31/>`_

  - `XPath and XQuery Functions and Operators 3.1
    <https://www.w3.org/TR/xpath-functions-31/>`_

  - `XSLT 2.0 and XPath 2.0, 4th Edition
    <https://www.wiley.com/en-us/XSLT+2+0+and+XPath+2+0+Programmer%27s+Reference%2C+4th+Edition-p-9780470192740>`_,
    Michael Kay (XSLT 2.0 and XSLT 3.0 editor)

  - `SAXONICA SaxonC documentation
    <https://www.saxonica.com/saxon-c/documentation12/>`_

  - `SAXONICA SaxonC Python API
    <https://www.saxonica.com/saxon-c/doc12/html/saxonc.html>`_

Since this project involved naming *800+* variables, below work was also
helpful:

  - `Naming Things: The Hardest Problem in Software Engineering
    <https://www.namingthings.co/>`_, Tom Benner

.. _`db/xml/leaf_*.xml`: db/xml/
.. _`leaf_04.xml`: db/xml/leaf_04.xml
.. _`leaf_07.xml`: db/xml/leaf_07.xml
.. _`leaf_0a.xml`: db/xml/leaf_0a.xml
.. _`leaf_12.xml`: db/xml/leaf_12.xml
.. _`leaf_18.xml`: db/xml/leaf_18.xml
.. _`leaf_1c.xml`: db/xml/leaf_1c.xml
.. _`leaf_8000001d.xml`: db/xml/leaf_8000001d.xml
.. _`leaf_80000026.xml`: db/xml/leaf_80000026.xml

.. _`db/schema/*.xsd`: db/schema/
.. _`leaf.xsd`: db/schema/leaf.xsd
.. _`scripts/check_xml_style.awk`: scripts/check_xml_style.awk

.. _`db/xslt/*.xslt`: db/xslt/
.. _`kcpuid.xslt`: db/xslt/kcpuid.xslt
.. _`kheader.xslt`: db/xslt/kheader.xslt

.. _`CONTRIBUTING`: CONTRIBUTING.rst
.. _`CHANGELOG`: CHANGELOG.rst
.. _`LICENSE`: LICENSE.rst
.. _`gitlab-ci.yml`: .gitlab-ci.yml
.. _`x86-cpuid.org`: https://x86-cpuid.org
