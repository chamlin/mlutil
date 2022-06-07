<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cts="http://marklogic.com/cts" xmlns:xdmp="http://marklogic.com/xdmp"
    exclude-result-prefixes="xs" version="2.0">

    <xsl:output method="text"/>

    <xsl:template match="@* | node()">
        <xsl:value-of select="concat ('>>>> ', node-name (.), ': ', string(.))"/>
    </xsl:template>

    <xsl:template match="cts:doc">
        <!--<xsl:variable name="terms" as="xs:string*"><xsl:apply-templates select="*[position() >= 0 and not(position() > 1000)]"/></xsl:variable>-->
        <xsl:variable name="terms" as="xs:string*"><xsl:apply-templates select="*"/></xsl:variable>
        <xsl:variable name='sorted' as="xs:string*"><xsl:perform-sort select="distinct-values($terms)"><xsl:sort select="."/></xsl:perform-sort></xsl:variable>
        <xsl:value-of select="string-join ($sorted, '&#x000A;')"/>
    </xsl:template>

    <xsl:template match="cts:term[not(exists(*))]">
        <xsl:value-of select="concat('cts:term-query(', @id, ')[', @pos, ']')"/>
    </xsl:template>
    
    <xsl:template match="cts:and-query[not(exists(*))]">
        <xsl:value-of select="'cts:and-query()'"/>
    </xsl:template>

    <xsl:template match="cts:term">
        <xsl:variable name="contents">
            <xsl:apply-templates select="*"/>
        </xsl:variable>
        <xsl:value-of select="concat($contents, '   = cts:term-query(', @id, ')[', @pos, ']')"/>
    </xsl:template>

    <xsl:template match="cts:element-query">
        <xsl:variable name="ename" select="cts:element/string()"/>
        <xsl:variable name="options" as="xs:string*"><xsl:call-template name="get-options"/></xsl:variable>
        <xsl:value-of select="concat('cts:element-query(xs:QName(', &apos;&quot;&apos;, $ename, &apos;&quot;&apos;, '), ')"/>
        <xsl:apply-templates select="child::element()[2]"/>
        <xsl:value-of select="concat (', (', $options, '))')"/>
    </xsl:template>
    
    <xsl:template match="cts:element-attribute-word-query">
        <xsl:variable name="ename" select="cts:element/string()"/>
        <xsl:variable name="aname" select="cts:attribute/string()"/>
        <xsl:variable name="options" as="xs:string*"><xsl:call-template name="get-options"/></xsl:variable>
        <xsl:value-of select="concat('cts:element-attribute-word-query(xs:QName(', &apos;&quot;&apos;, $ename, &apos;&quot;&apos;, '), xs:QName(', &apos;&quot;&apos;, $aname, &apos;&quot;&apos;, '), ')"/>
        <xsl:value-of select="concat (&apos;&quot;&apos;, cts:text/string(), &apos;&quot;&apos;, ', ')"/>
        <xsl:value-of select="concat (', (', $options, '))')"/>
    </xsl:template>

    <xsl:template match="cts:element-attribute-value-query">
        <xsl:variable name="ename" select="cts:element/string()"/>
        <xsl:variable name="aname" select="cts:attribute/string()"/>
        <xsl:variable name="options" as="xs:string*"><xsl:call-template name="get-options"/></xsl:variable>
        <xsl:value-of select="concat('cts:element-attribute-value-query(xs:QName(', &apos;&quot;&apos;, $ename, &apos;&quot;&apos;, '), xs:QName(', &apos;&quot;&apos;, $aname, &apos;&quot;&apos;, '), ')"/>
        <xsl:value-of select="concat (&apos;&quot;&apos;, cts:text/string(), &apos;&quot;&apos;, ', ')"/>
        <xsl:value-of select="concat (', (', $options, '))')"/>
    </xsl:template>

    <xsl:template match="cts:element-query/cts:element">
        <!-- already take care of by parent --> 
    </xsl:template>

    <xsl:template match="cts:element-value-query">
        <xsl:variable name="ename" select="cts:element/string(.)"/>
        <xsl:variable name="options" as="xs:string*"><xsl:call-template name="get-options"/></xsl:variable>
        <xsl:variable name="text"
            select="concat('cts:element-value-query(xs:QName(', &apos;&quot;&apos;, $ename, &apos;&quot;&apos;, '), ', &apos;&quot;&apos;, cts:text/string(), &apos;&quot;&apos;, ', (', $options, '))')"/>
        <xsl:value-of select="$text"/>
    </xsl:template>
    
    <xsl:template match="cts:field-value-query">
        <xsl:variable name="fname" select="cts:field/string(.)"/>
        <xsl:variable name="options" as="xs:string*"><xsl:call-template name="get-options"/></xsl:variable>
        <xsl:variable name="text"
            select="concat('cts:field-value-query(xs:QName(', &apos;&quot;&apos;, $fname, &apos;&quot;&apos;, '), ', &apos;&quot;&apos;, cts:text/string(), &apos;&quot;&apos;, ', (', $options, '))')"/>
        <xsl:value-of select="$text"/>
    </xsl:template>
    
    <xsl:template name="get-options" as="xs:string*">
        <xsl:variable name="options" as="xs:string*"><xsl:apply-templates select="cts:option"/></xsl:variable>
        <xsl:variable name="formatted-options" select="concat(&apos;&quot;&apos;, string-join($options, concat(&apos;&quot;&apos;, ',', &apos;&quot;&apos;)), &apos;&quot;&apos;)"/>
        <xsl:value-of select="$formatted-options"/>
    </xsl:template>

    <xsl:template match="cts:element-word-query">
        <xsl:variable name="ename" select="cts:element/string(.)"/>
        <xsl:variable name="options" as="xs:string*"><xsl:call-template name="get-options"/></xsl:variable>
        <xsl:variable name="text"
            select="concat('cts:element-word-query(xs:QName(', &apos;&quot;&apos;, $ename, &apos;&quot;&apos;, '), ', &apos;&quot;&apos;, cts:text/string(), &apos;&quot;&apos;, ', (', $options, '))')"/>
        <xsl:value-of select="$text"/>
    </xsl:template>
    
    <xsl:template match="cts:field-word-query">
        <xsl:variable name="fname" select="cts:field/string(.)"/>
        <xsl:variable name="options" as="xs:string*"><xsl:call-template name="get-options"/></xsl:variable>
        <xsl:variable name="text"
            select="concat('cts:element-field-query(xs:QName(', &apos;&quot;&apos;, $fname, &apos;&quot;&apos;, '), ', &apos;&quot;&apos;, cts:text/string(), &apos;&quot;&apos;, ', (', $options, '))')"/>
        <xsl:value-of select="$text"/>
    </xsl:template>

    <xsl:template match="cts:element">
        <xsl:variable name="s" select="cts:element/string(.)"/>
        <xsl:value-of select="concat(' HUH? cts:element ', s)"/>
    </xsl:template>

    <xsl:template match="cts:near-query">
        <xsl:variable name="queries" as="xs:string*"><xsl:apply-templates select="*[not(string(node-name(.)) eq 'cts:option')]"/></xsl:variable>
        <xsl:variable name="options" as="xs:string*"><xsl:call-template name="get-options"/></xsl:variable>
        <xsl:value-of select="concat ('cts:near-query((', string-join ($queries, ', '), '), ', @distance, ', (', $options, '))')"/>
    </xsl:template>

    <xsl:template match="cts:word-query">
        <xsl:variable name="options" as="xs:string*"><xsl:call-template name="get-options"/></xsl:variable>
        <xsl:variable name="text"
            select="concat('cts:word-query(', &apos;&quot;&apos;, cts:text/string(.), &apos;&quot;&apos;, ', (', $options, '))')"/>
        <xsl:value-of select="$text"/>
    </xsl:template>

    <xsl:template match="cts:option">
        <xsl:choose>
            <xsl:when test="text() eq 'case-insensitive'">
                <xsl:text>c-i</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'case-sensitive'">
                <xsl:text>c-s</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'diacritic-insensitive'">
                <xsl:text>d-i</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'diacritic-sensitive'">
                <xsl:text>d-s</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'unstemmed'">
                <xsl:text>unstem</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'stemmed'">
                <xsl:text>stem</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'wildcarded'">
                <xsl:text>wild</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'unwildcarded'">
                <xsl:text>unwild</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'child'">
                <xsl:text>child</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'descendant-or-self'">
                <xsl:text>desc-or-self</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'ordered'">
                <xsl:text>ordered</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="string(.)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
