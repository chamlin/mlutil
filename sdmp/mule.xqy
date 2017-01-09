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


(: do some join of counts/status and put it all together :)
declare function sdmp:forest-status-info () {
    <forest-status-info xmlns='http://marklogic.com/xdmp/status/forest'>{

        for $fstatus in cts:search (/fs:forest-status, $sdmp:collection-query)
        let $fname := $fstatus/fs:forest-name/fn:string()
        let $q := cts:and-query (($sdmp:collection-query, cts:element-value-query (xs:QName ('fs:forest-name'), $fname, 'exact')))
        let $fcounts := cts:search (/fs:forest-counts, $q)
        let $forest-disk-space := fn:sum ($fstatus/fs:stands/fs:stand/fs:disk-size/fn:data())
        return <forest>{
            <forest-name>{$fstatus/fs:forest-name/fn:data()}</forest-name>,
            <forest-id>{$fstatus/fs:forest-id/fn:data()}</forest-id>,
            <device-space>{$fstatus/fs:device-space/fn:data()}</device-space>,
            <data-dir>{$fstatus/fs:data-dir/fn:data()}</data-dir>,
            <host-id>{$fstatus/fs:host-id/fn:data()}</host-id>,
            <disk-space>{$forest-disk-space}</disk-space>
            ,
            let $stands-info := <stands>{
                for $stand in $fcounts/fs:stands-counts/fs:stand-counts
                let $stand-id := $stand/fs:stand-id/fn:data()
                let $stand-status := $fstatus/fs:stands/fs:stand[stand-id eq $stand-id]/fs:disk-size/fn:data()
                let $stand-name := fn:replace ($stand/fs:path, '^.+/', '')
                return
                    <stand>
                        <name>{$stand-name}</name>,
                        <disk-size>{$stand-name}</disk-size>
                        <active-fragment-count>{$stand/fs:active-fragment-count}</active-fragment-count>
                        <deleted-fragment-count>{$stand/fs:deleted-fragment-count}</deleted-fragment-count>
                    </stand>
             }</stands>
             let $active-fragment-count := fn:sum ($stands-info/stand/active-fragment-count)
             let $deleted-fragment-count := fn:sum ($stands-info/stand/deleted-fragment-count)
             let $total-fragment-count :=  $active-fragment-count + $deleted-fragment-count
             let $fmax := 
                if ($total-fragment-count eq 0) then
                    0
                else
                    xs:integer ( ((xs:double ($active-fragment-count) div $total-fragment-count) * $forest-disk-space) * 1.5)
             return (
                     $stands-info,
                     <active-fragment-count>{$active-fragment-count}</active-fragment-count>,
                     <deleted-fragment-count>{$deleted-fragment-count}</deleted-fragment-count>,
                     <total-fragment-count>{$total-fragment-count}</total-fragment-count>,
                     <fmax>{$fmax}</fmax>,
                     <one-point-five>{$fmax * 1.5}</one-point-five>
             )
         }</forest>
    }</forest-status-info>
};

(:
    map -> { data-dir } -> { size } -> [ host-ids ]
:)
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
let $s := sdmp:get-config-file ('databases.xml')
let $fs-info := sdmp:forest-status-info()
let $hosts := sdmp:hosts-ids ()
return sdmp:forest-status-info()


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