xquery version "3.0";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

if (starts-with($exist:path, "/store/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/store.xql">
            <add-parameter name="action" value="store"/>
            <add-parameter name="path" value="{substring-after($exist:path, '/store')}"/>
        </forward>
    </dispatch>
else if (starts-with($exist:path, "/delete/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/store.xql">
            <add-parameter name="action" value="delete"/>
            <add-parameter name="path" value="{substring-after($exist:path, '/delete')}"/>
        </forward>
    </dispatch>
else if ($exist:resource eq 'run') then
    let $query := request:get-parameter("q", ())
    return
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <!-- Query is executed by XQueryServlet -->
            <forward servlet="XQueryServlet">
                <set-header name="Cache-Control" value="no-cache"/>
                <!-- Query is passed via the attribute 'xquery.source' -->
                <set-attribute name="xquery.source" value="{$query}"/>
            </forward>
        </dispatch>
else if ($exist:resource eq 'execute') then
    let $query := request:get-parameter("qu", ())
    let $base := request:get-parameter("base", ())
    let $output := request:get-parameter("output", ())
    let $startTime := util:system-time()
    return
        switch ($output)
            case "adaptive"
            case "json"
            case "xml" return
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                    <!-- Query is executed by XQueryServlet -->
                    <forward servlet="XQueryServlet">
                        <set-header name="Cache-Control" value="no-cache"/>
                        <!-- Query is passed via the attribute 'xquery.source' -->
                        <set-attribute name="xquery.source" value="{$query}"/>
                        <!-- Results should be written into attribute 'results' -->
                        <set-attribute name="xquery.attribute" value="results"/>
        		        <set-attribute name="xquery.module-load-path" value="{$base}"/>
                        <clear-attribute name="results"/>
                        <!-- Errors should be passed through instead of terminating the request -->
                        <set-attribute name="xquery.report-errors" value="no"/>
                        <set-attribute name="start-time" value="{util:system-time()}"/>
                    </forward>
                    <view>
                        <!-- Post process the result: store it into the HTTP session
                           and return the number of hits only. -->
                        <forward url="results.xql">
                           <clear-attribute name="xquery.source"/>
                           <clear-attribute name="xquery.attribute"/>
                           <set-attribute name="elapsed"
                               value="{string(seconds-from-duration(util:system-time() - $startTime))}"/>
                        </forward>
        	        </view>
                </dispatch>
            default return
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                    <!-- Query is executed by XQueryServlet -->
                    <forward servlet="XQueryServlet">
                        <set-header name="Cache-Control" value="no-cache"/>
                        <!-- Query is passed via the attribute 'xquery.source' -->
                        <set-attribute name="xquery.source" value="{$query}"/>
            	        <set-attribute name="xquery.module-load-path" value="{$base}"/>
                        <!-- Errors should be passed through instead of terminating the request -->
                        <set-attribute name="xquery.report-errors" value="yes"/>
                        <set-attribute name="start-time" value="{util:system-time()}"/>
                    </forward>
                </dispatch>
else
    (: everything is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <set-header name="Cache-Control" value="no-cache"/>
        <cache-control cache="yes"/>
    </dispatch>
