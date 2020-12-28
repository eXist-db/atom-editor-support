xquery version "3.1";

declare namespace api="https://exist-db.org/xquery/vscode/api";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace router="http://exist-db.org/xquery/router";
import module namespace rutil="http://exist-db.org/xquery/router/util";
import module namespace errors="http://exist-db.org/xquery/router/errors";

declare function api:collection($request as map(*)) {
    let $collection := "/" || xmldb:decode-uri($request?parameters?collection)
    return
        array {
            for $childCol in xmldb:get-child-collections($collection)
            return
                map {
                    "type": "collection",
                    "name": $childCol
                },
            for $resource in xmldb:get-child-resources($collection)
            return
                map {
                    "type": "resource",
                    "name": xmldb:decode-uri($resource)
                }
        }
};

declare function api:stat($request as map(*)) {
    let $path := "/" || xmldb:decode-uri($request?parameters?path)
    return
        if (doc-available($path) or util:binary-doc-available($path)) then
            let $collection := replace($path, "^(.*/)[^/]+$", "$1")
            let $resource := replace($path, "^.*/([^/]+)$", "$1")
            return
                map {
                    "type": "resource",
                    "size": xmldb:size($collection, $resource),
                    "ctime": xmldb:created($collection, $resource),
                    "mtime": xmldb:last-modified($collection, $resource)
                }
        else if (xmldb:collection-available($path)) then
            map {
                "type": "collection",
                "ctime": xmldb:created($path)
            }
        else
            router:response(404, "Collection or resource not found: " || $path)
};

declare function api:read-file($request as map(*)) {
    let $resource := "/" || xmldb:decode-uri($request?parameters?path)
    let $mime := xmldb:get-mime-type($resource)
    let $data := 
        if (doc-available($resource)) then
            util:string-to-binary(serialize(doc($resource)))
        else if (util:binary-doc-available($resource)) then
            util:binary-doc($resource)
        else
            ()
    return
        if (exists($data)) then
            response:stream-binary($data, $mime, replace($resource, "^.*/([^/]+)$", "$1"))
        else
            router:response(404, "Resource not found: " || $resource)
};

declare function api:store-file($request as map(*)) {
    let $path := "/" || xmldb:decode-uri($request?parameters?path)
    let $collection := replace($path, "^(.*)/[^/]+$", "$1")
    let $resource := replace($path, "^.*/([^/]+)$", "$1")
    let $binary := $request?body instance of xs:base64Binary
    let $content := 
        if ($binary) then
            $request?body
        else
            util:binary-to-string($request?body)
    return
        map {
            "path": 
                if ($binary) then 
                    xmldb:store-as-binary($collection, $resource, $content)
                else
                    xmldb:store($collection, $resource, $content)
        }
};

declare function api:delete($request as map(*)) {
    let $path := "/" || xmldb:decode-uri($request?parameters?path)
    let $isResource := doc-available($path) or util:binary-doc-available($path)
    let $collection := replace($path, "^(.*)/[^/]+$", "$1")
    let $resource := replace($path, "^.*/([^/]+)$", "$1")
    return
        if ($isResource) then
            xmldb:remove($collection, $resource)
        else if (xmldb:collection-available($path)) then
            xmldb:remove($path)
        else
            error($errors:NOT_FOUND, "Resource or collection not found: " || $path)
};

declare function api:create-collection($request as map(*)) {
    let $path := "/" || xmldb:decode-uri($request?parameters?collection)
    let $parent := replace($path, "^(.*)/[^/]+$", "$1")
    let $new := replace($path, "^.*/([^/]+)$", "$1")
    return
        if (xmldb:collection-available($path)) then
            error($errors:FORBIDDEN, "Collection already exists: " || $path)
        else if (not(xmldb:collection-available($parent))) then
            error($errors:FORBIDDEN, "Parent collection does not exist: " || $parent)
        else
            let $created := xmldb:create-collection($parent, $new)
            return
                router:response(201, "Collection created: " || $created)
};

let $lookup := function($name as xs:string, $arity as xs:integer) {
    function-lookup(xs:QName($name), $arity)
}
return
    router:route("api.json", $lookup)