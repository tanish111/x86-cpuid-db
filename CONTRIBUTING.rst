.. SPDX-FileCopyrightText: 2023 Linutronix GmbH
.. SPDX-License-Identifier: CC0-1.0

Contribution guidelines
=======================

Development mailing list
------------------------

- Please submit all patches to `x86-cpuid@lists.linux.dev`_
- To subscribe, please check `subspace.kernel.org`_
- A public-inbox archive of the mailing list is available here_

A mailing list development workflow is chosen because:

1. It is the preferred method of development for the most-significant
   downstream projects; mainly the Linux Kernel and the Xen hypervisor.

2. Choosing a workflow that matches downstream projects' maintainers
   daily usage is ideal for keeping them in the loop regarding CPUID bit
   changes — especially the security relevant bits.

Please adhere to the Contributor Covenant's `code of conduct`_ during
all facets of project development, including mailing list discussions.

Contributions
-------------

All development must occur on top of the `tip`_ branch.

All patches must have a line in the commit log saying::

    Signed-off-by: Random Developer <random@example.org>

This indicates that you certify the patch under the "Developer's
Certificate of Origin 1.1", as stated at `developercertificate.org`_, and
as copied verbatim at the end of this document.

*Note:* Only known identities are allowed please; i.e., no anonymous
contributions.  This is especially relevant since some contributions
might involve security-related CPUID bits.

REUSE 3.0 compliance
--------------------

This project is fully compliant with `version 3.0 of the REUSE
Specification <https://reuse.software/spec/>`_.

If you create any new files in your submitted patch, please make sure
that such files have the proper SPDX copyright and license tags on top;
i.e., something like:

.. code-block:: python

    # SPDX-FileCopyrightText: 2024 Intel Corporation
    # SPDX-License-Identifier: GPL-2.0-only

Check any of the project's existing XML or Python files for examples.
Afterwards, make sure that the FSFE's reuse tool still `reports success
<https://reuse.readthedocs.io/en/v2.1.0/readme.html#cli>`_.

Testing
-------

Beside the ``reuse`` linting checks earlier mentioned, please make sure
that after applying your patches, below checks still succeed:

.. code-block:: shell

    $ ./scripts/validate_xml.sh
    $ ./scripts/check_xml_style.awk

The former validates that all of the XML files in the repo are valid,
*schema-wise*, while the latter mandates a uniform coding style for all
of them.

*Note:* You can check the ``stage: test`` jobs at the project's CI/CD
pipeline_ for more details.

Developer's Certificate of Origin 1.1
-------------------------------------

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.

.. _`code of conduct`: https://www.contributor-covenant.org/version/2/1/code_of_conduct
.. _`subspace.kernel.org`: https://subspace.kernel.org/lists.linux.dev.html
.. _`x86-cpuid@lists.linux.dev`: mailto:x86-cpuid@lists.linux.dev
.. _developercertificate.org: https://developercertificate.org
.. _here: https://lore.kernel.org/x86-cpuid
.. _tip: https://gitlab.com/x86-cpuid.org/x86-cpuid-db/-/tree/tip
.. _pipeline: .gitlab-ci.yml
