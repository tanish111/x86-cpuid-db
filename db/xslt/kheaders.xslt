<!--
    *** SPDX-FileCopyrightText: 2024 Linutronix GmbH
    *** SPDX-License-Identifier: GPL-2.0-only
-->
<xsl:stylesheet
    version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:lx="http://x86-cpuid.org/XSL/local">

    <xsl:import   href="kheader-common.xslt"/>

    <xsl:function                 name="lx:c-header-top">
        <xsl:value-of             select="concat(
                                          '#ifndef _ASM_X86_CPUID_LEAVES',      $nl,
                                          '#define _ASM_X86_CPUID_LEAVES',      $nl, $nl,
                                          '#include &lt;linux/types.h&gt;',     $nl, $nl)" />
    </xsl:function>

    <xsl:function                 name="lx:c-header-bottom">
        <xsl:value-of             select="concat(
                                          '#endif /* _ASM_X86_CPUID_LEAVES */', $nl)" />
    </xsl:function>

    <xsl:template                 name="xsl:initial-template">
        <xsl:param                name="generatedFilesLicense" />
        <xsl:param                name="generator" />

        <xsl:variable             name="leaf-XML-files"              as="item()*"
                                  select="sort(collection('../xml/?select=leaf_*.xml'), (),
                                          function($doc) { tokenize(base-uri($doc), '/')[last()] })">
        </xsl:variable>
        <xsl:variable             name="leaves-max-bitnameLen-seq"   as="item()*">
            <xsl:apply-templates  select="$leaf-XML-files"           mode="get-leaf-max-bitnameLen" />
        </xsl:variable>
        <xsl:variable             name="leaves-max-bitnameLen"       as="xs:integer">
            <xsl:value-of         select="xs:integer(max($leaves-max-bitnameLen-seq))" />
        </xsl:variable>

        <xsl:value-of             select="lx:c-generate-blurb($generatedFilesLicense, $generator)" />
        <xsl:value-of             select="lx:c-header-top()" />
        <xsl:apply-templates      select="$leaf-XML-files"           mode="dump-leaf-bitfields">
            <xsl:with-param       name="bitfield-name-padding"       select="$leaves-max-bitnameLen"/>
        </xsl:apply-templates>
        <xsl:value-of             select="lx:c-header-bottom()" />
    </xsl:template>

    <xsl:template                 match="leaf"                       mode="get-leaf-max-bitnameLen">
        <xsl:value-of             select="concat(max(//*[starts-with(local-name(), 'bit')]/string-length(@id)), ' ')" />
    </xsl:template>

    <xsl:template                 match="leaf"                       mode="dump-leaf-bitfields">
        <xsl:param                name="bitfield-name-padding"       as="xs:integer" />

        <xsl:value-of             select="lx:c-describe-leaf(@id)" />
        <xsl:apply-templates      select="subleaf">
            <xsl:with-param       name="bitfield-name-padding"       select="$bitfield-name-padding"/>
        </xsl:apply-templates>
        <xsl:value-of             select="$nl" />
    </xsl:template>

</xsl:stylesheet>
