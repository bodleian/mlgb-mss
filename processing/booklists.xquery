import module namespace bod = "http://www.bodleian.ox.ac.uk/bdlss" at "lib/msdesc2solr.xquery";
declare namespace map="http://www.w3.org/2005/xpath-functions/map";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare option saxon:output "indent=yes";

declare variable $booklists := collection('../collections/booklists/?select=*.xml;recurse=no');
declare variable $allinstances :=
for $instance in collection('../collections/booklists/?select=*.xml;recurse=yes')//tei:TEI[starts-with(@xml:id,'booklist_')]
let $roottei := $instance/ancestor::tei:TEI
let $datesoforigin := distinct-values($roottei//tei:origDate/normalize-space())
let $placesoforigin := distinct-values($roottei//tei:origPlace/normalize-space())
return
    <instance>
        {
            for $key in tokenize(normalize-space($instance/@key), ' ')
            return
                <key>{$key}</key>
        }
        <name>{normalize-space($instance/string())}</name>
        <link>{
                concat(
                '/catalog/',
                $roottei/@xml:id/data(),
                '|',                
                if ($roottei//tei:sourceDesc//tei:surrogates/tei:bibl[@type = ('digital-fascimile', 'digital-facsimile') and @subtype = 'full']) then
                    ' (Digital facsimile online)'
                else
                    if ($roottei//tei:sourceDesc//tei:surrogates/tei:bibl[@type = ('digital-fascimile', 'digital-facsimile') and @subtype = 'partial']) then
                        ' (Selected pages online)'
                    else
                        ''
                , '|',
                if ($roottei//tei:msPart) then
                    'Composite manuscript'
                else
                    string-join(($datesoforigin, $placesoforigin), '; ')
                )
            }</link>
        
        {
            if (not($instance/self::tei:placeName or $instance/self::tei:orgName)) then
                <type>{local-name($instance)}</type>
            else
                ()
        }       
    </instance>;

<add>
    {
        comment {concat(' Indexing started at ', current-dateTime(), ' using files in ', substring-before(substring-after(base-uri($booklists[1]), 'file:'), 'collections/booklists/'), ' ')}
    }
    {
        let $colids := $booklists/tei:TEI/@xml:id/data()
        
        return
            if (count($colids) ne count(distinct-values($colids))) then
                let $duplicateids := distinct-values(for $colid in $colids
                return
                    if (count($colids[. eq $colid]) gt 1) then
                        $colid
                    else
                        '')
                return
                    bod:logging('error', 'There are multiple booklists with the same xml:id in their root TEI elements', $duplicateids)
            
            else
                for $booklist in $booklists
   
                let $colid := $booklist/tei:TEI/@xml:id/string()
                    order by $colid
                return
                    if (string-length($colid) ne 0) then                        
                        let $subfolders := string-join(tokenize(substring-after(base-uri($booklist), 'collections/booklists/'), '/')[position() lt last()], '/')
                        let $htmlfilename := concat($colid, '.html')
                        let $htmldoc := doc(concat('html/booklists/', $subfolders, '/', $htmlfilename))
                        let $instances := $allinstances[key = $colid]
                       
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
                                <field
                                    name="type">booklist</field>
                                <field
                                    name="pk">{$colid}</field>
                                <field
                                    name="id">{$colid}</field>
                                { bod:string2one($colid, 'title') }
                                {bod:one2one($booklist//tei:publicationStmt/tei:idno[@type = 'booklist'], 'booklist_s')}
                                <field
                                    name="filename_s">{substring-after(base-uri($booklist), 'collections/booklists/')}</field>

                                {bod:indexHTML($htmldoc, 'ms_textcontent_tni')}
                                {bod:displayHTML($htmldoc, 'display')}

                                {
                                    (: Links to booklists  :)
                                    for $link in distinct-values($instances//div[@type="entry"][@corresp]/@corresp)
                                        order by normalize-space(translate(tokenize($link, '\|')[2], ".","")) collation "http://www.w3.org/2013/collation/UCA?numeric=yes;fallback=yes"
                                    return
                                        <field
                                            name="link_booklists_smni">{$link}</field>
                                        
                                }                      
                            </doc>
                    
                    else
                        bod:logging('warn', 'Cannot process booklists without @xml:id for root TEI element', (fn:substring-after(base-uri($booklist), "-mss")))
    }
</add>
