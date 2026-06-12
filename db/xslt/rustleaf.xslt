<!--
    *** SPDX-FileCopyrightText: 2024 Linutronix GmbH
    *** SPDX-License-Identifier: GPL-2.0-only
-->
<xsl:stylesheet
    version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:lx="http://x86-cpuid.org/XSL/local">

    <xsl:import href="kheader-common.xslt"/>

    <xsl:template name="xsl:initial-template">
        <xsl:param name="generatedFilesLicense" />
        <xsl:param name="generator" />

        <xsl:value-of select="lx:rust-generate-blurb($generatedFilesLicense, $generator)" />
        <xsl:value-of select="concat('#![allow(dead_code)]', $nl, $nl)" />

        <xsl:apply-templates select="leaf" />
    </xsl:template>

    <xsl:function name="lx:rust-generate-blurb" as="xs:string">
        <xsl:param name="license" as="xs:string" />
        <xsl:param name="generator" as="xs:string" />

        <xsl:value-of select="concat(
                              '// SPDX-License-Identifier: ', $license, $nl,
                              '// Generator: '               , $generator, $nl, $nl,
                              '// Auto-generated file.'                        , $nl,
                              '// Please submit all updates and bugfixes to https://x86-cpuid.org', $nl, $nl)" />
    </xsl:function>

    <xsl:function name="lx:rust-ident" as="xs:string">
        <xsl:param name="name" as="xs:string" />

        <xsl:sequence select="replace(replace(upper-case($name), '[^A-Z0-9_]', '_'), '_+', '_')" />
    </xsl:function>

    <xsl:function name="lx:rust-mask-expr" as="xs:string">
        <xsl:param name="startBit" as="xs:integer" />
        <xsl:param name="width" as="xs:integer" />

        <xsl:sequence select="if ($width = 32)
                              then 'u32::MAX'
                              else if ($width = 1)
                              then concat('1u32 &lt;&lt; ', $startBit)
                              else concat('((1u32 &lt;&lt; ', $width, ') - 1) &lt;&lt; ', $startBit)" />
    </xsl:function>

    <xsl:template match="leaf">
        <xsl:value-of select="concat('pub mod leaf_0x', lx:sanitize-hex-id(@id), ' {', $nl)" />
        <xsl:value-of select="concat($tab, '// Leaf ', @id, $nl)" />
        <xsl:value-of select="concat($tab, '// ', desc, $nl, $nl)" />

        <xsl:apply-templates select="subleaf">
            <xsl:with-param name="leaf-id" select="@id" />
        </xsl:apply-templates>

        <xsl:value-of select="concat('}', $nl, $nl)" />
    </xsl:template>

    <xsl:template match="subleaf">
        <xsl:param name="leaf-id" as="xs:string" />

        <xsl:variable name="is-dynamic" select="exists(@last)" />
        <xsl:variable name="subleaf-id" select="if ($is-dynamic) then 'n' else string(@id)" />

        <xsl:value-of select="concat($tab, 'pub mod subleaf_', $subleaf-id, ' {', $nl)" />
        <xsl:value-of select="concat(lx:repeat($tab, 2), 'pub const SUBLEAF_ID: u32 = ', @id, ';', $nl)" />

        <xsl:if test="$is-dynamic">
            <xsl:value-of select="concat(lx:repeat($tab, 2), 'pub const SUBLEAF_LAST: u32 = ', @last, ';', $nl)" />
        </xsl:if>

        <xsl:if test="desc">
            <xsl:value-of select="concat($tab, $tab, '// ', normalize-space(desc), $nl, $nl)" />
        </xsl:if>

        <xsl:apply-templates select="eax | ebx | ecx | edx">
            <xsl:with-param name="leaf-id" select="$leaf-id" />
            <xsl:with-param name="subleaf-id" select="$subleaf-id" />
        </xsl:apply-templates>

        <xsl:value-of select="concat($tab, '}', $nl, $nl)" />
    </xsl:template>

    <xsl:template match="eax | ebx | ecx | edx">
        <xsl:param name="leaf-id" as="xs:string" />
        <xsl:param name="subleaf-id" as="xs:string" />

        <xsl:variable name="register-name" select="name()" />

        <xsl:value-of select="concat(lx:repeat($tab, 2), 'pub mod ', $register-name, ' {', $nl)" />
        <xsl:if test="desc">
            <xsl:value-of select="concat(lx:repeat($tab, 3), '// ', normalize-space(desc), $nl, $nl)" />
        </xsl:if>

        <xsl:apply-templates select="*[starts-with(local-name(), 'bit')]">
            <xsl:with-param name="leaf-id" select="$leaf-id" />
            <xsl:with-param name="subleaf-id" select="$subleaf-id" />
            <xsl:with-param name="register-name" select="$register-name" />
        </xsl:apply-templates>

        <xsl:value-of select="concat(lx:repeat($tab, 2), '}', $nl, $nl)" />
    </xsl:template>

    <xsl:template match="*[starts-with(local-name(), 'bit')]">
        <xsl:param name="leaf-id" as="xs:string" />
        <xsl:param name="subleaf-id" as="xs:string" />
        <xsl:param name="register-name" as="xs:string" />

        <xsl:variable name="startBit" select="lx:get-bitfield-startbit(.)" />
        <xsl:variable name="width" select="xs:integer(@len)" />
        <xsl:variable name="const-base" select="concat('CPUID_', upper-case(lx:sanitize-hex-id($leaf-id)), '_', upper-case($subleaf-id), '_', upper-case($register-name), '_', lx:rust-ident(@id))" />

        <xsl:value-of select="concat(lx:repeat($tab, 3), '// ', @id, if (@desc) then concat(': ', @desc) else '', $nl)" />
        <xsl:value-of select="concat(lx:repeat($tab, 3), 'pub const ', $const-base, '_SHIFT: u32 = ', $startBit, ';', $nl)" />
        <xsl:value-of select="concat(lx:repeat($tab, 3), 'pub const ', $const-base, '_WIDTH: u32 = ', $width, ';', $nl)" />
        <xsl:value-of select="concat(lx:repeat($tab, 3), 'pub const ', $const-base, '_MASK: u32 = ', lx:rust-mask-expr($startBit, $width), ';', $nl, $nl)" />
    </xsl:template>
</xsl:stylesheet>
