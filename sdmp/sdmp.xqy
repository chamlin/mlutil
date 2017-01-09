xquery version "1.0-ml";

module namespace sdmp = 'http://marklogic.com/support/dump';

import schema namespace dbpkg = "http://marklogic.com/manage/package/databases"
    at "package-databases.xsd";

import module namespace pkg = "http://marklogic.com/manage/package" 
      at "/MarkLogic/manage/package/package.xqy";

declare namespace smeta = 'http://marklogic.com/support/meta';
declare namespace a = 'http://marklogic.com/xdmp/assignments';
declare namespace ho = 'http://marklogic.com/xdmp/hosts';
declare namespace c = 'http://marklogic.com/xdmp/clusters';
declare namespace g = 'http://marklogic.com/xdmp/group';
declare namespace f = 'http://marklogic.com/xdmp/forest';
declare namespace db = 'http://marklogic.com/xdmp/database';
declare namespace hs = 'http://marklogic.com/xdmp/status/host';
declare namespace fs = 'http://marklogic.com/xdmp/status/forest';

declare variable $sdmp:collection-default as xs:string := 'NONE-GIVEN';
declare variable $sdmp:collection as xs:string? := ();
declare variable $sdmp:collection-query as cts:query := cts:or-query (());

(: game-day bucket go boom, maybe; otherwise return (possibly empty) collection selection :)
declare function sdmp:check-collection-set ($throw as xs:boolean) {
    let $collection := (xdmp:get-request-field ('collection'), xdmp:get-session-field ('collection'))[1]
    let $check := 
        if ($throw and (fn:empty ($collection))) then
            fn:error(xs:QName("ERROR"), "No dump collection set via sdmp:set-collection()")
        else ()
    let $_set := sdmp:set-collection ($collection)
    return $collection
};

declare function sdmp:set-collection ($collection as xs:string?) {
    if (fn:not ($collection)) then () else (
        xdmp:set-session-field ('collection', $collection),
        xdmp:set ($sdmp:collection, $collection),
        xdmp:set ($sdmp:collection-query, cts:collection-query ($collection)),
        if (xdmp:estimate (cts:search (/, $collection-query)) > 0) then () 
        else
            fn:error(xs:QName("SDMP-BADCOLL"), 'collection "'||$collection||'" has no documents')
    )
};

declare function sdmp:get-dump-host () {
    sdmp:get-dump-host ($sdmp:collection)
};

declare function sdmp:get-dump-host ($collection) {
    cts:search (/smeta:Support-Request, $sdmp:collection-query)/smeta:Report-Host/fn:string()
};

(: returns doc node :)
declare function sdmp:get-config-file ($config-file) {
    sdmp:get-config-file ($sdmp:collection, $config-file)
};

(: returns doc (not root node) :)
declare function sdmp:get-config-file ($collection, $config-file) {
    fn:doc (cts:uri-match ('*/Configuration/'||$config-file, ('limit=1'), $sdmp:collection-query))
};

declare function sdmp:get-host-status ($host-id) {
    cts:search (/hs:host-status[ho:host-id eq $host-id], $sdmp:collection-query)
};

declare function sdmp:get-host-iowaits () {
    for $host in cts:search (/ho:host-status, $sdmp:collection-query)
    let $host-name := $host/ho:host-name/fn:data()
    let $iowaits := $host//ho:cpu-stat-iowait/fn:data() ! fn:floor (. + 0.5) ! fn:string()
    order by $host-name
    return (
        $host-name||': '||fn:string-join ($iowaits, ', ') 
    )
};

(: returns doc node :)
declare function sdmp:forest-status-from-id ($fid as xs:long) {
    sdmp:forest-status ($sdmp:collection, cts:element-value-query (xs:QName ('fs:forest-id'), $fid, 'exact'))
};



(: returns doc node :)
declare function sdmp:forest-status-from-name ($fname as xs:string) {
    sdmp:forest-status ($sdmp:collection, cts:element-value-query (xs:QName ('fs:forest-name'), $fname, 'exact'))
};

declare function sdmp:forest-status ($collection as xs:string, $q as cts:query) {
    let $query := cts:and-query ((
        cts:collection-query ($collection),
        cts:element-query (xs:QName ('fs:forest-status'), cts:true-query ()),
        $q
    ))
    return cts:search (fn:doc(), $query)[1]
};

declare function sdmp:db-config ($name as xs:string) {
    let $dbc := sdmp:get-config-file ('databases.xml')/db:databases/db:database[db:database-name eq $name]  
    return
        $dbc
};

