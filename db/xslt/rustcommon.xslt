<!--
    *** SPDX-FileCopyrightText: 2024 Linutronix GmbH
    *** SPDX-License-Identifier: GPL-2.0-only
-->
<xsl:stylesheet
    version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:lx="http://x86-cpuid.org/XSL/local">

    <xsl:import href="rust-common.xslt"/>

    <xsl:template name="xsl:initial-template">
        <xsl:param name="generatedFilesLicense" />
        <xsl:param name="generator" />

        <xsl:value-of select="lx:rust-generate-blurb($generatedFilesLicense, $generator)" />
        <xsl:value-of select="concat('#![allow(dead_code)]', $nl, $nl)" />
        <xsl:value-of select="concat(lx:rust-common-module(), $nl)" />
    </xsl:template>

</xsl:stylesheet>
