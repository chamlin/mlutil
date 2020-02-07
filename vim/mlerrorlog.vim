if exists("b:current_syntax")
    finish
endif

syntax match timestamp "\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\.\d\d\d"

" any over Notice, per https://docs.marklogic.com/guide/admin/logfiles
syntax match errorlevel ".*\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\.\d\d\d Warning: .*"
syntax match errorlevel ".*\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\.\d\d\d Error: .*"
syntax match errorlevel ".*\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\.\d\d\d Critical: .*"
syntax match errorlevel ".*\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\.\d\d\d Alert: .*"
syntax match errorlevel ".*\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\.\d\d\d Emergency: .*"

" source of prefixes:  https://docs.marklogic.com/guide/messages
syntax match code "ADMIN-[0-9A-Z]\+"
syntax match code "ALERT-[0-9A-Z]\+"
syntax match code "BUILD-[0-9A-Z]\+"
syntax match code "CPF-[0-9A-Z]\+"
syntax match code "DBG-[0-9A-Z]\+"
syntax match code "DHF-[0-9A-Z]\+"
syntax match code "DLS-[0-9A-Z]\+"
syntax match code "FLEXREP-[0-9A-Z]\+"
syntax match code "HADOOP-[0-9A-Z]\+"
syntax match code "ICN-[0-9A-Z]\+"
syntax match code "INFO-[0-9A-Z]\+"
syntax match code "ISYS-[0-9A-Z]\+"
syntax match code "JS-[0-9A-Z]\+"
syntax match code "JSEARCH-[0-9A-Z]\+"
syntax match code "MANAGE-[0-9A-Z]\+"
syntax match code "OI-[0-9A-Z]\+"
syntax match code "PKG-[0-9A-Z]\+"
syntax match code "PKI-[0-9A-Z]\+"
syntax match code "PROF-[0-9A-Z]\+"
syntax match code "RDT-[0-9A-Z]\+"
syntax match code "RESTAPI-[0-9A-Z]\+"
syntax match code "REST-[0-9A-Z]\+"
syntax match code "SEARCH-[0-9A-Z]\+"
syntax match code "SEC-[0-9A-Z]\+"
syntax match code "SER-[0-9A-Z]\+"
syntax match code "SQL-[0-9A-Z]\+"
syntax match code "SSL-[0-9A-Z]\+"
syntax match code "SVC-[0-9A-Z]\+"
syntax match code "TEMPORAL-[0-9A-Z]\+"
syntax match code "THSR-[0-9A-Z]\+"
syntax match code "TRGR-[0-9A-Z]\+"
syntax match code "TS-[0-9A-Z]\+"
syntax match code "VIEW-[0-9A-Z]\+"
syntax match code "X509-[0-9A-Z]\+"
syntax match code "XDMP-[0-9A-Z]\+"
syntax match code "XI-[0-9A-Z]\+"
syntax match code "XSLT-[0-9A-Z]\+"
 

highlight timestamp gui=bold
highlight link code Identifier
highlight link errorlevel Error

let b:current_syntax = "mlerrorlog"
