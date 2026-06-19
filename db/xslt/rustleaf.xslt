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
        <xsl:value-of select="concat('use super::common::{CpuidFeature, CpuidRegister};', $nl, $nl)" />

        <xsl:apply-templates select="leaf" />
    </xsl:template>

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
        <xsl:value-of select="concat('pub const ', $const-name, ': CpuidFeature = ', lx:rust-cpuid-feature-expr($leaf-id, $subleaf-id, $register-name, $start-bit, $width), ';', $nl, $nl)" />
    </xsl:template>
</xsl:stylesheet>
