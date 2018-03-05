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

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace xqdoc="http://www.xqdoc.org/1.0";

declare option output:method "json";
declare option output:media-type "application/json";

(: Search for functions matching the supplied query string.
 : Logic for different kinds of query strings:
 :   1. Module namespace prefix only (e.g., "kwic:", "fn:"): show all functions
 :        in the module
 :   2. Module namespace prefix + exact function name (e.g., "math:pow"): show
 :        just this function
 :   3. Module namespace prefix + partial function name (e.g., "ngram:con"):
 :        show matching functions from the module
 :   4. No module namespace prefix + partial or complete function name (e.g.,
 :        "con"): show matching functions from all modules
 : Note 1: We give special handling to default XPath functions:
 :   1. Since the "fn" namespace prefix is the default function namespace,
 :        its functions are included in searches when no namespace prefix is
 :        supplied. Functions from this namespace appear at the top of the list
 :        of results. The results also omit the "fn" namespace prefix if it
 :        was omitted in the query string.
 :   2. If the "fn" namespace prefix is supplied in the query string, we limit
 :        searches to the default XPath functions, and the results show the
 :        prefix.
 : Note 2: We do not currently search for variables in these modules.
 : :)
declare function local:get-built-in-functions($q as xs:string) {
    let $supplied-module-namespace-prefix := if (contains($q, ':')) then substring-before($q, ':') else ()
    let $function-name-fragment := if (contains($q, ':')) then substring-after($q, ':') else $q
    (: If the user supplies the "fn" prefix, we should preserve it :)
    let $show-fn-prefix := exists($supplied-module-namespace-prefix) and $supplied-module-namespace-prefix eq 'fn'
    let $modules :=
        if ($supplied-module-namespace-prefix eq 'fn') then
            inspect:inspect-module-uri(xs:anyURI('http://www.w3.org/2005/xpath-functions'))
        else
            let $all-modules := (util:registered-modules(), util:mapped-modules()) ! inspect:inspect-module-uri(xs:anyURI(.))
            return
                if ($supplied-module-namespace-prefix) then
                    $all-modules[starts-with(@prefix, $supplied-module-namespace-prefix)]
                else
                    $all-modules
    let $functions := $modules/function[not(annotation/@name = "private") and not(deprecated)]
    for $function in $functions
    let $function-name :=
        (: Functions in some modules contain the module namespace prefix in
         : the name attribtue, e.g., @name="map:merge". :)
        if (contains($function/@name, ':')) then
            substring-after($function/@name, ':')
        (: Functions in others *do not*, e.g., math:pow > @name="pow" :)
        else
            $function/@name
    let $module-namespace-prefix :=
        (: All modules have a @prefix attribute, except the default XPath
         : function namespace, whose @prefix is an empty string. (Even though
         : its prefix is conventionally given as "fn" in the spec.) :)
        $function/parent::module/@prefix
    let $complete-function-name := if ($show-fn-prefix) then ('fn:' || $function-name) else ($module-namespace-prefix || ':' || $function-name)
    where
        (
            starts-with($complete-function-name, $function-name-fragment)
            or
            starts-with($function-name, $function-name-fragment)
        )
    (: Ensure functions in "fn" namespace, or default function namespace,
     : appear at the top of the list :)
    order by ($module-namespace-prefix, '')[1], lower-case($function-name)
    return
        local:describe-function($function, $module-namespace-prefix, $function-name, $show-fn-prefix, $q)
};

(: Search in imported functions for functions and variables matching the supplied query string.
 : The logic is similar to the first case, but handles two different scenarios:
 :   1. If there's a signature parameter... TODO: I can't figure out when signature is called; help, Wolfgang? -JW
 :   2. If there are 1+ module imports, resolve these and look inside them for matching functions or global variables
 :)
