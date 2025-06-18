import module namespace bod = "http://www.bodleian.ox.ac.uk/bdlss" at "lib/msdesc2solr.xquery";
declare namespace map="http://www.w3.org/2005/xpath-functions/map";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare option saxon:output "indent=yes";

declare variable $booklists := collection('../collections/booklists/?select=*.xml;recurse=yes');


(: Read works authority file to be able to link from authors to their works :)
(:~ declare variable $worksauthority := doc("../works.xml")/tei:TEI/tei:text/tei:body/tei:listBibl/tei:bibl[@xml:id];
declare variable $authorsinworksauthority := true();  ~:)

(: Read persons authority file to be able to link from works to 
   their authors (not necessary if the works authority has authors in it) :)
(:~ declare variable $personauthority := doc("../persons.xml")/tei:TEI/tei:text/tei:body/tei:listPerson/tei:person[@xml:id]; ~:)

(: Get a list of person keys in all the collection records, to check a link from work to person won't be broken :)
(:~ declare variable $personkeys := distinct-values(collection('../booklists?select=*.xml;recurse=yes')//tei:back/tei:listBibl//(tei:persName|tei:author|tei:editor)/@key/data()); ~:)



(: Find instances in collection files, building in-memory data 
   structure, to avoid having to search across all files for each authority file entry :)
declare variable $allinstances :=
    for $instance in $booklists//tei:text
        let $roottei := $instance/ancestor::tei:TEI/@xml:id
        let $biblids := $instance//tei:bibl/@corresp/data()
        for $biblidhash in $biblids
            let $biblid := substring-after($biblidhash, '#')      
            let $booklink := substring-after($instance/tei:body//tei:div[@type="entry" and tei:bibl[@corresp=$biblidhash]]/@corresp/data(), "catalog/")  
            return
                <instance>
                    <key>{$roottei}</key>
                    <biblid>{$biblid}</biblid>                    
                    <copycode>
                        {
                            $instance/tei:body//tei:div[@type="entry" and tei:bibl[@corresp=$biblidhash]]/tei:ab[@type="mlgb_copyCode"]/text()
                        }
                    </copycode>
                    { 
                    if ($booklink) then
                        <link> { concat('/catalog/', $booklink) }</link>
                    else ()
                    }           
                </instance>;


(: MLGB title facet :)
declare function local:titles($titles as node()*, $solrfield as xs:string, $solrsuffix as xs:string) as element()* 
{
    let $outputnames := map { 
        "group": 1,
        "location" : 2
        }   
    let $all as element()* := (
    for $title in $titles
    return        
        let $map := map {
            'group': $title[@type="mlgb_booklist_Group"]/text(),
            'location': $title[@type="mlgb_location"]/text()
        }
        for $key in map:keys($map)
        order by $title/text(), $outputnames($key)    
        for $val in $map($key)
        return
            <field
                name="{$solrfield}{$key}{$solrsuffix}"
                type="{$key}">{$val}</field>  
    )    
    for $type in distinct-values($all/@type)
    for $t in distinct-values($all[@type = $type]/text())
    return
        <field
            name="{($all[@type = $type]/@name)[1]}">{$t}</field>
    
};

<add>    
    {
        comment {concat(' Indexing started at ', current-dateTime(), ' using files in ', substring-before(substring-after(base-uri($booklists[1]), 'file:'), 'collections/booklists/'), ' ')}
    }
    {
        let $blids := $booklists/tei:TEI/@xml:id/data()
        
        return
            if (count($blids) ne count(distinct-values($blids))) then
                let $duplicateids := distinct-values(for $blid in $blids
                return
                    if (count($blids[. eq $blid]) gt 1) then
                        $blid
                    else
                        '')
                return
                    bod:logging('error', 'There are multiple booklists with the same xml:id in their root TEI elements', $duplicateids)
            
            else
                for $booklist in $booklists
   
                let $blid := $booklist/tei:TEI/@xml:id/string()
                    order by $blid
                return
                    if (string-length($blid) ne 0) then                        
                        let $subfolders := string-join(tokenize(substring-after(base-uri($booklist), 'collections/booklists/'), '/')[position() lt last()], '/')
                        let $htmlfilename := concat($blid, '.html')
                        let $htmldoc := doc(concat('html/booklists/', $subfolders, '/', $htmlfilename))
                        let $titlegroup := $booklist/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type="mlgb_booklist_Group"]
                        let $titlelocation := $booklist/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type="mlgb_location"]
                        let $titlecode := $booklist/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type="mlgb_code"]
                        let $titlebooklist := $booklist/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type="mlgb_booklist"]
                        let $title := concat($titlegroup, ": ", $titlelocation, ". ", $titlecode, ". ", $titlebooklist)
                        let $instances := $allinstances[key/@xml:id/data() = $blid]
                       
                        (:
                    Guide to Solr field naming conventions:                
                        _i = integer field
                        _b = boolean field
                        _s = string field (tokenized)
                        _t = text field (not tokenized)
                        _?m = multiple field (typically facets)
                        *ni = not indexed (except _tni fields which are copied to the fulltext index)
                :)
                        return
                            <doc>
                                <field name="type">booklist</field>
                                <field name="pk">{$blid}</field>
                                <field name="id">{$blid}</field>                               
                                {bod:string2one($title, 'title')}
                               
                                <field name="filename_s">{substring-after(base-uri($booklist), 'collections/booklists/')}</field>

                                {bod:indexHTML($htmldoc, 'ms_textcontent_tni')}
                                {bod:displayHTML($htmldoc, 'display')}
                            
                                {local:titles($booklist/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/node(), 'ms_title', '_sm') }                          
                                
                                {
                                (: Links to existing books  :)
                                for $link in distinct-values($instances/link/text())
                                    order by normalize-space(translate(tokenize($link, '\|')[2], ".","")) collation "http://www.w3.org/2013/collation/UCA?numeric=yes;fallback=yes"
                                    return
                                    <field name="link_corresp_smni">{$link}</field>
                                }
                                
                            </doc>
                    
                    else
                        bod:logging('warn', 'Cannot process booklists without @xml:id for root TEI element', (fn:substring-after(base-uri($booklist), "-mss")))
    }
</add>
