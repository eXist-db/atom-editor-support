(:
 :  eXide - web-based XQuery IDE
 :  
 :  Copyright (C) 2011 Wolfgang Meier
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

(:~
	Post-processes query results for the sandbox application. The
	controller first sends the user-supplied query to XQueryServlet
	for evaluation. The result is then passed to this script, which
	stores the result set into the HTTP session and returns the number
	of hits and time elapsed.

	Subsequent requests from the sandbox application may retrieve single
	items from the result set stored in the session (see controller).
:)

declare option exist:serialize "method=xml media-type=text/xml omit-xml-declaration=yes indent=yes";

declare function local:elapsed-time() {
    let $startTime := request:get-attribute("start-time")
    return
        if ($startTime) then
        	let $current-time := current-time()
        	let $hours :=  hours-from-duration($current-time - xs:time($startTime))
        	let $minutes :=  minutes-from-duration($current-time - xs:time($startTime))
        	let $seconds := seconds-from-duration($current-time - xs:time($startTime))
        	return ($hours * 3600) + ($minutes * 60) + $seconds
        else 0
};

(: 	When a query has been executed, its results will be passed into
	this script in the request attribute 'results'.
:)
let $input := request:get-data()
let $results := request:get-attribute("results")
let $count := xs:integer(request:get-parameter("count", ()))
return (
    response:set-header("X-elapsed", local:elapsed-time()),
	response:set-header("X-result-count", string(count($results))),
    if (string-length($input) gt 0) then
        $input
	else if ($count) then
		subsequence($results, 1, xs:int($count))
	else
		$results
)