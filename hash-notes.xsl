<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cts="http://marklogic.com/cts" xmlns:qry='http://marklogic.com/cts/query'
    xmlns:xdmp="http://marklogic.com/xdmp" exclude-result-prefixes="xs" version="2.0">
    
    <!-- Do something like this, where this xsl is hash-notes.xsl:
                    xquery version "1.0-ml";
                    declare namespace cts='http://marklogic.com/cts';
                    declare namespace qry='http://marklogic.com/cts/query';
                    let $doc := <doc><cc>zhang.victoria@marriott#com</cc></doc>
                    let $options := <options xmlns="cts:train"><use-db-config>true</use-db-config><details>true</details></options>
                    let $hash-terms := cts:hash-terms ($doc, $options)
                    let $query := cts:word-query ('*marriott#com')
                    let $final-plan := xdmp:plan (cts:search (/, $query))//qry:final-plan
                    let $xslt := xdmp:document-get ('/Users/chamlin/git/mlutil/hash-notes.xsl')
                    return (
                    xdmp:xslt-eval ($xslt/*, $final-plan, map:entry ('hash-terms', $hash-terms))
)
    -->

    <xsl:param name="hash-terms" as='element(cts:doc)'/>

    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>
    

    <xsl:template match="qry:key">
        <!--<xsl:value-of select="xdmp:log(concat('inside ', string(node-name(..))))"/>-->
        <xsl:variable name="key" select="string(.)"/>
        <xsl:variable name="hash-term" select="$hash-terms//cts:term[string(@id) eq $key]"/>
        <xsl:variable name="contents">
            <xsl:choose>
                <xsl:when test="exists($hash-term)"><xsl:apply-templates select="$hash-terms//cts:term[string(@id) eq $key]" mode="short"/></xsl:when>
                <!--<xsl:when test="exists($hash-term)"><xsl:value-of select="count($hash-term)"/></xsl:when>-->
                <xsl:otherwise><xsl:text>NOT FOUND!!!!!!!!!!!!!</xsl:text></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:copy-of select="."/>
        <hash-term><xsl:value-of select="$contents"/></hash-term>
        <!--<hash-term><xsl:copy><xsl:apply-templates select="$hash-terms//cts:term[string(@id) eq $key]" mode="short"/></xsl:copy></hash-term>-->
    </xsl:template>
    
    <xsl:template match="cts:term[not(exists(*))]" mode='short'>
        <xsl:value-of select="concat('cts:term-query(', @id, ')[', @pos, ']')"/>
    </xsl:template>
    
    <xsl:template match="cts:term" mode='short'>
        <xsl:variable name="contents">
            <xsl:apply-templates select="*" mode="short"/>
        </xsl:variable>
        <xsl:value-of select="concat($contents, '   = cts:term-query(', @id, ')[', @pos, ']')"/>
    </xsl:template>
    
    <xsl:template match="cts:and-query" mode='short'>
        <xsl:variable name="queries" as="xs:string*"><xsl:apply-templates select="*" mode="short"/></xsl:variable>
        <xsl:value-of select="concat ('cts:and-query((', string-join ($queries, ', '), '))')"/>
    </xsl:template>
    
    <xsl:template match="cts:and-query[not(exists(*))]" mode='short'>
        <xsl:value-of select="'cts:and-query()'"/>
    </xsl:template>

    <xsl:template match="cts:element-query" mode='short'>
        <xsl:variable name="ename" select="cts:element/string()"/>
        <xsl:variable name="options" as="xs:string*"><xsl:call-template name="get-options"/></xsl:variable>
        <xsl:value-of select="concat('cts:element-query(xs:QName(', &apos;&quot;&apos;, $ename, &apos;&quot;&apos;, '), ')"/>
        <xsl:apply-templates select="child::element()[2]"/>
        <xsl:value-of select="concat (', (', $options, '))')"/>
    </xsl:template>
    
    <xsl:template match="cts:element-query/cts:element" mode='short'>
        <!-- already take care of by parent -->
    </xsl:template>
    
    <xsl:template match="cts:element-value-query" mode='short'>
        <xsl:variable name="ename" select="cts:element/string()"/>
        <xsl:variable name="options" as="xs:string*"><xsl:call-template name="get-options"/></xsl:variable>
        <xsl:variable name="text"
            select="concat('cts:element-value-query(xs:QName(', &apos;&quot;&apos;, $ename, &apos;&quot;&apos;, '), ', &apos;&quot;&apos;, cts:text/string(), &apos;&quot;&apos;, ', (', $options, '))')"/>
        <xsl:value-of select="$text"/>
    </xsl:template>
    
    <xsl:template name="get-options" as="xs:string*">
        <xsl:variable name="options" as="xs:string*"><xsl:apply-templates select="cts:option" mode="short"/></xsl:variable>
        <xsl:variable name="formatted-options" select="concat(&apos;&quot;&apos;, string-join($options, concat(&apos;&quot;&apos;, ',', &apos;&quot;&apos;)), &apos;&quot;&apos;)"/>
        <xsl:value-of select="$formatted-options"/>
    </xsl:template>
    
    <xsl:template match="cts:element-word-query" mode='short'>
        <xsl:variable name="ename" select="cts:element/string()"/>
        <xsl:variable name="options" as="xs:string*"><xsl:call-template name="get-options"/></xsl:variable>
        <xsl:variable name="text"
            select="concat('cts:element-word-query(xs:QName(', &apos;&quot;&apos;, $ename, &apos;&quot;&apos;, '), ', &apos;&quot;&apos;, cts:text/string(), &apos;&quot;&apos;, ', (', $options, '))')"/>
        <xsl:value-of select="$text"/>
    </xsl:template>
    
    <xsl:template match="cts:element" mode='short'>
        <xsl:variable name="s" select="cts:element/string()"/>
        <xsl:value-of select="concat(' HUH? cts:element ', s)"/>
    </xsl:template>
    
    <xsl:template match="cts:near-query" mode='short'>
        <xsl:variable name="queries" as="xs:string*"><xsl:apply-templates select="*[not(string(node-name(.)) eq 'cts:option')]" mode="short"/></xsl:variable>
        <xsl:variable name="options" as="xs:string*"><xsl:call-template name="get-options"/></xsl:variable>
        <xsl:value-of select="concat ('cts:near-query((', string-join ($queries, ', '), ') ', @distance, ', (', $options, '))')"/>
    </xsl:template>
    
    <xsl:template match="cts:word-query" mode='short'>
        <xsl:variable name="options" as="xs:string*"><xsl:call-template name="get-options"/></xsl:variable>
        <xsl:variable name="text"
            select="concat('cts:word-query(', &apos;&quot;&apos;, cts:text/string(), &apos;&quot;&apos;, ', (', $options, '))')"/>
        <xsl:value-of select="$text"/>
    </xsl:template>
    
    <xsl:template match="cts:option" mode='short'>
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
            <xsl:when test="text() eq 'whitespace-insensitive'">
                <xsl:text>w-i</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'whitespace-sensitive'">
                <xsl:text>w-s</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'punctuation-insensitive'">
                <xsl:text>p-i</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'punctuation-sensitive'">
                <xsl:text>p-s</xsl:text>
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
            <xsl:when test="text() eq 'ordered'">
                <xsl:text>ordered</xsl:text>
            </xsl:when>
            <xsl:when test="text() eq 'descendant-or-self'">
                <xsl:text>desc-or-self</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="string(.)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
