xquery version "3.1";

declare namespace json="http://www.json.org";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/javascript";

declare function local:collection($root as xs:anyURI, $level as xs:int) {
    if ($level > 2) then
        ()
    else
        let $resources := (
            for $child in xmldb:get-child-collections($root)
            let $path := $root || "/" || $child
            order by $child ascending
            return
                map {
                    "label": $child,
                    "type": "collection",
                    "icon": "icon-file-directory",
                    "path": $path,
                    "loaded": $level < 2 or empty((xmldb:get-child-collections($path), xmldb:get-child-resources($path))),
                    "children": local:collection($path, $level + 1)
                },
            for $resource in xmldb:get-child-resources($root)
            let $path := $root || "/" || $resource
            let $mime := xmldb:get-mime-type($path)
            order by $resource ascending
            return
                map {
                    "label": $resource,
                    "type": "resource",
                    "icon": if ($mime = ("application/xml", "text/html")) then "icon-file-code" else "icon-file-text",
                    "path": $path,
                    "loaded": true()
                }
        )
        return
            array { $resources }
};

let $root := request:get-parameter("root", "/db")
return
    local:collection($root, 1)
