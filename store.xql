(:
 :  eXide - web-based XQuery IDE
 :
 :  Copyright (C) 2018 Wolfgang Meier
 :
 :  This program is free software: you can redistribute it and/or modify
 :  it under the terms of the GNU General Public License as published by
 :  the Free Software Foundation, either version 3 of the License, or
 :  (at your option) any later version.
 :
 :  This program is distributed in the hope that it will be useful,
 :  but WITHOUT ANY WARRANTY; without even the implied warranty of
 :  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 :  GNU General Public License for more details.
 :
 :  You should have received a copy of the GNU General Public License
 :  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 :)
xquery version "3.0";

declare option exist:serialize "method=json media-type=text/javascript";

declare function local:fix-permissions($collection as xs:string, $resource as xs:string) {
    let $path := concat($collection, "/", $resource)
    let $mime := xmldb:get-mime-type($path)
    return
        if ($mime eq "application/xquery") then
            sm:chmod(xs:anyURI($path), "u+x,g+x,o+x")
        else
            ()
};

declare function local:get-run-path($path) {
    let $appRoot := repo:get-root()
    return
        replace(
            if (starts-with($path, $appRoot)) then
                request:get-context-path() || "/" || request:get-attribute("$exist:prefix") || "/" ||
                substring-after($path, $appRoot)
            else
                request:get-context-path() || "/rest" || $path,
            "/{2,}", "/"
        )
};

declare function local:get-mime-type() {
    let $contentType := request:get-header("Content-Type")
    return
        replace($contentType, "\s*;.*$", "")
};

(:~ Called by the editor to store a document :)
declare function local:store($path as xs:string) {
    let $split := analyze-string($path, "^(.*)/([^/]+)$")//fn:group/string()
    let $collection := $split[1]
    let $resource := $split[2]
    let $mime := local:get-mime-type()
    let $data := request:get-data()
    let $data :=
        if($data instance of xs:base64Binary) then
            $data
        else if($mime and not($data)) then
            util:string-to-binary("")
        else
            $data
    return
        try {
            let $isNew := not(util:binary-doc-available($path)) and not(doc-available($path))
            let $path :=
                if (util:binary-doc-available($path)) then
                    xmldb:store-as-binary($collection, $resource, $data)
                else
                    if ($mime) then
                        xmldb:store($collection, $resource, $data, $mime)
                    else
                        xmldb:store($collection, $resource, $data)
            return (
                if ($isNew) then
                    local:fix-permissions($collection, $resource)
                else
                    (),
                <message status="ok" externalLink="{local:get-run-path($path)}"/>
            )
        } catch * {
            if ($mime = "text/html") then
                let $path := xmldb:store-as-binary($collection, $resource, $data)
                return
                    <message status="ok" externalLink="{local:get-run-path($path)}"/>
            else
                let $message :=
                replace(
                    replace($err:description, "^.*XMLDBException:", ""),
                    "\[at.*\]$", ""
                )
                return
                    <error status="error">
                        <message>{$message}</message>
                    </error>
        }
};

declare function local:remove($path as xs:string) {
    try {
        if (xmldb:collection-available($path)) then
            xmldb:remove($path)
        else
            let $split := analyze-string($path, "^(.*)/([^/]+)$")//fn:group/string()
            let $collection := $split[1]
            let $resource := $split[2]
            return
                xmldb:remove($collection, $resource),
        <message status="ok"/>
    } catch * {
        let $message :=
        replace(
            replace($err:description, "^.*XMLDBException:", ""),
            "\[at.*\]$", ""
        )
        return
            <error status="error">
                <message>{$message}</message>
            </error>
    }
};

let $path := request:get-parameter("path", ())
let $action := request:get-parameter("action", "store")
return
    switch($action)
        case "delete" return
            local:remove($path)
        default return
            local:store($path)
