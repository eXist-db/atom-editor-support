xquery version "3.1";

declare namespace json="http://www.json.org";
declare namespace expath="http://expath.org/ns/pkg";
declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/javascript";

declare function local:get-package-uri($path as xs:string) {
    collection($path)//expath:package/@name
};

declare function local:get-icon($mime as xs:string) {
    switch ($mime)
        case "application/xml" case "text/html" return
            "icon-file-code"
        case "image/jpeg" case "image/gif" case "image/png"
        case "image/svg+xml" return
            "icon-file-media"
        case "application/octet-stream" return
            "icon-file-binary"
        case "application/xquery" return
            "icon-gear"
        default return
            "icon-file-text"
};

declare function local:get-permissions($path as xs:string) {
    let $permissions := sm:get-permissions(xs:anyURI($path))/sm:permission
    return
        map {
            "owner": $permissions/@owner,
            "group": $permissions/@group,
            "mode": $permissions/@mode
        }
};

declare function local:collection($root as xs:anyURI, $level as xs:int) {
    if ($level > 2) then
        ()
    else
        let $resources := (
            for $child in xmldb:get-child-collections($root)
            let $path := $root || "/" || $child
            let $package := local:get-package-uri($path)
            let $permissions := local:get-permissions($path)
            order by $child ascending
            return
                map {
                    "label": $child,
                    "type": "collection",
                    "icon": if ($package) then "icon-package" else "icon-file-directory",
                    "path": $path,
                    "loaded": $level < 2 or empty((xmldb:get-child-collections($path), xmldb:get-child-resources($path))),
                    "children": local:collection($path, $level + 1),
                    "package": $package/string(),
                    "permissions": $permissions
                },
            for $resource in xmldb:get-child-resources($root)
            let $path := $root || "/" || $resource
            let $mime := xmldb:get-mime-type($path)
            let $permissions := local:get-permissions($path)
            order by $resource ascending
            return
                map {
                    "label": $resource,
                    "type": "resource",
                    "icon": local:get-icon($mime),
                    "path": $path,
                    "loaded": true(),
                    "permissions": $permissions
                }
        )
        return
            array { $resources }
};

let $root := request:get-parameter("root", "/db")
return
    local:collection($root, 1)
