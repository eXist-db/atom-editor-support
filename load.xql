xquery version "3.0";

let $path := xmldb:encode(request:get-parameter("path", ()))
let $mime := xmldb:get-mime-type($path)
let $isBinary := util:is-binary-doc($path)
(: Disable betterFORM filter :)
let $attribute := request:set-attribute("betterform.filter.ignoreResponseBody", "true")
let $header := response:set-header("Content-Type", if ($mime) then $mime else "application/binary")
return
    if ($isBinary) then
        let $data := util:binary-doc($path)
        return
            response:stream-binary($data, $mime, ())
    else
        let $doc := doc($path)
        return
            if ($doc) then
                $doc
            else
                response:set-status-code(404)