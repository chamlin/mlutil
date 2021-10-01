<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cts="http://marklogic.com/cts"
    exclude-result-prefixes="xs" version="2.0">

    <xsl:output method="text"/>

    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="cts:docx">
        <xsl:variable name="terms" as="xs:string*"><xsl:apply-templates select="*"/></xsl:variable>
        <xsl:variable name='sorted'><xsl:perform-sort select="$terms"><xsl:sort select="."/></xsl:perform-sort></xsl:variable>
        <xsl:value-of select="$sorted"/>
    </xsl:template>

    <xsl:template match="cts:doc">
        <xsl:variable name="terms" as="xs:string*"><xsl:apply-templates select="*"/></xsl:variable>
        <xsl:variable name='sorted' as="xs:string*"><xsl:perform-sort select="$terms"><xsl:sort select="."/></xsl:perform-sort></xsl:variable>
        <xsl:value-of select="string-join ($sorted, '&#x000D;')"/>
    </xsl:template>

    <xsl:template match="cts:term[not(exists(*))]">
        <xsl:value-of select="concat(@id, '[', @pos, ']')"/>
    </xsl:template>

    <xsl:template match="cts:term">
        <xsl:variable name="id-pos" select="concat(@id, '[', @pos, ']')"/>
        <xsl:variable name="contents">
            <xsl:apply-templates select="*"/>
        </xsl:variable>
        <xsl:value-of select="concat($id-pos, '  =  ', $contents)"/>
    </xsl:template>

    <xsl:template match="cts:element-query">
        <xsl:variable name="ename" select="cts:element/string()"/>
        <xsl:value-of select="concat('&lt;', $ename, '&gt;')"/>
        <xsl:apply-templates select="*"/>
        <xsl:value-of select="concat('&lt;/', $ename, '&gt;')"/>
    </xsl:template>

    <xsl:template match="cts:element-query/cts:element">
        <!-- already take care of by parent -->
    </xsl:template>

    <xsl:template match="cts:element-value-query">
        <xsl:variable name="ename" select="cts:element/string()"/>
        <xsl:variable name="text"
            select="concat(&apos;&quot;&apos;, cts:text/string(), &apos;&quot;&apos;)"/>
        <xsl:value-of select="concat('(', '&lt;', $ename, '&gt;', $text)"/>
        <xsl:apply-templates select="cts:option"/>
        <xsl:text>)</xsl:text>
    </xsl:template>

    <xsl:template match="cts:element-word-query">
        <xsl:variable name="ename" select="cts:element/string()"/>
        <xsl:variable name="text"
            select="concat(&quot;&apos;&quot;, cts:text/string(), &quot;&apos;&quot;)"/>
        <xsl:value-of select="concat('(', '&lt;', $ename, '&gt;', $text)"/>
        <xsl:apply-templates select="cts:option"/>
        <xsl:text>)</xsl:text>
    </xsl:template>

    <xsl:template match="cts:element">
        <xsl:variable name="ename" select="cts:element/string()"/>
        <xsl:value-of select="concat(' HUH? ', $ename)"/>
    </xsl:template>

    <xsl:template match="cts:near-query">
        <xsl:apply-templates select="*[1]"/>
        <xsl:value-of select="concat(' NEAR/', @distance, ' ')"/>
        <xsl:apply-templates select="*[2]"/>
    </xsl:template>

    <xsl:template match="cts:word-query">
        <xsl:variable name="text"
            select="concat(&quot;&apos;&quot;, cts:text/string(), &quot;&apos;&quot;)"/>
        <xsl:value-of select="concat('(', $text)"/>
        <xsl:apply-templates select="cts:option"/>
        <xsl:text>)</xsl:text>
    </xsl:template>

    <xsl:template match="cts:option">
        <xsl:value-of
            select="
                if ((parent::cts:word-query | parent::cts:element-word-query | parent::cts:element-value-query) and not(exists(preceding-sibling::cts:option))) then
                    ' '
                else
                    ''"/>
        <xsl:choose>
            <xsl:when test="text() eq 'case-insensitive'">
                <xsl:text>?c-i</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'case-sensitive'">
                <xsl:text>?c-s</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'diacritic-insensitive'">
                <xsl:text>?d-i</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'diacritic-sensitive'">
                <xsl:text>?d-s</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'unstemmed'">
                <xsl:text>?unstemmed</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'stemmed'">
                <xsl:text>?stemmed</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'wildcarded'">
                <xsl:text>?wild</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'unwildcarded'">
                <xsl:text>?unwild</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'child'">
                <xsl:text>?child</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'descendant-or-self'">
                <xsl:text>?descendant-or-self</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat('?', string(.))"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