(: doesn't get replicas/unattached :)
declare function sdmp:db-forest-sizes () {
    sdmp:db-forest-sizes ($sdmp:collection)
};

declare function sdmp:db-forest-sizes ($collection) {
    let $dbs := sdmp:get-config-file ($collection, 'databases.xml')
    let $assigns := sdmp:get-config-file ($collection, 'assignments.xml')   
    return
        for $db in $dbs/db:databases/db:database
        let $db-name := $db/db:database-name/fn:data()
        for $fid in $db/db:forests/db:forest-id/fn:data()
        let $assignment := $assigns/a:assignments/a:assignment[a:forest-id eq $fid]
        let $fsize := fn:sum (/f:forest-status[f:forest-id eq $fid]/f:stands/f:stand/f:disk-size/fn:data(), 0)
        return fn:concat ($db-name, ' - ', $assignment/a:forest-name/fn:data(), ': ', $fsize, ' MB')
};

(: doesn't get replicas/unattached :)
declare function sdmp:db-forest-stand-sizes () {
    sdmp:db-forest-stand-sizes ($sdmp:collection)
};


declare function sdmp:db-forest-stand-sizes ($collection) {
    let $dbs := sdmp:get-config-file ($collection, 'databases.xml')
    let $assigns := sdmp:get-config-file ($collection, 'assignments.xml')   
    return
        for $db in $dbs/db:databases/db:database
        let $db-name := $db/db:database-name/fn:data()
        for $fid in $db/db:forests/db:forest-id/fn:data()
        let $forest-name := $assigns/a:assignments/a:assignment[a:forest-id eq $fid]/a:forest-name/fn:data()
        let $fstat := sdmp:forest-status ($collection, $fid)
        for $stand in $fstat/f:forest-status/f:stands/f:stand
        let $path := $stand/f:path/fn:data()
        let $size := $stand/f:disk-size/fn:data()
        return fn:concat ($db-name, ' - ', $path, ': ', $size, ' MB')
};

declare function sdmp:create-db-package ($dbname) {
    sdmp:create-db-package ($dbname, ())
};

declare function sdmp:create-db-package ($dbname, $mimetype) {
    let $pkgname := 'sdmp-pkg-'||fn:replace (sem:uuid-string (), '-', 'x')
    let $pkgdb := sdmp:get-package-dbconfig ($dbname)
    return (
        pkg:create ($pkgname),
        pkg:put-database ($pkgname, $pkgdb),
        if ($mimetype) then
            pkg:get-package ($pkgname, $mimetype)
        else
            pkg:get-package ($pkgname),
        pkg:delete ($pkgname)
    )
};

declare function sdmp:create-db-package ($dbname, $dbs, $mimetype) {
    let $pkgname := 'sdmp-pkg-'||fn:replace (sem:uuid-string (), '-', 'x')
    let $pkgdb := sdmp:get-package-dbconfig ($dbname, $dbs)
    return (
        pkg:create ($pkgname),
        pkg:put-database ($pkgname, $pkgdb),
        if ($mimetype) then
            pkg:get-package ($pkgname, $mimetype)
        else
            pkg:get-package ($pkgname),
        pkg:delete ($pkgname)
    )
};

declare function sdmp:get-package-dbconfig ($dbname) as element(dbpkg:package-database) {
    sdmp:get-package-dbconfig ($dbname, sdmp:get-config-file ('databases.xml'))
};

declare function sdmp:get-package-dbconfig ($dbname, $dbs) as element(dbpkg:package-database) {
    let $config := $dbs/db:databases/db:database[db:database-name eq $dbname]
    let $skips := ('db:database-name', 'db:database-id', 'db:security-database', 'db:schema-database', 'db:triggers-database', 'db:forests') ! xs:QName (.)
    let $empties := ('db:database-backups') ! xs:QName (.)
   return
  <package-database xmlns="http://marklogic.com/manage/package/databases">
	<metadata>
		<package-version>2.0</package-version>
		<user>admin</user>
		<group>Default</group>
		<host>{xdmp:hostname()}</host>
		<timestamp>{fn:current-dateTime ()}</timestamp>
		<platform>macosx</platform>
	</metadata>
    <config>
      <name>{$dbname}</name>
      <package-database-properties>{
        for $config-item in $config/*
        where fn:not (fn:node-name($config-item) = $skips)
        return
            if (fn:node-name($config-item) = $empties) then
                element { fn:node-name ($config-item) } {}
            else
                $config-item
      }</package-database-properties>
     <links>
			<forests-list>
				<forest-name>{$dbname}-forest</forest-name>
			</forests-list>
			<security-database>Security</security-database>
			<schema-database>Schemas</schema-database>
		</links>
    </config>
  </package-database>
};
