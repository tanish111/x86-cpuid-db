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

        <xsl:value-of select="concat('pub struct CpuidFeature {', $nl)" />
        <xsl:value-of select="concat($tab, 'pub leaf: u32,', $nl)" />
        <xsl:value-of select="concat($tab, 'pub subleaf: u32,', $nl)" />
        <xsl:value-of select="concat($tab, 'pub shift: u8,', $nl)" />
        <xsl:value-of select="concat($tab, 'pub width: u8,', $nl)" />
        <xsl:value-of select="concat('}', $nl, $nl)" />

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

    <xsl:function name="lx:rust-feature-name" as="xs:string">
        <xsl:param name="bitfield" as="element()" />

        <xsl:variable name="feature-id" select="if ($bitfield/linux[@altid]) then $bitfield/linux/@altid else $bitfield/@id" />

        <xsl:sequence select="concat('X86_FEATURE_', lx:rust-ident($feature-id))" />
    </xsl:function>

    <xsl:function name="lx:rust-cpuid-const-name" as="xs:string">
        <xsl:param name="leaf-id" as="xs:string" />
        <xsl:param name="subleaf-id" as="xs:string" />
        <xsl:param name="register-name" as="xs:string" />
        <xsl:param name="bitfield" as="element()" />

        <xsl:sequence select="concat(
                              'CPUID_',
                              upper-case(lx:sanitize-hex-id($leaf-id)), '_',
                              upper-case($subleaf-id), '_',
                              upper-case($register-name), '_',
                              lx:rust-ident($bitfield/@id))" />
    </xsl:function>

    <xsl:function name="lx:rust-cpuid-feature-expr" as="xs:string">
        <xsl:param name="leaf-id" as="xs:string" />
        <xsl:param name="subleaf-id" as="xs:integer" />
        <xsl:param name="start-bit" as="xs:integer" />
        <xsl:param name="width" as="xs:integer" />

        <xsl:sequence select="concat(
                              'CpuidFeature {', $nl,
                              $tab, 'leaf: ', $leaf-id, ',', $nl,
                              $tab, 'subleaf: ', $subleaf-id, ',', $nl,
                              $tab, 'shift: ', $start-bit, ',', $nl,
                              $tab, 'width: ', $width, ',', $nl,
                              '}' )" />
    </xsl:function>

    <xsl:template match="leaf">
        <xsl:value-of select="concat('// Leaf ', @id, ': ', desc, $nl, $nl)" />

        <xsl:apply-templates select="subleaf">
            <xsl:with-param name="leaf-id" select="@id" />
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="subleaf">
        <xsl:param name="leaf-id" as="xs:string" />

        <xsl:variable name="subleaf-id" select="xs:integer(@id)" />

        <xsl:apply-templates select="eax | ebx | ecx | edx">
            <xsl:with-param name="leaf-id" select="$leaf-id" />
            <xsl:with-param name="subleaf-id" select="$subleaf-id" />
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="eax | ebx | ecx | edx">
        <xsl:param name="leaf-id" as="xs:string" />
        <xsl:param name="subleaf-id" as="xs:integer" />

        <xsl:variable name="register-name" select="name()" />

        <xsl:apply-templates select="*[starts-with(local-name(), 'bit')]">
            <xsl:with-param name="leaf-id" select="$leaf-id" />
            <xsl:with-param name="subleaf-id" select="$subleaf-id" />
            <xsl:with-param name="register-name" select="$register-name" />
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="*[starts-with(local-name(), 'bit')]">
        <xsl:param name="leaf-id" as="xs:string" />
        <xsl:param name="subleaf-id" as="xs:integer" />
        <xsl:param name="register-name" as="xs:string" />

        <xsl:variable name="start-bit" select="lx:get-bitfield-startbit(.)" />
        <xsl:variable name="width" select="xs:integer(@len)" />
        <xsl:variable name="is-feature" select="exists(linux[@feature = 'true'])" />
        <xsl:variable name="const-name" select="if ($is-feature)
                                                then lx:rust-feature-name(.)
                                                else lx:rust-cpuid-const-name($leaf-id, string($subleaf-id), $register-name, .)" />

        <xsl:value-of select="concat('/// ', if (@desc) then @desc else @id, $nl)" />
        <xsl:value-of select="concat('pub const ', $const-name, ': CpuidFeature = ', lx:rust-cpuid-feature-expr($leaf-id, $subleaf-id, $start-bit, $width), ';', $nl, $nl)" />
    </xsl:template>
</xsl:stylesheet>
