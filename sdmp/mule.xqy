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

let $_set := sdmp:set-collection ('jpmc-space')
return 'ha'