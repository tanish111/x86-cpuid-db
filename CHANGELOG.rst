.. SPDX-FileCopyrightText: 2023-2024 Linutronix GmbH
.. SPDX-License-Identifier: CC0-1.0

Changelog
=========

Release v2.4
------------

Switch the license for generated *code* artifacts (e.g., Linux kernel
headers) from the Creative Commons Zero 1.0 Universal license, SPDX
``CC0-1.0``, to the MIT license (SPDX ``MIT``).  This aligns with the
Linux Kernel, since the generated header files are code, and ``MIT`` is
one of the "preferred" licenses for kernel code while ``CC0-1.0`` is not.

Updates to the CPUID database:

- Leaf ``0x80000001``: Mark the ``e_mmx`` bitfield as valid for AMD.


Release v2.3
------------

*Minor bugfix*: Remove leaf ``0x3`` (Processor Serial Number) from the
XML database.  Per H. Peter Anvin's feedback on a related Linux kernel
patch queue, leaf ``0x3`` is not unique to Transmeta as the project
claimed.

Since leaf ``0x3``'s format differs between Intel and Transmeta, and the
project does not yet support having the same CPUID bitfield with varying
interpretations across vendors, removal was necessary.  Given that Intel
discontinued support for PSN from Pentium 4 onward and Linux force
disables it on early boot for privacy concerns, this should have minimal
impact.

Updates to the CPUID database:

- Leaf ``0x80000021``: Improve bitfield descriptions for consistency and
  CSV output readability.


Release v2.2
------------

*Minor bugfix*: Per Ingo Molnar's feedback on a related Linux kernel
patch queue, it is desired to always use CPUID in its capitalized form.

- Fix all instances at the XML database's CPUID bitfield descriptions.

- Remove small case "cpuid" from the project's ``hunspell(5)``
  dictionary, thus preventing its usage in future commits via CI.


Release v2.1
------------

- Add spellchecking and x86 terminology style enforcement for all CPUID
  bitfield descriptions in the XML database.  Build multiple
  x86-specific ``hunspell(5)`` dictionary and affix files for such
  enforcement.

- Use such logic to standardize the style for x86 trademarks, registers,
  opcodes, byte units, hexadecimal digits, and x86 abbreviated and
  non-abbreviated technical terms.

- Similarly, refuse abbreviated terms that might be OK in code but not
  in official listings (e.g., "addr", "instr", "reg", "virt", etc.)

- Introduce ``scripts/spellcheck_xml.sh`` to automate the hunspell
  invocation, and add it to the project's CI pipeline.

- Update the CPUID database:

  - Leaf ``0xd``: Apply vendor fixes from Andrew Cooper (Xen / Citrix)

  - Leaf ``0x80000020/0x80000021``: Add new Zen5 SoC bits.  Thanks to
    Avadhut Naik (AMD).

  - Leaf ``0x7``: Add new NMI source reporting bit.  Thanks to Sohil
    Mehta (Intel).

  - All leaves: Fix all issues identified by the new ``hunspell(5)``
    pipeline.


Release v2.0
------------

- Introduce a new transformer, ``kheaders.xslt``, which generates one
  Linux kernel C header file for all the 63 cpuid leaves' bitfields.

  Introduce the cpuidgen ``--kheaders`` option to invoke that new
  transformer.

- Extend cpuid database bitfields coverage:

  - Add Transmeta vendor tags to the appropriate bitfields at leaves
    ``0x0``, ``0x01``, and from ``0x80000000`` to ``0x80000006``.

  - Add Transmeta's CPUID leaves ``0x03``, ``0x80860000`` to
    ``0x80860007``.

  - Add Centaur/Zhaoxin leaves ``0xc0000000`` and ``0xc0000001``, along
    with Zhoaxin's exclusive feature bits.

- Add some documentation for the ``<linux>`` tag, due to earlier related
  questions on the x86-cpuid mailing list.

Changes to generated files styling
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Beside the aforementioned extra cpuid leaves and bitfields, the
generated Linux kernel C structures has changed from:

.. code-block:: c

      /*
       * CPUID leaf 0
       */

      struct leaf0_sl0 {
          ...;
      };

to:

.. code-block:: c

      /*
       * Leaf 0x0
       * Maximum standard leaf number + CPU vendor string
       */

      struct leaf_0x0_0 {
          ...;
      };

For consistency, the generated CSVs now also always prints a ``0x``
prefix for the leaf ID.  Thus, for the leaves ``0x0 => 0x9``, the CSV
output has changed from:

.. code-block:: shell

   0,       0,  eax,    31:0,  max_std_leaf  , Highest cpuid standard leaf supported

to:

.. code-block:: shell

   0x0,     0,  eax,    31:0,  max_std_leaf  , Highest cpuid standard leaf supported

This also matches, in spirit, the C structure naming changes.


Release v1.0
------------

- Prepend the workspace's ``git describe`` string, as a tag, to all
  generated output.

- Document generated files' tagging conventions; i.e., the SPDX license
  tag and the aforementioned workspace git describe tag.

- Add minor Python refactorings and type annotations fixes.

- Add a GitLab CI file which:

  - Validates, schema-wise, all of the project's XML files
  - Runs coding style checks over such XML files
  - Runs FSFE REUSE licensing compliance checks for the whole project
  - Compile-tests all generated kernel headers
  - Runs ``mypy`` strict static typing checks on all Python code
  - Deploys the project's generated files into GitLab's "downloads" area


PRE-Release v1.0-rc1
--------------------

Prepare for project's first release

- Describe all known CPUID leaves bitfields in an XML format and put them
  under ``db/xml/leaf_*.xml``.  This covers:

  - 52 CPUID leaves
  - 835 specific CPUID bitfields, gathered from multiple vendors
  - 274 Linux x86 feature and ``/proc/cpuinfo`` flags
  - 198 Xen hypervisor feature flags

- Introduce XSD schemas for all the project's XML files and put them under
  ``db/schema/``.

- Introduce XSLT transformers on top of such XML files

  - ``db/xslt/kcpuid.xslt``: Generate a Linux Kernel kcpuid CSV file
  - ``db/xslt/kheader.xslt``: Generate a Linux kernel C header file

- Introduce thin Python wrappers to invoke the XSLT transformers

  - ``tools/cpuidgen.py``: Main wrapper (kcpudi CSV and C structures generation)
  - ``tools/xmlgen.py``: XML generator, which was helpful during development

- Introduce internal XML validation and coding style checks

  - ``scripts/validate_xml.sh``: Validate all XML files against their schema
  - ``scripts/check_xml_style.awk``: Ensure consistent coding style for all XMLs

- Add standard project files

  - ``CONTRIBUTING``: Mailing list dev workflow + developercertificate.org
  - ``LICENSE``: Notes on GPLv2, generated files license, and REUSE v3.0
  - ``README``: Preamble, usage, statistics, and references
  - ``CHANGELOG``: This file
