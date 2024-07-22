<!--
    *** SPDX-FileCopyrightText: 2023-2024 Linutronix GmbH
    *** SPDX-License-Identifier: GPL-2.0-only
-->
<xsl:stylesheet
    version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:lx="http://x86-cpuid.org/XSL/local">

    <xsl:import   href="kheader-common.xslt"/>

    <xsl:template name="xsl:initial-template">
        <xsl:param           name="generatedFilesLicense" />
        <xsl:param           name="generator" />
        <xsl:variable        name="leafID"  select="/leaf/@id" />

        <xsl:value-of        select="lx:c-generate-blurb($generatedFilesLicense, $generator)" />

        <xsl:value-of        select="concat(
                                     '/*',                                                                 $nl,
                                     ' * CPUID leaf ', $leafID, ' bitfields description',                  $nl,
                                     ' */',                                                                $nl, $nl,
                                     '#ifndef _ASM_X86_CPUID_LEAF_', lx:sanitize-hex-id($leafID),          $nl,
                                     '#define _ASM_X86_CPUID_LEAF_', lx:sanitize-hex-id($leafID),          $nl, $nl,
                                     '#include &lt;linux/types.h&gt;',                                     $nl, $nl)" />

        <xsl:apply-templates select="//subleaf" />

        <xsl:value-of        select="concat(                                                               $nl,
                                     '#endif /* _ASM_X86_CPUID_LEAF_', lx:sanitize-hex-id($leafID), ' */', $nl)" />
    </xsl:template>
</xsl:stylesheet>
