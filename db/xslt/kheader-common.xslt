<!--
    *** SPDX-FileCopyrightText: 2023-2024 Linutronix GmbH
    *** SPDX-License-Identifier: GPL-2.0-only
-->
<xsl:stylesheet
    version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:lx="http://x86-cpuid.org/XSL/local">

    <xsl:output method="text" />

    <xsl:variable name="tab"                    select="'&#9;'"/>
    <xsl:variable name="nl"                     select="'&#10;'"/>

    <!-- Generate C headers top blurb. -->
    <xsl:function name="lx:c-generate-blurb"    as="xs:string">
        <xsl:param name="license"               as="xs:string" />
        <xsl:param name="generator"             as="xs:string" />

        <xsl:value-of select="concat(
                              '/* SPDX-License-Identifier', ': '  , $license, ' */',                $nl,
                              '/* Generator: '                    , $generator            , ' */',  $nl, $nl,
                              '/*',                                                                 $nl,
                              ' * Auto-generated file.',                                            $nl,
                              ' * Please submit all updates and bugfixes to https://x86-cpuid.org', $nl,
                              ' */',                                                                $nl, $nl)" />
    </xsl:function>

    <!-- Generate leaf description, as a multi-line C comment. -->
    <xsl:function name="lx:c-describe-leaf"     as="xs:string">
        <xsl:param name="leafID"                as="xs:string" />
        <xsl:param name="leafDescription"       as="xs:string" />

        <xsl:value-of select="concat(
                              '/*',                                                                 $nl,
                              ' * Leaf ', $leafID,                                                  $nl,
                              ' * ', $leafDescription,                                              $nl,
                              ' */',                                                                $nl, $nl)" />
    </xsl:function>

    <!--
        *** Helper Functions
    -->

    <!-- Round-up a number to the nearest multiple -->
    <xsl:function name="lx:round-up"            as="xs:decimal">
        <xsl:param name="number"                as="xs:decimal"/>
        <xsl:param name="multiple"              as="xs:decimal"/>

        <xsl:sequence                           select="ceiling($number div $multiple) * $multiple"/>
    </xsl:function>

    <!-- Repeat a string n times -->
    <xsl:function name="lx:repeat"              as="xs:string">
        <xsl:param name="string"                as="xs:string"/>
        <xsl:param name="times"                 as="xs:integer"/>

        <xsl:sequence                           select="string-join((1 to $times) ! $string, '')"/>
    </xsl:function>

    <!-- Sanitize a hexadecimal leaf ID (remove '0x') -->
    <xsl:function name="lx:sanitize-hex-id"     as="xs:string">
        <xsl:param name="id-value"              as="xs:string"/>

        <xsl:sequence                           select="replace(lower-case($id-value), '^0x', '')"/>
    </xsl:function>

    <!-- Sanitize a bitfield name (C bitfields cannot have leading digits) -->
    <xsl:function name="lx:sanitize-bitfield-name" as="xs:string">
        <xsl:param name="name"                  as="xs:string"/>

        <xsl:sequence                           select="replace($name, '^(\d)', '_$1')"/>
    </xsl:function>

    <!-- Extract a bitfield's start bit (For XML elements <bit1>, <bit2>, ..., <bit31>) -->
    <xsl:function name="lx:get-bitfield-startbit" as="xs:integer">
        <xsl:param name="bitfield"              as="element()"/>

        <xsl:sequence                           select="xs:integer(substring-after(local-name($bitfield), 'bit'))"/>
    </xsl:function>

    <!-- For passed register (XML node), return a sequence of all its bitfields (<bitN> elements) -->
    <xsl:function name="lx:get-register-bitfields" as="element()*">
        <xsl:param name="node"                  as="element()"/>

        <xsl:sequence                           select="$node/*[starts-with(local-name(), 'bit')]"/>
    </xsl:function>

    <!-- Calculate the required padding, in tabs, before a C99 bitfield's colon ":" -->
    <xsl:function name="lx:bitfield-colon-padding-ntabs" as="xs:integer">
        <xsl:param name="leafBiggestNameLen"    as="xs:decimal" />
        <xsl:param name="bitfield-name"         as="xs:string" />

        <xsl:variable name="required-padding"   select="lx:round-up($leafBiggestNameLen, 8)" />
        <xsl:sequence                           select="xs:integer(ceiling(
                                                        ($required-padding - string-length($bitfield-name)) div 8))" />
    </xsl:function>

    <!-- Generate a single C99 'reserved' bitfield entry (padding).
         C99 spec: "A bit-field declaration with no declarator, but only a
         colon and a width, indicates an unnamed bit-field."
    -->
    <xsl:function name="lx:generate-reserved-entry"   as="xs:string">
        <xsl:param name="u32"                   as="xs:boolean" />
        <xsl:param name="name-padding"          as="xs:integer" />
        <xsl:param name="len"                   as="xs:integer" />
        <xsl:param name="comma-or-semicolon"    as="xs:string" />

        <xsl:sequence                           select="lx:generate-bitfield($u32, '', $name-padding, $len, $comma-or-semicolon, 'Reserved')" />
    </xsl:function>

    <!-- Generate a single C99 bitfield entry -->
    <xsl:function name="lx:generate-bitfield"   as="xs:string">
        <xsl:param name="u32"                   as="xs:boolean" />
        <xsl:param name="bitfield-name"         as="xs:string" />
        <xsl:param name="bitfield-name-padding" as="xs:integer" />
        <xsl:param name="bitfield-len"          as="xs:integer" />
        <xsl:param name="comma-or-semicolon"    as="xs:string" />
        <xsl:param name="short-description"     as="xs:string" />

        <xsl:variable name="u32-prefix"
                      select="if ($u32) then concat($tab, 'u32', $tab) else concat($tab, $tab)" />

        <xsl:variable name="colon-padding-ntabs"
                      select="lx:bitfield-colon-padding-ntabs($bitfield-name-padding, $bitfield-name)" />

        <xsl:variable name="bitfield-len-padding"
                      select="if (string-length(xs:string($bitfield-len)) = 1) then ' ' else ''"/>

        <xsl:sequence select="concat($u32-prefix,
                              lx:sanitize-bitfield-name($bitfield-name),
                              lx:repeat($tab, $colon-padding-ntabs), ': ',
                              $bitfield-len-padding, $bitfield-len,
                              $comma-or-semicolon,
                              ' // ', $short-description, $nl)" />
    </xsl:function>

    <!--
        *** Template matches
    -->

    <!-- Subleaf matching: Generate "struct { ... } name;" blocks -->
    <xsl:template match="subleaf">
        <xsl:param                              name="bitfield-name-padding"  as="xs:integer" />

        <xsl:variable name="is-dynamic"         select="exists(@last)"/>
        <xsl:variable name="leafID"             select="ancestor::leaf/@id" />
        <xsl:variable name="subleafID"          select="if ($is-dynamic) then 'n' else @id" />
        <xsl:variable name="subleafNode"        select="." />

        <xsl:value-of                           select="concat('struct leaf_0x', lx:sanitize-hex-id($leafID), '_', $subleafID, ' {', $nl)" />
        <xsl:for-each                           select="tokenize('eax ebx ecx edx')">
            <xsl:variable name="registerName"   select="."/>
            <xsl:variable name="registerNode"   select="$subleafNode/*[local-name() = $registerName]"/>
            <xsl:choose>
                <xsl:when test="$registerNode">
                    <xsl:apply-templates        select="$registerNode">
                        <xsl:with-param         name="name-padding"           select="$bitfield-name-padding" />
                    </xsl:apply-templates>
                </xsl:when>
                <!--
                    *** TODO

                    Create a synthetic child register element for the missing
                    registers so that the "eax | ebx |ecx | edx" template
                    matching rules can be DRY-ed (reused) instead of open
                    coding the generate-full-register-padding mode again here.

                    This can be done by chaining the XSLT transformations: the
                    first transformation in the chain has an identity
                    transformer except for <subleaf>, where the missing child
                    register elements are added.  Afterwards, this sheet's
                    transformations can be applied.

                    The same concept can be used for detecting bitfield
                    reserved areas, thus making this sheet much simpler.
                -->
                <xsl:otherwise>
                    <xsl:value-of               select="concat($tab, '// ', $registerName, $nl)" />
                    <xsl:value-of               select="lx:generate-reserved-entry(true(), $bitfield-name-padding, 32, ';')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        <xsl:value-of                           select="concat('};', $nl)" />
        <xsl:value-of                           select="if (following-sibling::*) then $nl else ''" />
    </xsl:template>

    <!-- Register matching: Generate a "// Register name" line divider -->
    <xsl:template match="eax | ebx | ecx | edx">
        <xsl:param                              name="name-padding"  as="xs:integer" />

        <xsl:value-of                           select="concat($tab, '// ', name(), $nl)" />
        <xsl:if test="empty(lx:get-register-bitfields(.))">
            <xsl:apply-templates                select="current()"
                                                mode="generate-full-register-padding">
                <xsl:with-param                 name="name-padding"  select="$name-padding" />
            </xsl:apply-templates>
        </xsl:if>
        <xsl:apply-templates                    select="lx:get-register-bitfields(.)">
            <xsl:with-param                     name="name-padding"  select="$name-padding" />
        </xsl:apply-templates>
    </xsl:template>

    <!-- Bit matching: Generate the C99 bitfield entries (reserved areas included) -->
    <xsl:template match="*[starts-with(local-name(), 'bit')]">
        <xsl:param                              name="name-padding"  as="xs:integer" />

        <xsl:variable name="startBit"           select="lx:get-bitfield-startbit(.)" />
        <xsl:variable name="endBit"             select="$startBit + xs:integer(@len)"/>

        <xsl:if test="position() = 1 and $startBit > 0">
            <xsl:apply-templates                select="current()"
                                                mode="generate-leading-padding">
                <xsl:with-param                 name="startBit"
                                                select="$startBit"/>
                <xsl:with-param                 name="name-padding"  select="$name-padding" />
            </xsl:apply-templates>
        </xsl:if>

        <xsl:if test="position() > 1">
            <xsl:apply-templates                select="current()"
                                                mode="generate-intra-padding">
                <xsl:with-param                 name="startBit"      select="$startBit"/>
                <xsl:with-param                 name="previousField" select="preceding-sibling::*[1]"/>
                <xsl:with-param                 name="name-padding"  select="$name-padding" />
            </xsl:apply-templates>
        </xsl:if>

        <xsl:apply-templates                    select="current()"
                                                mode="generate-bitfield">
            <xsl:with-param                     name="u32"           select="($startBit = 0)" />
            <xsl:with-param                     name="name"          select="@id" />
            <xsl:with-param                     name="name-padding"  select="$name-padding" />
            <xsl:with-param                     name="len"           select="xs:integer(@len)" />
            <xsl:with-param                     name="delimiter"     select="if (empty(following-sibling::*) and $endBit = 32) then ';' else ','" />
            <xsl:with-param                     name="description"   select="@desc" />
        </xsl:apply-templates>

        <xsl:if test="(empty(following-sibling::*)) and ($endBit &lt; 32)">
            <xsl:apply-templates                select="current()"
                                                mode="generate-trailing-padding">
                <xsl:with-param                 name="endBit"        select="$endBit"/>
                <xsl:with-param                 name="name-padding"  select="$name-padding" />
            </xsl:apply-templates>
        </xsl:if>
    </xsl:template>

    <!-- Generate padding for an entire u32 register -->
    <xsl:mode name="generate-full-register-padding"/>
    <xsl:template match="*"                     mode="generate-full-register-padding">
        <xsl:param                              name="name-padding"  as="xs:integer" />

        <xsl:value-of                           select="lx:generate-reserved-entry(true(), $name-padding, 32, ';')"/>
    </xsl:template>

    <!-- Generate bitfield leading padding (Reserved area) -->
    <xsl:mode name="generate-leading-padding"/>
    <xsl:template match="*"                     mode="generate-leading-padding">
        <xsl:param                              name="startBit"/>
        <xsl:param                              name="name-padding"  as="xs:integer" />

        <xsl:value-of                           select="lx:generate-reserved-entry(true(), $name-padding, $startBit, ',')" />
    </xsl:template>

    <!-- Generate bitfield intra padding (Reserved area) -->
    <xsl:mode name="generate-intra-padding"/>
    <xsl:template match="*"                     mode="generate-intra-padding">
        <xsl:param                              name="startBit" />
        <xsl:param                              name="previousField"/>
        <xsl:param                              name="name-padding"  as="xs:integer" />

        <xsl:variable                           name="previousStartbit"
                                                select="lx:get-bitfield-startbit($previousField)" />
        <xsl:variable                           name="previousEndbit"
                                                select="$previousStartbit + xs:integer($previousField/@len)" />

        <xsl:if test="$startBit > $previousEndbit">
            <xsl:value-of                       select="lx:generate-reserved-entry(false(), $name-padding, $startBit - $previousEndbit, ',')" />
        </xsl:if>
    </xsl:template>

    <!-- Generate trailing padding (Reserved area) -->
    <xsl:mode name="generate-trailing-padding"/>
    <xsl:template match="*"                     mode="generate-trailing-padding">
        <xsl:param                              name="endBit"/>
        <xsl:param                              name="name-padding"  as="xs:integer" />

        <xsl:value-of                           select="lx:generate-reserved-entry(false(), $name-padding, 32 - $endBit, ';')"/>
    </xsl:template>

    <!-- Generate actual bitfield entry -->
    <xsl:mode name="generate-bitfield"/>
    <xsl:template match="*"                     mode="generate-bitfield">
        <xsl:param                              name="u32" />
        <xsl:param                              name="name"/>
        <xsl:param                              name="name-padding"  as="xs:integer" />
        <xsl:param                              name="len" />
        <xsl:param                              name="delimiter" />
        <xsl:param                              name="description" />

        <xsl:value-of                           select="lx:generate-bitfield($u32, $name, $name-padding, $len, $delimiter, $description)" />
    </xsl:template>

</xsl:stylesheet>