declare function local:get-imported-functions($q as xs:string?, $signature as xs:string?, $base as xs:string,
    $imported-module-source-urls as xs:string*, $imported-module-namespace-uris as xs:string*, $imported-module-prefixes as xs:string*) {
    let $supplied-module-namespace-prefix :=
        if (empty($signature)) then
            replace($q, "^\$?([^:]+):.*$", "$1")
        else
            replace($signature, "^\$?([^:]+):.*$", "$1")
    for $imported-module-prefix at $i in $imported-module-prefixes
    where matches($imported-module-prefix, "^" || $supplied-module-namespace-prefix)
    let $imported-module-namespace-uri := $imported-module-namespace-uris[$i]
    let $imported-module-source-url :=
        (: Handle absolute sources like /db or file:/ :)
        if (matches($imported-module-source-urls[$i], "^(/|\w+:)")) then
            $imported-module-source-urls[$i]
        (: Handle relative sources by prepending base :)
        else
            concat($base, "/", $imported-module-source-urls[$i])
    return
        try {
            let $module := inspect:inspect-module($imported-module-source-url)
            return (
                (: Look for matching functions :)
                if (not(starts-with($q, "$")) and not(starts-with($signature, "$"))) then
                    let $function-name-fragment := replace($q, "^\$?[^:]+:(.*)$", "$1")
                    (: We're looking at imported modules, so assume no "fn" namespace prefix :)
                    let $show-fn-prefix := ()
                    for $function in $module/function[not(annotation/@name = "private")]
                    let $function-name :=
                        (: Functions in some modules contain the module namespace prefix in
                         : the name attribute, e.g., @name="map:merge". :)
                        if (contains($function/@name, ':')) then
                            substring-after($function/@name, ':')
                        (: Functions in others *do not*, e.g., math:pow > @name="pow" :)
                        else
                            $function/@name
                    let $arity := count($function/argument)
                    (: fix namespace prefix to match the one in the import :)
                    let $complete-function-name := concat($imported-module-prefix, ":", $function-name)
                    return
                        if (
                            (empty($signature) or $signature = $complete-function-name || "#" || $arity) and
                            (empty($q) or matches($complete-function-name, "^" || $q || "|:" || $q))
                        ) then
                            map {
                                "text": local:generate-signature($function, $imported-module-prefix, $function-name, $show-fn-prefix),
                                "name": $function/@name || "#" || $arity,
                                "leftLabel": $function/returns/@type || local:cardinality($function/returns/@cardinality),
                                "snippet": local:generate-template($function, $imported-module-prefix, $function-name, $show-fn-prefix),
                                "type": "function",
                                "replacementPrefix": $q,
                                "description": $function/description/string(),
                                "path": $imported-module-source-url
                            }
                        else
                            ()
                (: Look for matching variables :)
                else
                    let $signature := substring-after($signature, "$")
                    let $q := substring-after($q, "$")
                    for $variable in $module/variable[not(annotation/@name = "private")]
                    (: fix namespace prefix to match the one in the import :)
                    let $variable-name := concat($imported-module-prefix, ":", substring-after($variable/@name, ":"))
                    return
                        if (
                            (not($signature) or $signature = $variable-name) and
                            (not($q) or matches($variable-name, "^" || $q || "|:" || $q))
                        ) then
                            map {
                                "text": "$" || $variable-name,
                                "name": $variable-name,
                                "replacementPrefix": "$" || $q,
                                "type": "variable",
                                "path": $imported-module-source-url
                            }
                        else
                            ()
            )
        } catch * {
            ()
        }
};

declare function local:describe-function($function as element(function), $module-namespace-prefix as xs:string, $function-name as xs:string, $show-fn-prefix as xs:boolean, $q as xs:string) {
    let $signature := local:generate-signature($function, $module-namespace-prefix, $function-name, $show-fn-prefix)
    let $template := local:generate-template($function, $module-namespace-prefix, $function-name, $show-fn-prefix)
    let $help := $function/description/string()
    let $leftLabel := $function/returns/@type || local:cardinality($function/returns/@cardinality)
    return
        map {
            "text": $signature,
            "snippet": $template,
            "type": "function",
            "description": $help,
            "leftLabel": $leftLabel,
            "replacementPrefix": $q
        }
};

declare function local:generate-signature($function as element(function), $module-namespace-prefix as xs:string, $function-name as xs:string, $show-fn-prefix as xs:boolean?) {
    (
        if ($module-namespace-prefix ne '') then
            ($module-namespace-prefix || ":")
        else if ($show-fn-prefix) then
            "fn:"
        else
            ()
    ) ||
    $function-name ||
    "(" ||
    string-join(
        $function/argument !
            ("$" || ./@var || " as " || ./@type || local:cardinality(./@cardinality)),
        ", "
    ) ||
    ")"
};

declare function local:generate-template($function as element(function), $module-namespace-prefix as xs:string, $function-name as xs:string, $show-fn-prefix as xs:boolean?) {
    (
        if ($module-namespace-prefix ne '') then
            ($module-namespace-prefix || ":")
        else if ($show-fn-prefix) then
            "fn:"
        else
            ()
    ) ||
    $function-name ||
    "(" ||
    string-join(
        for $param at $p in $function/argument
        return
            "${" || $p || ":$" || $param/@var || "}",
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

let $q := request:get-parameter("prefix", ())
let $signature := request:get-parameter("signature", ())
let $base := request:get-parameter("base", ())
let $imported-module-source-urls := request:get-parameter("source", ())
let $imported-module-namespace-uris := request:get-parameter("uri", ())
let $imported-module-prefixes := request:get-parameter("mprefix", ())
return
    array {
        if ($q) then local:get-built-in-functions($q) else (),
        local:get-imported-functions($q, $signature, $base, $imported-module-source-urls, $imported-module-namespace-uris, $imported-module-prefixes)
    }
