xquery version "1.0-ml";

import module namespace sdmp = 'http://marklogic.com/support/dump' at '/sdmp.xqy';

declare namespace smeta = 'http://marklogic.com/support/meta';
declare namespace a = 'http://marklogic.com/xdmp/assignments';
declare namespace ho = 'http://marklogic.com/xdmp/hosts';
declare namespace c = 'http://marklogic.com/xdmp/clusters';
declare namespace g = 'http://marklogic.com/xdmp/group';
declare namespace f = 'http://marklogic.com/xdmp/forest';
declare namespace db = 'http://marklogic.com/xdmp/database';
declare namespace hs = 'http://marklogic.com/xdmp/status/host';
declare namespace fs = 'http://marklogic.com/xdmp/status/forest';

declare function sdmp:db-info () {
    let $results := map:map()
    let $db-config := (
        for $db in sdmp:get-config-file ('databases.xml')/db:databases/db:database
        let $db-map :=
            map:entry ('name', $db/db:database-name/fn:data()) +
            map:entry ('id', $db/db:database-id/fn:data()) +
            map:entry ('merge-max-size', $db/db:merge-max-size/fn:data()) +
            map:entry ('merge-min-ratio', $db/db:merge-min-ratio/fn:data()) +
            map:entry ('merge-timestamp', $db/db:merge-timestamp/fn:data()) +
            map:entry ('retain-until-backup', $db/db:retain-until-backup/fn:data()) +
            map:entry ('forest-ids', $db/db:forests/db:forest-id/fn:data())
        return (
            map:put ($results, 'name:'||$db/db:database-name/fn:data(), $db-map),
            map:put ($results, 'id:'||$db/db:database-id/fn:string(), $db-map)
        )
    )
    return $results
    
};



