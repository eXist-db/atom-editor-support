(:
 :  eXide - web-based XQuery IDE
 :
 :  Copyright (C) 2011-13 Wolfgang Meier
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
xquery version "3.1";

declare namespace xqdoc="http://www.xqdoc.org/1.0";
declare namespace json="http://json.org/";

declare option exist:serialize "method=json media-type=application/json";

declare function local:builtin-modules($prefix as xs:string) {
    for $module in util:registered-modules()
    let $funcs := inspect:module-functions-by-uri(xs:anyURI($module))
    let $matches := for $func in $funcs where matches(function-name($func), concat("^(\w+:)?", $prefix)) return $func
    for $func in $matches
    let $desc := inspect:inspect-function($func)
    order by function-name($func)
    return
        local:describe-function($desc, $prefix)
};

declare function local:describe-function($desc, $prefix as xs:string) {
    let $signature := local:generate-signature($desc)
    return
        map {
            "text": $signature,
            "snippet": local:create-template($desc),
            "type": "function",
            "description": $desc/description/string(),
            "replacementPrefix": $prefix
        }
};

declare function local:generate-signature($func as element(function)) {
    $func/@name/string() || "(" ||
    string-join(
        for $param in $func/argument
        return
            "$" || $param/@var/string() || " as " || $param/@type/string() || local:cardinality($param/@cardinality),
        ", "
    ) ||
    ")"
};

declare function local:create-template($func as element(function)) {
    $func/@name/string() || "(" ||
    string-join(
        for $param at $p in $func/argument
        return
            "${" || $p || ":$" || $param/@var/string() || "}",
        ", "
    ) ||
    ")"
};

declare function local:cardinality($cardinality as xs:string) {
    switch ($cardinality)
        case "zero or one" return "?"
        case "zero or more" return "*"
        case "one or more" return "+"
        default return ()
};

declare function local:imported-functions($prefix as xs:string?, $signature as xs:string?, $base as xs:string,
    $sources as xs:string*, $uris as xs:string*, $prefixes as xs:string*) {
    for $uri at $i in $uris
    let $source := if (matches($sources[$i], "^(/|\w+:)")) then $sources[$i] else concat($base, "/", $sources[$i])
    return
        try {
            let $mprefix := $prefixes[$i]
            let $module := inspect:inspect-module($source)
            return (
                if (not(starts-with($prefix, "$"))) then
                    for $desc in $module/function
                    let $name := $desc/@name/string()
                    let $arity := count($desc/argument)
                    (: fix namespace prefix to match the one in the import :)
                    let $name := concat($mprefix, ":", substring-after($name, ":"))
                    return
                        if (
                            (empty($signature) or $signature = $name || "#" || $arity) and
                            (empty($prefix) or matches($name, "^" || $prefix || "|:" || $prefix))
                        ) then
                            map {
                                "text": local:generate-signature($desc),
                                "name": $desc/@name || "#" || $arity,
                                "snippet": local:create-template($desc),
                                "type": "function",
                                "replacementPrefix": $prefix,
                                "description": $desc/description/string(),
                                "path": $source
                            }
                        else
                            ()
                else
                    let $prefix := substring-after($prefix, "$")
                    for $var in $module/variable
                    (: fix namespace prefix to match the one in the import :)
                    let $name := concat($mprefix, ":", substring-after($var/@name, ":"))
                    return
                        if (empty($prefix) or matches($name, "^" || $prefix || "|:" || $prefix)) then
                            map {
                                "text": "$" || $name,
                                "name": $name,
                                "replacementPrefix": "$" || $prefix,
                                "type": "variable",
                                "path": $source
                            }
                        else
                            ()
            )
        } catch * {
            ()
        }
};

let $signature := request:get-parameter("signature", ())
let $prefix := request:get-parameter("prefix", ())
let $uris := request:get-parameter("uri", ())
let $sources := request:get-parameter("source", ())
let $prefixes := request:get-parameter("mprefix", ())
let $base := request:get-parameter("base", ())
return
    array {
        if ($prefix) then local:builtin-modules($prefix) else (),
        local:imported-functions($prefix, $signature, $base, $sources, $uris, $prefixes)
    }
