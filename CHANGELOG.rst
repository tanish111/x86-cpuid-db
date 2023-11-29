.. SPDX-FileCopyrightText: 2023 Linutronix GmbH
.. SPDX-License-Identifier: CC0-1.0

Changelog
=========

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

  - ``scripts/validate_xml.sh``: Valide all XML files against their schema
  - ``scripts/check_xml_style.awk``: Ensure consistent coding style for all XMLs

- Add standard project files

  - ``CONTRIBUTING``: Mailing list dev workflow + developercertificate.org
  - ``LICENSE``: Notes on GPLv2, generated files license, and REUSE v3.0
  - ``README``: Preamble, usage, statistics, and references
  - ``CHANGELOG``: This file
