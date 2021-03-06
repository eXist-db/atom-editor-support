xquery version "3.0";

import module namespace test="http://exist-db.org/xquery/xqsuite"
at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";
declare option output:indent "no";

let $source := request:get-parameter("source", ())
return
    if (util:binary-doc-available((xs:anyURI("xmldb:exist://" || $source)))) then
        test:suite(inspect:module-functions(xs:anyURI("xmldb:exist://" || $source)))
    else
        let $message := "The query must be saved in the database to run it as a test"
        return
            error(QName("http://exist-db.org/apps/atom-editor-support", "error"), $message)
