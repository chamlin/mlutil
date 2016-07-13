xquery version "1.0-ml";

module namespace sdmp = 'http://marklogic.com/support/dump';

import schema namespace dbpkg = "http://marklogic.com/manage/package/databases"
    at "package-databases.xsd";

import module namespace pkg = "http://marklogic.com/manage/package" 
      at "/MarkLogic/manage/package/package.xqy";

declare namespace smeta = 'http://marklogic.com/support/meta';
declare namespace db = 'http://marklogic.com/xdmp/database';
declare namespace f = 'http://marklogic.com/xdmp/status/forest';
declare namespace a = 'http://marklogic.com/xdmp/assignments';

declare variable $sdmp:collection as xs:string := 'NONE-GIVEN';

declare function sdmp:set-collection ($bar) { xdmp:set ($sdmp:collection, $bar) };

declare function sdmp:get-dump-host () {
    sdmp:get-dump-host ($sdmp:collection)
};

declare function sdmp:get-dump-host ($collection) {
    cts:search (/smeta:Support-Request, cts:collection-query ($collection))/smeta:Report-Host/fn:string()
};

declare function sdmp:get-mangled-dump-host () {
    sdmp:get-mangled-dump-host ($sdmp:collection)
};

declare function sdmp:get-mangled-dump-host ($collection) {
    fn:replace (sdmp:get-dump-host ($collection), '\.', '_')
};

(: returns doc node :)
declare function sdmp:get-config-file ($config-file) {
    sdmp:get-config-file ($sdmp:collection, $config-file)
};

declare function sdmp:get-config-file ($collection, $config-file) {
    let $mangled_host := sdmp:get-mangled-dump-host ($collection)
    let $uri := cts:uri-match ('*/'||$mangled_host||'/*/'||$config-file, (), cts:collection-query ($collection))
    return  fn:doc ($uri)
};

declare function sdmp:main-host-uri-pattern ($filename) {
    sdmp:main-host-uri-pattern ($sdmp:collection, $filename)
};

declare function sdmp:main-host-uri-pattern ($collection, $filename) {
    '*/'||sdmp:get-mangled-dump-host ($collection)||'/*/Forest-Status.xml'
};

(: returns doc node :)
declare function sdmp:get-forest-status ($fid) {
    sdmp:get-forest-status ($sdmp:collection, $fid)
};

declare function sdmp:get-forest-status ($collection, $fid) {
    let $query := cts:and-query ((
        cts:collection-query ($collection),
        cts:element-value-query (xs:QName ('f:forest-id'), fn:string ($fid))
    ))
    let $uri-pattern := sdmp:main-host-uri-pattern($collection, 'Forest-Status.xml')
    let $uri := cts:uri-match ($uri-pattern, (), $query)
    return fn:doc ($uri)
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
        let $fstat := sdmp:get-forest-status ($collection, $fid)
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


declare function sdmp:get-package-dbconfig ($dbname) as element(dbpkg:package-database) {
    let $dbs := sdmp:get-config-file ('databases.xml')
    let $config := $dbs/db:databases/db:database[db:database-name eq 'ABCI']
    let $skips := ('db:database-name', 'db:database-id', 'db:security-database', 'db:schema-database', 'db:triggers-database', 'db:forests') ! xs:QName (.)
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
      <package-database-properties>
        { $config/*[fn:not (fn:node-name() = $skips)] }
      </package-database-properties>
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
