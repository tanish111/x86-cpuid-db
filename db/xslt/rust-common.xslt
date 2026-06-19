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

    <xsl:function name="lx:rust-generate-blurb" as="xs:string">
        <xsl:param name="license" as="xs:string" />
        <xsl:param name="generator" as="xs:string" />

        <xsl:value-of select="concat(
                              '// SPDX-License-Identifier: ', $license, $nl,
                              '// Generator: '               , $generator, $nl, $nl,
                              '// Auto-generated file.',                        $nl,
                              '// Please submit all updates and bugfixes to https://x86-cpuid.org', $nl, $nl)" />
    </xsl:function>

    <xsl:function name="lx:rust-register-variant" as="xs:string">
        <xsl:param name="register-name" as="xs:string" />

        <xsl:choose>
            <xsl:when test="$register-name = 'eax'"><xsl:sequence select="'CpuidRegister::Eax'" /></xsl:when>
            <xsl:when test="$register-name = 'ebx'"><xsl:sequence select="'CpuidRegister::Ebx'" /></xsl:when>
            <xsl:when test="$register-name = 'ecx'"><xsl:sequence select="'CpuidRegister::Ecx'" /></xsl:when>
            <xsl:when test="$register-name = 'edx'"><xsl:sequence select="'CpuidRegister::Edx'" /></xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="error((), concat('Unknown CPUID register: ', $register-name))" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="lx:rust-common-module" as="xs:string">
        <xsl:sequence select="concat(
                              '#[derive(Clone, Copy, Debug, PartialEq, Eq)]', $nl,
                              '#[repr(u8)]', $nl,
                              'pub enum CpuidRegister {', $nl,
                              $tab, 'Eax = 0,', $nl,
                              $tab, 'Ebx = 1,', $nl,
                              $tab, 'Ecx = 2,', $nl,
                              $tab, 'Edx = 3,', $nl,
                              '}', $nl, $nl,

                              'impl CpuidRegister {', $nl,
                              $tab, '#[must_use]', $nl,
                              $tab, 'pub const fn select(self, eax: u32, ebx: u32, ecx: u32, edx: u32) -> u32 {', $nl,
                              $tab, $tab, 'match self {', $nl,
                              $tab, $tab, 'Self::Eax => eax,', $nl,
                              $tab, $tab, 'Self::Ebx => ebx,', $nl,
                              $tab, $tab, 'Self::Ecx => ecx,', $nl,
                              $tab, $tab, 'Self::Edx => edx,', $nl,
                              $tab, $tab, '}', $nl,
                              $tab, '}', $nl,
                              '}', $nl, $nl,

                              '#[derive(Clone, Copy, Debug, PartialEq, Eq)]', $nl,
                              'pub struct CpuidRegs {', $nl,
                              $tab, 'pub eax: u32,', $nl,
                              $tab, 'pub ebx: u32,', $nl,
                              $tab, 'pub ecx: u32,', $nl,
                              $tab, 'pub edx: u32,', $nl,
                              '}', $nl, $nl,

                              '#[derive(Clone, Copy, Debug, PartialEq, Eq)]', $nl,
                              'pub struct CpuidFeature {', $nl,
                              $tab, 'pub leaf: u32,', $nl,
                              $tab, 'pub subleaf: u32,', $nl,
                              $tab, 'pub register: CpuidRegister,', $nl,
                              $tab, 'pub shift: u8,', $nl,
                              $tab, 'pub width: u8,', $nl,
                              '}', $nl, $nl,

                              'impl CpuidFeature {', $nl,
                              $tab, '#[must_use]', $nl,
                              $tab, 'pub const fn field_mask(self) -> u32 {', $nl,
                              $tab, $tab, 'if self.width == 32 {', $nl,
                              $tab, $tab, $tab, 'u32::MAX', $nl,
                              $tab, $tab, '} else {', $nl,
                              $tab, $tab, $tab, '(1u32 &lt;&lt; self.width) - 1', $nl,
                              $tab, $tab, '}', $nl,
                              $tab, '}', $nl, $nl,

                              $tab, '#[must_use]', $nl,
                              $tab, 'pub const fn mask(self) -> u32 {', $nl,
                              $tab, $tab, 'self.field_mask() &lt;&lt; self.shift', $nl,
                              $tab, '}', $nl, $nl,

                              $tab, '#[must_use]', $nl,
                              $tab, 'pub const fn extract(self, regs: CpuidRegs) -> u32 {', $nl,
                              $tab, $tab, '(self.register.select(regs.eax, regs.ebx, regs.ecx, regs.edx) &gt;&gt; self.shift)', $nl,
                              $tab, $tab, '&amp; self.field_mask()', $nl,
                              $tab, '}', $nl, $nl,

                              $tab, '#[must_use]', $nl,
                              $tab, 'pub const fn enabled(self, regs: CpuidRegs) -> bool {', $nl,
                              $tab, $tab, 'self.extract(regs) != 0', $nl,
                              $tab, '}', $nl,
                              '}' )" />
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
        <xsl:param name="register-name" as="xs:string" />
        <xsl:param name="start-bit" as="xs:integer" />
        <xsl:param name="width" as="xs:integer" />

        <xsl:sequence select="concat(
                              'CpuidFeature {', $nl,
                              $tab, 'leaf: ', $leaf-id, ',', $nl,
                              $tab, 'subleaf: ', $subleaf-id, ',', $nl,
                              $tab, 'register: ', lx:rust-register-variant($register-name), ',', $nl,
                              $tab, 'shift: ', $start-bit, ',', $nl,
                              $tab, 'width: ', $width, ',', $nl,
                              '}' )" />
    </xsl:function>

</xsl:stylesheet>
