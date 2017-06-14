xquery version "3.1";

declare namespace expath="http://expath.org/ns/pkg";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace dbutil="http://exist-db.org/xquery/dbutil";

declare option output:method "json";
declare option output:media-type "application/json";

declare function local:get-package-root($path as xs:string) {
    for $pkg in collection(repo:get-root())/expath:package[starts-with($path, util:collection-name(.))]
    return
        util:collection-name($pkg)
};

declare function local:get-module-info($script as xs:anyURI) {
    let $data := util:binary-doc($script)
    let $source := util:base64-decode($data)
    where matches($source, "^module\s+namespace", "m")
    return
        let $match :=
            analyze-string($source, "^module\s+namespace\s+([^\s=]+)\s*=\s*['""]([^'""]+)['""]", "m")//fn:match
        return
            map {
                "prefix": $match/fn:group[1]/string(),
                "namespace": $match/fn:group[2]/string(),
                "source": $script,
                "ref": "package"
            }
};

declare function local:scan-modules($pkgRoot as xs:string, $imports as xs:string*) {
    dbutil:find-by-mimetype($pkgRoot, "application/xquery", function($script) {
        for $info in local:get-module-info($script)
        return
            if ($info?namespace = $imports) then
                ()
            else
                $info
    })
};

declare function local:mapped-modules($imports as xs:string*) {
    for $uri in (util:registered-modules(), util:mapped-modules())
    where not($uri = $imports)
    let $module := inspect:inspect-module-uri($uri)
    return
        map {
            "prefix": $module/@prefix,
            "namespace": $module/@uri,
            "source": $module/@location,
            "ref": "global"
        }
};

declare function local:sort($modules as map(*)*) {
    for $module in $modules
    order by $module?prefix, $module?namespace
    return
        $module
};


let $path := request:get-parameter("path", "/db/apps/tei-publisher/modules/lib/ajax.xql")
let $imported := request:get-parameter("uri", ())
let $path := if (starts-with($path, "xmldb:exist://")) then substring-after($path, "xmldb:exist://") else $path
let $pkgRoot := local:get-package-root($path)
let $pkgRoot := if ($pkgRoot) then $pkgRoot else $path
let $modules := (
    local:sort(local:scan-modules($pkgRoot, $imported)),
    local:sort(local:mapped-modules($imported))
)
return
    array {
        $modules
    }
