xquery version "1.0-ml";
declare namespace sdmp = 'http://marklogic.com/support/dump';
declare namespace smeta = 'http://marklogic.com/support/meta';
declare namespace db = 'http://marklogic.com/xdmp/database';
declare namespace f = 'http://marklogic.com/xdmp/status/forest';
declare namespace a = 'http://marklogic.com/xdmp/assignments';

declare function sdmp:get-dump-host ($collection) {
    cts:search (/smeta:Support-Request, cts:collection-query ($collection))/smeta:Report-Host/fn:string()
};

declare function sdmp:get-mangled-dump-host ($collection) {
    fn:replace (sdmp:get-dump-host ($collection), '\.', '_')
};

(: returns doc node :)
declare function sdmp:get-config-file ($collection, $config-file) {
    let $mangled_host := sdmp:get-mangled-dump-host ($collection)
    let $uri := cts:uri-match ('*/'||$mangled_host||'/*/'||$config-file, (), cts:collection-query ($collection))
    return  fn:doc ($uri)
};

(: doesn't get replicas/unattached :)
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

let $collection := 'xyz-slow'
return sdmp:db-forest-sizes ($collection)


