xquery version '1.0-ml';
declare namespace event = 'http://esereno.com/logging/event';
declare namespace html = 'https://www.w3.org/1999/xhtml';

import module namespace sdmp = 'http://marklogic.com/support/dump' at '/sdmp.xqy';

let $collection-set := sdmp:check-collection-set (fn:true())
let $codepoint := ('collation=http://marklogic.com/collation/codepoint')


return
    (
    xdmp:set-response-content-type('text/html')
    ,
    <html xmlns='https://www.w3.org/1999/xhtml'>
        <body>
        <hr/>
        <h1>forest-space for collection "{$collection-set}"</h1>
        <hr/>
            <h1>Forest space</h1>
            <form action='/dump-forest-space.xqy' method='GET' id='dump' target='forest-space'>
                <input type="submit" value="view" />
            </form>
        <x>{sdmp:db-forest-stand-sizes ()}</x>
        </body>
    </html>
    )
