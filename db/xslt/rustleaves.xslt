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

        <xsl:variable name="leaf-XML-files" as="item()*"
                      select="sort(collection('../xml/?select=leaf_*.xml'), (),
                              function($doc) { tokenize(base-uri($doc), '/')[last()] })" />

        <xsl:variable name="bitfields" as="element()*"
                      select="$leaf-XML-files//leaf//*[starts-with(local-name(), 'bit')]" />

        <xsl:value-of select="lx:rust-generate-blurb($generatedFilesLicense, $generator)" />
        <xsl:value-of select="concat('#![allow(dead_code)]', $nl, $nl)" />
        <xsl:value-of select="concat('use super::common::{CpuidFeature, CpuidRegister};', $nl, $nl)" />

        <xsl:for-each-group select="$bitfields" group-by="lx:rust-const-name(.)">
            <xsl:apply-templates select="current-group()[1]" mode="rust-dump-bitfield">
                <xsl:with-param name="indent" select="''" />
            </xsl:apply-templates>
        </xsl:for-each-group>
    </xsl:template>

</xsl:stylesheet>
