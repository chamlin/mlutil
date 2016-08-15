xquery version '1.0-ml';
declare namespace event = 'http://esereno.com/logging/event';

import module namespace sdmp = 'http://marklogic.com/support/dump' at '/sdmp.xqy';

declare function local:get-table-value-map ($name-ref-, $q) {
    let $value-map := 
        let $_map := map:map ()
        let $_ :=
          for $tuple in cts:value-tuples ($refs, (), $q)
          let $dt := $tuple[1]
          let $name := $tuple[2]
          let $value := $tuple[3]
          return
            if (map:contains ($_map, $name)) then
                
                if (map:contains ($_map, $name)) then
                    map:put ($_map, $name, (map:get ($_map, $name), $subtype))
                else
                    map:put ($_map, $name, $subtype)



                map:put ($_map, $name, (map:get ($_map, $name), $subtype))
            else
                map:put ($_map, $name, $subtype)
        return $_map
}

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
            <h2>nodes: {$nodes}</h2>
        <hr/>{
            <table border='1'>{
            <tr>{$nodes ! <th>{.}</th>}</tr>
(:
            for $ts in cts:values ($dt-ref, (), ('ascending'), $sar-coll-name-q)
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
