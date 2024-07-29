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

        <xsl:value-of        select="lx:c-generate-blurb($generatedFilesLicense, $generator)" />

        <xsl:apply-templates select="leaf">
            <xsl:with-param  name="bitfield-name-padding"
                             select="max(//*[starts-with(local-name(), 'bit')]/string-length(@id))" />
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="leaf">
        <xsl:param           name="bitfield-name-padding" />

        <xsl:value-of        select="concat(
                                     '#ifndef _ASM_X86_CPUID_LEAF_', lx:sanitize-hex-id(@id),          $nl,
                                     '#define _ASM_X86_CPUID_LEAF_', lx:sanitize-hex-id(@id),          $nl, $nl,
                                     '#include &lt;linux/types.h&gt;',                                 $nl, $nl)" />

        <xsl:value-of        select="lx:c-describe-leaf(@id)" />
        <xsl:apply-templates select="subleaf">
            <xsl:with-param  name="bitfield-name-padding"   select="$bitfield-name-padding" />
        </xsl:apply-templates>

        <xsl:value-of        select="concat(                                                           $nl,
                                     '#endif /* _ASM_X86_CPUID_LEAF_', lx:sanitize-hex-id(@id), ' */', $nl)" />
    </xsl:template>
</xsl:stylesheet>
