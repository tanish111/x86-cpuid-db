<!--
*** SPDX-FileCopyrightText: 2023 Linutronix GmbH
*** SPDX-License-Identifier: GPL-2.0-only
-->
<xsl:stylesheet
    version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:lx="http://x86-cpuid.org/XSL/local">

    <xsl:function name="lx:intel-notation-hex" as="xs:string">
        <xsl:param name="hexValue" as="xs:string" />
        <xsl:sequence select="concat(upper-case(replace($hexValue, '^0x', '')), 'H')" />
    </xsl:function>

    <xsl:function name="lx:intel-notation-range" as="xs:string">
        <xsl:param name="start" as="xs:integer" />
        <xsl:param name="end"   as="xs:integer" />
        <xsl:sequence select="if ($start = $end) then string($start) else concat($end, ':', $start)" />
    </xsl:function>

    <xsl:function name="lx:left-pad" as="xs:string">
        <xsl:param name="number" as="xs:string" />
        <xsl:param name="length" as="xs:integer" />
        <xsl:sequence select="string-join((for $i in 1 to ($length - string-length($number)) return ' ', $number))" />
    </xsl:function>

    <xsl:function name="lx:right-pad" as="xs:string">
        <xsl:param name="name" as="xs:string" />
        <xsl:param name="length" as="xs:integer" />
        <xsl:sequence select="string-join(('    ', $name, for $i in 1 to ($length - string-length($name)) return ' '))" />
    </xsl:function>

    <xsl:output method="text" />

    <xsl:variable name="nl"                     select="'&#10;'"/>
    <xsl:variable name="leafPadding"            select="10" />
    <xsl:variable name="subleafPadding"         select="10" />
    <xsl:variable name="regnamePadding"         select="5"  />
    <xsl:variable name="bitrangePadding"        select="8"  />
    <xsl:variable name="shortnamePadding"       select="23" />

    <xsl:template name="xsl:initial-template">
        <xsl:value-of select="concat('# SPDX-License-Identifier', ': ', 'CC0-1.0'                           , $nl,
                                     ''                                                                     , $nl,
                                     '# Auto-generated file.'                                               , $nl,
                                     '# Please submit all updates and bugfixes to https://x86-cpuid.org'    , $nl,
                                     '#'                                                                    , $nl,
                                     '# The basic row format is:'                                           , $nl,
                                     '#'                                                                    ,
                                      lx:left-pad('LEAF,'       , $leafPadding)                             ,
                                      lx:left-pad('SUBLEAVES,'  , $subleafPadding  + 1)                     ,
                                      lx:left-pad('reg,'        , $regnamePadding  + 1)                     ,
                                      lx:left-pad('bits,'       , $bitrangePadding + 1)                     ,
                                      lx:right-pad('short_name' , $shortnamePadding)                        ,
                                     ', long_description'                                                   , $nl)" />

        <xsl:apply-templates select="sort(collection('db/xml/?select=leaf_*.xml'), (),
                                     function($doc) { tokenize(base-uri($doc), '/')[last()] })" />
    </xsl:template>

    <xsl:template match="leaf">
        <xsl:value-of select="concat($nl,
                                     '# Leaf ', lx:intel-notation-hex(@id), $nl,
                                     '# '     , desc,                       $nl, $nl)" />

        <xsl:apply-templates select="subleaf" />
    </xsl:template>

    <xsl:template match="subleaf">
        <xsl:variable name="subleafStart"       select="xs:integer(@id)" />
        <xsl:variable name="subleafEnd"         select="xs:integer(if (@array) then @id + @array - 1 else @id)" />

        <xsl:apply-templates select="eax | ebx | ecx | edx">
            <xsl:with-param name="subleafRange" select="lx:intel-notation-range($subleafStart, $subleafEnd)" />
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="eax | ebx | ecx | edx">
        <xsl:param name="subleafRange" />

        <xsl:apply-templates select="*[starts-with(local-name(), 'bit')]">
            <xsl:with-param name="subleafRange" select="$subleafRange" />
            <xsl:with-param name="registerName" select="name()" />
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="*[starts-with(local-name(), 'bit')]">
        <xsl:param name="subleafRange" />
        <xsl:param name="registerName" />

        <xsl:variable name="leafID"             select="ancestor::leaf/@id" />
        <xsl:variable name="startBit"           select="xs:integer(substring-after(name(), 'bit'))" />
        <xsl:variable name="endBit"             select="$startBit + xs:integer(@len) - 1" />
        <xsl:variable name="bitrange"           select="lx:intel-notation-range($startBit, $endBit)" />
        <xsl:variable name="shortName"          select="@id" />
        <xsl:variable name="description"        select="@desc" />

        <xsl:value-of select="concat(lx:left-pad($leafID,       $leafPadding)      , ','  ,
                                     lx:left-pad($subleafRange, $subleafPadding)   , ','  ,
                                     lx:left-pad($registerName, $regnamePadding)   , ','  ,
                                     lx:left-pad($bitrange,     $bitrangePadding)  , ','  ,
                                     lx:right-pad($shortName,   $shortnamePadding) , ', ' ,
                                     $description, $nl)" />
    </xsl:template>
</xsl:stylesheet>
