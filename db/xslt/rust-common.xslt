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

    <xsl:function name="lx:rust-common-module-docs" as="xs:string">
        <xsl:sequence select="concat(
                              '//! Shared types for generated CPUID leaf modules.', $nl,
                              '//!', $nl,
                              '//! [`CpuidFeature`] describes the location of a bitfield within a CPUID', $nl,
                              '//! leaf/subleaf result.  [`CpuidRegister`] identifies which result register', $nl,
                              '//! contains the field.' )" />
    </xsl:function>

    <xsl:function name="lx:rust-common-module" as="xs:string">
        <xsl:sequence select="concat(
                              '/// CPUID result register (`eax`, `ebx`, `ecx`, or `edx`).', $nl,
                              '#[derive(Clone, Copy, Debug)]', $nl,
                              '#[repr(u8)]', $nl,
                              'pub enum CpuidRegister {', $nl,
                              $tab, '/// Result register `eax`.', $nl,
                              $tab, 'Eax = 0,', $nl,
                              $tab, '/// Result register `ebx`.', $nl,
                              $tab, 'Ebx = 1,', $nl,
                              $tab, '/// Result register `ecx`.', $nl,
                              $tab, 'Ecx = 2,', $nl,
                              $tab, '/// Result register `edx`.', $nl,
                              $tab, 'Edx = 3,', $nl,
                              '}', $nl, $nl,

                              'impl CpuidRegister {', $nl,
                              $tab, '/// Return the value of the register selected by `self`.', $nl,
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

                              '/// Location of a CPUID bitfield within a leaf/subleaf result.', $nl,
                              '#[derive(Clone, Copy, Debug)]', $nl,
                              'pub struct CpuidFeature {', $nl,
                              $tab, '/// CPUID leaf number (input `eax`, including `0x80000000` leaves).', $nl,
                              $tab, 'pub leaf: u32,', $nl,
                              $tab, '/// CPUID subleaf (input `ecx` when applicable, otherwise `0`).', $nl,
                              $tab, 'pub subleaf: u32,', $nl,
                              $tab, '/// Register containing the bitfield.', $nl,
                              $tab, 'pub register: CpuidRegister,', $nl,
                              $tab, '/// Least significant bit index of the field within the register.', $nl,
                              $tab, 'pub shift: u8,', $nl,
                              $tab, '/// Width of the field in bits.', $nl,
                              $tab, 'pub width: u8,', $nl,
                              '}' )" />
    </xsl:function>

    <xsl:function name="lx:rust-ident" as="xs:string">
        <xsl:param name="name" as="xs:string" />

        <xsl:variable name="normalized"
                      select="replace(replace(upper-case($name), '[^A-Z0-9_]', '_'), '_+', '_')" />

        <xsl:sequence select="replace($normalized, '^(\d)', '_$1')" />
    </xsl:function>

    <xsl:function name="lx:rust-feature-name" as="xs:string">
        <xsl:param name="bitfield" as="element()" />

        <xsl:variable name="feature-id" select="if ($bitfield/linux[@altid]) then $bitfield/linux/@altid else $bitfield/@id" />

        <xsl:sequence select="concat('X86_FEATURE_', lx:rust-ident($feature-id))" />
    </xsl:function>

    <xsl:function name="lx:rust-cpuid-const-name" as="xs:string">
        <xsl:param name="bitfield" as="element()" />

        <xsl:sequence select="lx:rust-ident($bitfield/@id)" />
    </xsl:function>

    <xsl:function name="lx:rust-const-name" as="xs:string">
        <xsl:param name="bitfield" as="element()" />

        <xsl:sequence select="if (exists($bitfield/linux[@feature = 'true']))
                              then lx:rust-feature-name($bitfield)
                              else lx:rust-cpuid-const-name($bitfield)" />
    </xsl:function>

    <xsl:function name="lx:rust-cpuid-feature-expr" as="xs:string">
        <xsl:param name="leaf-id" as="xs:string" />
        <xsl:param name="subleaf-id" as="xs:integer" />
        <xsl:param name="register-name" as="xs:string" />
        <xsl:param name="start-bit" as="xs:integer" />
        <xsl:param name="width" as="xs:integer" />
        <xsl:param name="indent" as="xs:string" />

        <xsl:variable name="field-indent" select="concat($indent, $tab)" />

        <xsl:sequence select="concat(
                              'CpuidFeature {', $nl,
                              $field-indent, 'leaf: ', $leaf-id, ',', $nl,
                              $field-indent, 'subleaf: ', $subleaf-id, ',', $nl,
                              $field-indent, 'register: ', lx:rust-register-variant($register-name), ',', $nl,
                              $field-indent, 'shift: ', $start-bit, ',', $nl,
                              $field-indent, 'width: ', $width, ',', $nl,
                              $indent, '}' )" />
    </xsl:function>

    <xsl:template match="*[starts-with(local-name(), 'bit')]" mode="rust-dump-bitfield">
        <xsl:param name="indent" as="xs:string" />

        <xsl:variable name="leaf-id" select="ancestor::leaf/@id" />
        <xsl:variable name="subleaf-id" select="xs:integer(ancestor::subleaf/@id)" />
        <xsl:variable name="register-name" select="parent::node()/name()" />
        <xsl:variable name="start-bit" select="lx:get-bitfield-startbit(.)" />
        <xsl:variable name="width" select="xs:integer(@len)" />
        <xsl:variable name="const-name" select="lx:rust-const-name(.)" />

        <xsl:value-of select="concat($indent, '/// ', if (@desc) then @desc else @id, $nl)" />
        <xsl:value-of select="concat($indent, 'pub const ', $const-name, ': CpuidFeature = ',
                              lx:rust-cpuid-feature-expr($leaf-id, $subleaf-id, $register-name, $start-bit, $width, $indent),
                              ';', $nl, $nl)" />
    </xsl:template>

</xsl:stylesheet>