(:

{
    "DBA_MON_Replica2": {
        "data-dir": "/data/MarkLogic",
        "host-id": "13973387445666055785",
        "device-space": 2812605,
        "name": "DBA_MON_Replica2",
        "id": "3745282478058803410",
        "stands": {
            "10052118607267114042": {
                "active": 150657,
                "name": "0000015d",
                "deleted": 0,
                "disk-size": 234
            },
            "13532792807398717798": {
                "active": 693850,
                "name": "00000137",
                "deleted": 0
            },
            "7849641782511800525": {
                "active": 483373,
                "name": "0000015e",
                "deleted": 0
            }
        }
    },
    ...
    
:)
declare function sdmp:forest-status-info () {
    let $results := map:map()
    let $_load_status :=
        for $fstatus in cts:search (/fs:forest-status, $sdmp:collection-query)
        let $fname := $fstatus/fs:forest-name/fn:string()
        let $q := cts:and-query (($sdmp:collection-query, cts:element-value-query (xs:QName ('fs:forest-name'), $fname, 'exact')))
        let $fcounts := cts:search (/fs:forest-counts, $q)
        let $forest-map := 
            let $map :=
                map:entry ('stands', map:map ()) +
                map:entry ('name', $fstatus/fs:forest-name/fn:data()) +
                map:entry ('id', $fstatus/fs:forest-id/fn:data()) +
                map:entry ('device-space', $fstatus/fs:device-space/fn:data()) +
                map:entry ('data-dir', $fstatus/fs:data-dir/fn:data()) +
                map:entry ('host-id', $fstatus/fs:host-id/fn:data())
            let $_add := map:put ($results, $fname, $map)
            return $map
        let $stands-map := map:get ($forest-map, 'stands')
        for $stand in $fcounts/fs:stands-counts/fs:stand-counts
        let $stand-id := $stand/fs:stand-id/fn:data()
        let $stand-status := $fstatus/fs:stands/fs:stand[stand-id eq $stand-id]/fs:disk-size/fn:data()
        let $stand-name := fn:replace ($stand/fs:path, '^.+/', '')
        let $stand-map := 
            map:entry ('name', $stand-name) +
            map:entry ('disk-size', $fstatus/fs:stands/fs:stand[fs:stand-id eq $stand-id]/fs:disk-size/fn:data()) +
            map:entry ('active', $stand/fs:active-fragment-count/fn:data()) +
            map:entry ('deleted', $stand/fs:deleted-fragment-count/fn:data())
        return map:put ($stands-map, fn:string ($stand-id), $stand-map)
    return $results
};

declare function sdmp:host-mount-spaces ($hosts as map:map, $fs-info as map:map) {
    let $results :=
        let $map :=  map:map ()
        let $_init :=
            for $fname in map:keys ($fs-info)
            let $fstat := map:get ($fs-info, $fname)
            let $fdir := map:get ($fstat, 'data-dir')
            let $fhost := map:get ($fstat, 'host-id')
            let $space := map:get ($fstat, 'device-space')
            return
                let $dir-map :=
                    if (fn:exists (map:get ($map, $fdir))) then 
                        map:get ($map, $fdir)
                    else
                        let $new-map := map:map ()
                        return (
                            map:put ($map, $fdir, $new-map),
                            $new-map
                        )
                return map:put ($dir-map, fn:string ($space), (map:get ($dir-map, fn:string ($space)), $fhost))
        return $map
    return $results
};

let $_set := sdmp:set-collection ('jpmc-space')
let $db-info := sdmp:db-info()
let $fs-info := sdmp:forest-status-info()
let $hosts := sdmp:hosts-ids ()
return <x>{sdmp:host-mount-spaces($hosts, $fs-info)}</x>


(:

xquery version "1.0-ml";
declare namespace f = 'http://marklogic.com/xdmp/status/forest';
declare option xdmp:mapping "false";

declare function local:analyze-forests ($fnames as xs:string+) {
    for $fname in $fnames
    let $fid := xdmp:forest ($fname)
    let $fstatus := xdmp:forest-status ($fid)
    let $fcounts := xdmp:forest-counts ($fid)    
    return local:analyze-forest ($fstatus, $fcounts)
};

declare function local:analyze-forest ($fstatus as element(f:forest-status), $fcounts as element(f:forest-counts)) {
    let $fname1 := $fstatus/f:forest-name/fn:data()
    let $on-disk := fn:sum ($fstatus/f:stands/f:stand/f:disk-size/fn:data())
    let $fname2 := $fcounts/f:forest-name/fn:data()
    let $active-fragments := fn:sum ($fcounts/f:stands-counts/f:stand-counts/f:active-fragment-count/fn:data())
    let $deleted-fragments := fn:sum ($fcounts/f:stands-counts/f:stand-counts/f:deleted-fragment-count/fn:data())
    let $total-fragments := $active-fragments + $deleted-fragments
    let $fmax := 
        if ($total-fragments eq 0) then
            0
        else
            xs:integer ( ((xs:double ($active-fragments) div $total-fragments) * $on-disk) * 1.5)
    let $one-point-five-space := $fmax * 1.5
    let $current-factor-required := 
        if ($on-disk eq 0) then
            0
        else
            $one-point-five-space div $on-disk
    return (
        fn:concat ($fname1, ' active-fragments ', $active-fragments),
        fn:concat ($fname1, ' deleted-fragments ', $deleted-fragments),
        fn:concat ($fname1, ' total-fragments ', $total-fragments),
        fn:concat ($fname1, ' on-disk size ', $on-disk),
        fn:concat ($fname1, ' fmax ', $fmax),
        fn:concat ($fname1, ' one-point-five-space ', $one-point-five-space),
        fn:concat ($fname1, ' current-factor-required ', $current-factor-required)
    )
};


for $fname in (xdmp:forests () ! xdmp:forest-name (.))
order by $fname
return
  let $fstatus := xdmp:forest-status (xdmp:forest ($fname))
  let $fcounts := xdmp:forest-counts (xdmp:forest ($fname))
  return local:analyze-forest ($fstatus, $fcounts)
  
  :)