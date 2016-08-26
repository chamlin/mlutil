xquery version '1.0-ml';
declare namespace event = 'http://esereno.com/logging/event';

import module namespace sdmp = 'http://marklogic.com/support/dump' at '/sdmp.xqy';

let $collections := cts:collections()
let $codepoint := ('collation=http://marklogic.com/collation/codepoint')
let $collection-set := xdmp:get-request-field ('coll', ($collections, 'NONE')[1])
let $name := xdmp:get-request-field ('name', 'NONE')

let $sar-coll-name-q := 
    cts:and-query ((
        cts:element-value-query (xs:QName ('event:type'), 'sar'),
        cts:collection-query ($collection-set),
        cts:element-range-query (xs:QName ('event:name'), '=', $name, $codepoint)
    ))

let $node-ref := cts:element-reference (xs:QName ('event:node'), $codepoint)
let $value-ref := cts:element-reference (xs:QName ('event:value'))
let $dt-ref := cts:element-reference (xs:QName ('event:timestamp'))
let $nodes := cts:values ($node-ref, (), ('ascending'), $sar-coll-name-q)
let $name-q := cts:element-range-query (xs:QName ('event:name'), '=', $name, $codepoint)

return
    (
    xdmp:set-response-content-type('text/html')
    ,
    <html xmlns='https://www.w3.org/1999/xhtml'>
        <body>
        <hr/>
            <h1>SAR (collection = {$collection-set}, name = {$name})</h1>
        <hr/>{
            (: let $value-map := local:get-table-value-map ($dt-ref, $node-ref, $value-ref, $sar-coll-name-q) :)
            <table border='1'>{
            <caption>$count values</caption>,
            <tr>{('datetime', $nodes) ! <th>{.}</th>}</tr>,
            for $ts in cts:values ($dt-ref, (), ('ascending'), $sar-coll-name-q)
            let $ts-q := cts:and-query (($sar-coll-name-q, cts:element-range-query (xs:QName ('event:timestamp'), '=', $ts)))
            let $node-value-map :=
                let $_map := map:map ()
                let $_ :=
                    for $tuple in cts:value-tuples (($node-ref, $value-ref), (), $ts-q)
                    let $vals := json:array-values ($tuple)
                    let $node := $vals[1]
                    let $value := $vals[2]
                    let $frequency := cts:frequency ($tuple)
                    return
                        if (map:contains ($_map, $node)) then 
                            let $current := map:get ($_map, $node)
                            return (
                                map:put ($current, 'total', fn:sum ((map:get ($current, 'total'), ($value * $frequency)))),
                                map:put ($current, 'count', fn:sum ((map:get ($current, 'count'), 1))),
                                map:put ($current, 'values', ((map:get ($current, 'values'), $value)))
                            )
                        else
                            let $new := map:new ((
                                map:entry ('total', ($value * $frequency)),
                                map:entry ('count', 1),
                                map:entry ('values', $value)
                            ))
                            return map:put ($_map, $node, $new)
                return $_map
            return
                <tr>{
                    <td>{$ts}</td>,
                    for $node in $nodes
                    let $value-map := map:get ($node-value-map, $node)
                    return
                        if (fn:exists ($value-map)) then
                            let $values := map:get ($value-map, 'values')
                            let $count := map:get ($value-map, 'count')
                            return
                                if ($count > 1) then
                                    let $min := fn:min ($values)
                                    let $max := fn:max ($values)
                                    return <td>{$min} -> {$max}</td>
                                else
                                    <td>{$values}</td>
                        else
                            <td/>
                }</tr>
(:
            for $node in cts:values ($node-ref, (), ('ascending'), $sar-coll-name-q)
            let $node-values-at-time-q := cts:and-query ((
                $sar-coll-name-q,
                cts:element-range-query (xs:QName ('event:timestamp'), '=', $ts),
                cts:element-range-query (xs:QName ('event:node'), '=', $node, $codepoint)
            ))
            let $node-values := cts:values ($value-ref, (), (), $node-values-at-time-q)
            return ($ts||'/'||$node||': ', $node-values)
:)
            }</table>
        }<hr/>

        </body>
    </html>
    )
