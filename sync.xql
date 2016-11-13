xquery version "3.1";

declare namespace json="http://www.json.org";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/javascript";

declare function local:collection($root as xs:anyURI, $relPath as xs:string?, $timestamp as xs:dateTime?) {
    let $resources := (
        for $child in xmldb:get-child-collections($root)
        let $path := $root || "/" || $child
        let $relPath := string-join(($relPath, $child), "/")
        order by $child ascending
        return
            map {
                "path": $child,
                "children": local:collection($path, $relPath, $timestamp),
                "lastModified": xmldb:created($path)
            },
        for $resource in xmldb:get-child-resources($root)
        let $path := $root || "/" || $resource
        let $mime := xmldb:get-mime-type($path)
        let $lastModified := 
            try {
                xmldb:last-modified($root, $resource)
            } catch * {
                current-dateTime()
            }
        where empty($timestamp) or ($lastModified > $timestamp)
        order by $resource ascending
        return
            map {
                "path": $resource,
                "lastModified": $lastModified
            }
    )
    return
        array { $resources }
};

let $timestampParam := request:get-parameter("timestamp", ())
let $timestamp := if ($timestampParam) then xs:dateTime($timestampParam) else ()
let $root := request:get-parameter("root", "/db")
return
    map {
        "root": $root,
        "timestamp": current-dateTime(),
        "children": local:collection(xs:anyURI($root), (), $timestamp)
    }
