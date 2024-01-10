declare variable $q := '
        ... insert cts:query here ...
';
declare variable $indent := '    ';

declare function local:add-to-value ($result, $value, $to-add) {
    let $now := map:get ($result, $value)
    let $size := fn:count ($now)
    return map:put ($result, $value, (fn:subsequence ($now, 1, $size - 1), $now[$size] + $to-add))
};

declare function local:output ($result, $to-add) {
    if (fn:starts-with ($to-add, 'cts:')) then
        for $i in 1 to map:get ($result, 'depth')
        return map:put ($result, 'result', map:get ($result, 'result') || $indent)
    else (),
    map:put ($result, 'result', map:get ($result, 'result') || $to-add)
};

declare function local:push-to-value ($result, $value, $to-push) {
    map:put ($result, $value, (map:get ($result, $value), $to-push))
};

declare function local:pop-from-value ($result, $value) {
    let $now := map:get ($result, $value)
    let $size := fn:count ($now)
    let $return := $now[$size]
    let $_ := map:put ($result, $value, fn:subsequence ($now, 1, $size - 1))
    return $return
};

declare function local:top-value ($result, $value) {
    let $now := map:get ($result, $value)
    let $size := fn:count ($now)
    return $now[$size]
};

declare function local:dobit ($result, $bit) {
      if (fn:starts-with ($bit, 'cts:')) then (
          if (map:get ($result, 'paren-count') > 0) then (
              local:add-to-value ($result, 'depth', 1),
              local:push-to-value ($result, 'paren-count', 0),
              local:output ($result, '&#x000A;')
          ) else ()
      ) else (
            if ($bit eq '(') then local:add-to-value ($result, 'paren-count', 1) else (),
            if ($bit eq ')') then
                if (local:top-value ($result, 'paren-count') eq 1) then (
                    local:pop-from-value ($result, 'paren-count'),
                    local:add-to-value ($result, 'depth', -1)
                ) else
                    local:add-to-value ($result, 'paren-count', -1)
            else ()
      ),
          local:output ($result, $bit)
};

let $result := map:new ((
    map:entry ('depth', 0),
    map:entry ('paren-count', 0),
    map:entry ('result', '')
))

let $bits := 
    for $bit in (fn:analyze-string ($q, 'cts:[a-z-]+')/*/fn:string())
    return (fn:analyze-string (fn:string($bit), '[()]')/*/fn:string())
let $_work :=
    for $bit in $bits
    return
        local:dobit ($result, $bit)
return 
    map:get ($result, 'result')


