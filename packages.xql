xquery version "3.1";

declare namespace expath="http://expath.org/ns/pkg";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "json";
declare option output:media-type "application/json";

declare variable $repo := "https://exist-db.org/exist/apps/public-repo/find";

declare function local:installed() {
    array {
        for $pkg in repo:list()
        let $expath := collection(repo:get-root())//expath:package[@name = $pkg][1]
        return
            map {
                "name": $expath/@name/string(),
                "abbrev": $expath/@abbrev/string(),
                "title": $expath/expath:title/string(),
                "version": $expath/@version/string(),
                "collection": util:collection-name($expath)
            }
    }
};

(:~
 : Uninstall given package if it is installed.
 : 
 : @return true if the package could be removed, false otherwise
 :)
declare function local:remove($package-url as xs:string) as xs:boolean {
    if ($package-url = repo:list()) then
        let $undeploy := repo:undeploy($package-url)
        let $remove := repo:remove($package-url)
        return
            $remove
    else
        false()
};

declare %private function local:entry-filter($path as xs:anyURI, $type as xs:string, $param as item()*) as xs:boolean
{
	$path = "expath-pkg.xml"
};

declare %private function local:entry-data($path as xs:anyURI, $type as xs:string, $data as item()?, $param as item()*) as item()?
{
    <entry>
        <path>{$path}</path>
    	<type>{$type}</type>
    	<data>{$data}</data>
    </entry>
};

declare function local:deploy() {
    let $xarPath := request:get-parameter("xar", ())
    let $meta :=
        try {
            compression:unzip(
                util:binary-doc($xarPath), local:entry-filter#3, 
                (),  local:entry-data#4, ()
            )
        } catch * {
            error(xs:QName("local:xar-unpack-error"), "Failed to unpack archive")
        }
    let $package := $meta//expath:package/string(@name)
    let $removed := local:remove($package)
    let $installed := repo:install-and-deploy-from-db($xarPath, $repo)
    return
        repo:get-root()
};

let $action := request:get-parameter("action", ())
return
    switch($action)
        case "deploy" return 
            local:deploy()
        default return
            local:installed()