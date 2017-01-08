xquery version '1.0-ml';
declare namespace event = 'http://esereno.com/logging/event';
declare namespace html = 'https://www.w3.org/1999/xhtml';

import module namespace sdmp = 'http://marklogic.com/support/dump' at '/sdmp.xqy';
let $collections := cts:collections()
let $collection-set := sdmp:check-collection-set (fn:false())
    
let $codepoint := ('collation=http://marklogic.com/collation/codepoint')


return
    (
    xdmp:set-response-content-type('text/html')
    ,
    <html xmlns='https://www.w3.org/1999/xhtml'>
        <body>
        <hr/>
            <h1>Select collection (current: {$collection-set})</h1>
            <form action='/' method='GET' id='collection'>
                <select name='collection' label='collection'>
                    {
                        for $collection in $collections
                        return element { xs:QName ('html:option') } {
                            attribute { 'value' } { $collection },
                            if ($collection eq $collection-set) then attribute { 'selected' } { } else (),
                            $collection
                        }
                    }
                </select>
                <input type="submit" value="Set" />
            </form>
        <hr/>{
            <h1>Support dump (current collection: {$collection-set})</h1>,
            let $q := 
                    cts:and-query ((
                        cts:element-value-query (xs:QName ('event:type'), 'sar'),
                        cts:collection-query ($collection-set)
                    ))
            let $db-doc := sdmp:get-config-file ('databases.xml')
            return (
                if ($db-doc) then 
                    <form action='/dump.xqy' method='GET' id='dump' target='dump'>
                        <input type="submit" value="view" />
                    </form>
                else
                    <p>No dump uploaded for this collection name</p>
            )
        }            
        <hr/>{
            <h1>Sar readings (current collection: {$collection-set})</h1>,
            let $q := 
                    cts:and-query ((
                        cts:element-value-query (xs:QName ('event:type'), 'sar'),
                        cts:collection-query ($collection-set)
                    ))
            let $count := xdmp:estimate (cts:search (/event:event, $q))
            let $name-ref := cts:element-reference (xs:QName ('event:name'), $codepoint)
            let $names := cts:values ($name-ref, (), (), $q)
            return (
                <h1>SAR ({$count} readings)</h1>,
                <form action='/sar.xqy' method='GET' id='sar' target='sar'>
                    <select name='name' label='name'>
                        {
                            $names ! <option value='{.}'>{.}</option>
                        }
                    </select>
                    <input type="hidden" value="{$collection-set}" />
                    <input type="submit" value="view" />
                </form>
            )
        }
        <hr/>
        </body>
    </html>
    )
