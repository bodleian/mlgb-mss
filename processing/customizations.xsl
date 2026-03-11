<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:bod="http://www.bodleian.ox.ac.uk/bdlss" xpath-default-namespace="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="tei html xs bod" version="2.0">



    <!-- The stylesheet is a library. It doesn't validate and won't produce HTML on its own. It is called by 
         convert2HTML.xsl and previewManuscript.xsl. Any templates added below will override the templates 
         in msdesc2html.xsl in the consolidated-tei-schema repository, allowing customization of manuscript 
         display for each catalogue. -->


    <!-- For Medieval, notes are sometimes used between items to give context, so this overrides the 
         default in msdesc2html.xsl, which re-orders child elements of msItem for the sake of neatness. -->

    <xsl:template name="SubItems">
        <xsl:apply-templates/>
    </xsl:template>



    <!-- TODO: Move these templates to msdesc2html.xsl if applicable to all catalogues? -->

    <xsl:template match="msDesc/msIdentifier/altIdentifier[@type='former' and child::idno[not(@subtype)]]">
        <p>
            <xsl:text>Former shelfmark: </xsl:text>
            <xsl:apply-templates/>
        </p>
    </xsl:template>

    <xsl:template match="title[@key]">
        <span>
            <xsl:attribute name="class">
                <xsl:if test="not(parent::msItem)">
                    <xsl:text>title </xsl:text>
                </xsl:if>
                <xsl:text>tei-title</xsl:text>
                <xsl:if test="not(@rend) and not(@type)">
                    <xsl:text> italic</xsl:text>
                </xsl:if>
            </xsl:attribute>
            <xsl:choose>
                <xsl:when test="not(@key='')">
                    <a>
                        <xsl:attribute name="href">
                            <xsl:value-of select="$website-url"/>
                            <xsl:text>/catalog/</xsl:text>
                            <xsl:value-of select="tokenize(@key, ' ')[1]"/>
                        </xsl:attribute>
                        <xsl:apply-templates/>
                    </a>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates/>
                </xsl:otherwise>
            </xsl:choose>
        </span>
        <xsl:if test="following-sibling::*[1][self::note and not(matches(., '^\s*[A-Z(,]')) and not(child::*[1][self::lb and string-length(normalize-space(preceding-sibling::text())) = 0])]">
            <xsl:text>, </xsl:text>
        </xsl:if>
    </xsl:template>



    <!-- This is Medieval notation, do not move this to msdesc2html.xsl -->

    <xsl:template match="lb">
        <xsl:text>|</xsl:text>
    </xsl:template>



    <!-- This is an override of the template in msdesc2html.xsl, which outputs a div. Maybe the choice should be based on context? -->

    <xsl:template match="formula">
        <span class="formula">
            <xsl:apply-templates/>
        </span>
    </xsl:template>



    <!-- Display lemmata in italic -->

    <xsl:template match="incipit/quote | incipit/cit/quote | explicit/quote | explicit/cit/quote">
        <i>
            <xsl:apply-templates/>
        </i>
    </xsl:template>
    <xsl:template match="text()[ancestor::incipit/@type='lemma' or ancestor::explicit/@type='lemma']">
        <i>
            <xsl:copy/>
        </i>
    </xsl:template>



    <!-- Display links to abbreviations and conventions pages, and the most recent change 
         at the bottom of book pages (just before Zotero links, if any) -->

    <xsl:template name="Footer">
        <div class="abbreviations">
            <xsl:processing-instruction name="ni"/>
            <h3>Abbreviations</h3>
            <p>View <a title="GitHub" href="https://github.com/bodleian/medieval-mss/wiki/Abbreviations">list of abbreviations</a> and <a title="HathiTrust" href="https://hdl.handle.net/2027/uva.x000937945?urlappend=%3Bseq=12">editorial conventions</a>.
            </p>
            <xsl:processing-instruction name="ni"/>
        </div>
        <xsl:apply-templates select="/TEI/teiHeader/revisionDesc[change][1]"/>
    </xsl:template>

    <xsl:template match="revisionDesc[.//change]">
        <div class="revisionDesc">
            <xsl:processing-instruction name="ni"/>
            <h3>Last Substantive Revision</h3>
            <xsl:choose>
                <xsl:when test="some $change in .//change satisfies exists($change/@when)">
                    <xsl:for-each select=".//change[@when]">
                        <xsl:sort select="@when" order="descending"/>
                        <xsl:if test="position() eq 1">
                            <xsl:apply-templates select="."/>
                        </xsl:if>
                    </xsl:for-each>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="(.//change)[1]"/>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:processing-instruction name="ni"/>
        </div>
    </xsl:template>

    <xsl:template match="change">
        <p class="change">
            <xsl:if test="@when">
                <xsl:value-of select="@when"/>
                <xsl:text>: </xsl:text>
            </xsl:if>
            <xsl:apply-templates/>
        </p>
    </xsl:template>



    <!-- This is used in generate-html.sh -->

    <xsl:template name="batch">
        <!-- Set up the collection of files to be converted. The path must be supplied in batch mode, and must be a full
             path because this stylesheet is normally imported by convert2HTML.xsl via a URL. -->
        <xsl:variable name="path">
            <xsl:choose>
                <xsl:when test="starts-with($collections-path, '/')">
                    <!-- UNIX-like systems -->
                    <xsl:value-of select="concat('file://', $collections-path, '/?select=', $files, ';on-error=warning;recurse=', $recurse)"/>
                </xsl:when>
                <xsl:when test="matches($collections-path, '[A-Z]:/')">
                    <!-- Git Bash on Windows -->
                    <xsl:value-of select="concat('file:///', $collections-path, '/?select=', $files, ';on-error=warning;recurse=', $recurse)"/>
                </xsl:when>
                <xsl:when test="matches($collections-path, '[A-Z]:\\')">
                    <!-- Windows -->
                    <xsl:value-of select="concat('file:///', replace($collections-path, '\\', '/'), '/?select=', $files, ';on-error=warning;recurse=', $recurse)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:copy-of select="bod:logging('error', 'A full path to the collections folder containing source TEI must be specified', .)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <!-- For each item in the collection -->
        <xsl:for-each select="collection($path)">

            <!-- Boolean variable: true ⇢ id starts with "booklist_" -->
            <xsl:variable name="isBooklist" select="starts-with(/TEI/@xml:id, 'booklist_')" />

            <xsl:choose>
                <xsl:when test="string-length(/TEI/@xml:id/string()) eq 0">

                    <!-- Cannot do anything if there is no @xml:id on the root TEI element -->
                    <xsl:copy-of select="bod:logging('warn', 'Cannot process XML without @xml:id for root TEI element', /TEI, base-uri())"/>

                </xsl:when>
                <xsl:otherwise>

                    <!-- Build HTML in a variable so it can be post-processed to strip out undesirable HTML code -->
                    <xsl:variable name="outputdoc" as="element()">
                        <xsl:choose>
                            <xsl:when test="$output-full-html">
                                <html xmlns="http://www.w3.org/1999/xhtml">
                                    <head>
                                        <title></title>
                                    </head>
                                    <body>
                                        <div class="content tei-body" id="{/TEI/@xml:id}">
                                            <xsl:call-template name="Header"/>
                                            <xsl:choose>
                                                <xsl:when test="/TEI/teiHeader/fileDesc/sourceDesc/msDesc and not($isBooklist) ">
                                                    <xsl:apply-templates select="/TEI/teiHeader/fileDesc/sourceDesc/msDesc"/>
                                                    <xsl:call-template name="Funding"/>
                                                    <xsl:call-template name="AbbreviationsKey"/>
                                                    <xsl:call-template name="Footer"/>
                                                </xsl:when>
                                                <xsl:otherwise>
                                                    <xsl:choose>
                                                        <xsl:when test="$isBooklist">
                                                            <!-- #96 reinstate post-launch when styling decided -->
                                                            <!-- <xsl:apply-templates select="/TEI/teiHeader/fileDesc/sourceDesc/msDesc"/> -->
                                                            <div class="citation">
                                                                <p>This digital edition currently lists only editorial identifications of selected texts referred to in the booklist. For the full text of the booklist with editorial commentary see:</p>
                                                                <xsl:apply-templates select="/TEI/teiHeader/fileDesc/sourceDesc/bibl/bibl"/>
                                                            </div>
                                                            <xsl:call-template name="Booklist"/>
                                                        </xsl:when>
                                                        <xsl:otherwise>
                                                            <xsl:apply-templates select="/TEI/text/body"/>
                                                        </xsl:otherwise>
                                                    </xsl:choose>
                                                </xsl:otherwise>
                                            </xsl:choose>

                                        </div>
                                    </body>
                                </html>
                            </xsl:when>
                            <xsl:otherwise>
                                <div>
                                    <div class="content tei-body" id="{/TEI/@xml:id}">
                                        <xsl:call-template name="Header"/>
                                        <xsl:apply-templates select="/TEI/teiHeader/fileDesc/sourceDesc/msDesc"/>
                                        <xsl:call-template name="Funding"/>
                                        <xsl:call-template name="AbbreviationsKey"/>
                                        <xsl:call-template name="Footer"/>
                                    </div>
                                </div>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>

                    <!-- Create output HTML files -->
                    <xsl:variable name="subfolders" select="tokenize(substring-after(base-uri(.), $collections-path), '/')[position() ne last()]"/>
                    <xsl:variable name="outputpath" select="concat('./html/', string-join($subfolders, '/'), '/', /TEI/@xml:id/string(), '.html')"/>
                    <xsl:result-document href="{$outputpath}" method="xhtml" encoding="UTF-8" indent="yes">

                        <!-- Applying templates on the HTML already built, with a mode, to strip out undesirable HTML code -->
                        <xsl:apply-templates select="$outputdoc" mode="stripoutempty"/>

                    </xsl:result-document>

                </xsl:otherwise>
            </xsl:choose>

        </xsl:for-each>
    </xsl:template>


    <!-- MLGB Booklists -->
    <xsl:template name="Booklist">
        <ul class="booklist">
            <xsl:for-each select="/TEI/text/body//div[@type='entry']">

                <xsl:variable name="head" select="./head/text()"/>
                <xsl:variable name="booklink" select="substring-after(./@corresp, 'catalog/')"/>
                <xsl:variable name="numworks" select="count(.//div[@type='work'])"/>

                <li>
                    <xsl:choose>
                        <xsl:when test="$booklink">
                            <a>
                                <xsl:attribute name="href">
                                    <xsl:value-of select="$website-url"/>
                                    <xsl:text>/catalog/</xsl:text>
                                    <xsl:value-of select="tokenize($booklink, ' ')[1]"/>
                                </xsl:attribute>
                                <xsl:value-of select="$head" />
                            </a>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$head" />
                        </xsl:otherwise>
                    </xsl:choose>

                    <!-- only display extract if one div@work -->
                    <xsl:if test="$numworks = 1">
                        <xsl:variable name="extract" select=".//div[@type='work'][1]/ab[@type='mlgb_catalogueExtract']/text()"/>
                        <xsl:if test="$extract">
                            <xsl:text>&#x20;</xsl:text>
                            <xsl:value-of select="$extract" />
                        </xsl:if>
                    </xsl:if>

                    <xsl:call-template name="works">
                        <!-- pass in div@entry -->
                        <xsl:with-param name="entry" select="." />
                        <xsl:with-param name="numworks" select="$numworks" />
                    </xsl:call-template>

                </li>
            </xsl:for-each>
        </ul>
    </xsl:template>

    <xsl:template name="works">
        <xsl:param name="entry"/>
        <xsl:param name="numworks"/>

        <div class="works">
            <xsl:for-each select="$entry//div[@type='work']">

                <xsl:variable name="biblid" select="substring-after(./bibl/@corresp, '#')"/>
                <xsl:variable name="copycode" select="./ab[@type='mlgb_copyCode']/text()"/>
                <xsl:variable name="extract" select="./ab[@type='mlgb_catalogueExtract']/text()"/>
                <xsl:variable name="biblnode" select="/TEI/text/back/listBibl/bibl[@xml:id=$biblid]"/>

                <!-- only display copycode and extract if more than one div@work -->
                <xsl:if test="$numworks > 1">
                    <xsl:value-of select="$copycode" />
                    <xsl:if test="$extract">
                        <xsl:text>&#x20;</xsl:text>
                        <xsl:value-of select="$extract" />
                    </xsl:if>
                </xsl:if>

                <xsl:apply-templates select="$biblnode"/>
            </xsl:for-each>
        </div>
    </xsl:template>

    <!-- Book customisation override to display evidence after orgName -->

    <xsl:template match="orgName">
        <!--#151 Uncertain provenance evidence -->
        <xsl:if test="parent::provenance[@cert='low']">
            <span>
                <xsl:attribute name="class">
                    <xsl:text>uncertain</xsl:text>
                </xsl:attribute>
                <xsl:text>(?)&#x20;</xsl:text>
            </span>
        </xsl:if>
        <!--#151 Rejected provenance evidence -->
        <xsl:if test="parent::provenance[@type='#rejected']">
            <span>
                <xsl:attribute name="class">
                    <xsl:text>rejected</xsl:text>
                </xsl:attribute>
                <xsl:text>(Rejected)&#x20;</xsl:text>
            </span>
        </xsl:if>
        <span>
            <xsl:attribute name="class">
                <xsl:value-of select="string-join((name(), @role), ' ')"/>
            </xsl:attribute>
            <xsl:choose>
                <xsl:when test="@key and not(@key='')">
                    <a>
                        <xsl:attribute name="href">
                            <xsl:value-of select="$website-url"/>
                            <xsl:text>/catalog/</xsl:text>
                            <xsl:value-of select="@key"/>
                        </xsl:attribute>
                        <xsl:apply-templates/>
                    </a>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates/>
                </xsl:otherwise>
            </xsl:choose>
        </span>
        <span>
            <xsl:attribute name="class">
                <xsl:text>evidence</xsl:text>
            </xsl:attribute>
            <xsl:text>&#x3A;&#x20;</xsl:text>
            <xsl:variable name="evidence" select="parent::provenance[starts-with(@type, '#') and not(@type='#rejected')]"/>
            <xsl:choose>
                <xsl:when test="$evidence">
                    <xsl:for-each select="tokenize(substring-after($evidence/@type, '#'), ' ')">
                        <xsl:value-of select="bod:provenanceTypeLookup(.)"/>
                        <xsl:choose>
                            <xsl:when test="position() ne last()">
                                <xsl:text>&#x3B;&#x20;and&#x20;</xsl:text>
                            </xsl:when>
                            <xsl:otherwise>
                                <!-- Do not add a full stop if the evidence label ends with a full stop, in this case only 'c' -->
                                <xsl:if test=". != 'c'">
                                    <xsl:text>&#x2E;</xsl:text>
                                </xsl:if>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>inferred evidence.</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </span>
    </xsl:template>

    <xsl:function name="bod:provenanceTypeLookup" as="xs:string">
        <xsl:param name="provenanceType"/>
        <xsl:choose>
            <xsl:when test="$provenanceType eq 'b'">evidence from binding or elements of a binding typical of a particular library, or pastedowns bearing evidence of provenance</xsl:when>
            <xsl:when test="$provenanceType eq 'c'">evidence from locally specific contents, including obits, scribbles, etc.</xsl:when>
            <xsl:when test="$provenanceType eq 'd'">evidence of dicta probatoria, usually a secundo folio</xsl:when>
            <xsl:when test="$provenanceType eq 'e'">evidence from an ex-libris inscription or note of gift to an institution</xsl:when>
            <xsl:when test="$provenanceType eq 'g'">evidence from an inscription consisting of a title or, when a pressmark, a personal name in the genitive case</xsl:when>
            <xsl:when test="$provenanceType eq 'i'">evidence from an inscription of ownership by an individual member of a religious house (which may not, however, be evidence for institutional ownership)</xsl:when>
            <xsl:when test="$provenanceType eq 'l'">liturgical evidence, often to be found in the kalendar</xsl:when>
            <xsl:when test="$provenanceType eq 'm'">evidence from marginalia, sometimes distinctive of a particular house or known scribe</xsl:when>
            <xsl:when test="$provenanceType eq 's'">evidence from the style of script or illumination</xsl:when>
            <xsl:otherwise>
                <xsl:text>inferred evidence</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- Book customisation to display Pressmarks and Catalogue Notes -->

    <xsl:template match="q[@type='pressmark']">
        <div class="tei-pressmark">
            <span class="tei-label">
                <xsl:copy-of select="bod:standardText('Pressmark:')"/>
                <xsl:text>&#x20;</xsl:text>
            </span>
            <xsl:text>'</xsl:text>
            <xsl:apply-templates/>
            <xsl:text>'</xsl:text>
        </div>
    </xsl:template>

    <xsl:template match="note[@type='MLGB3_medievalCatalogueNotes']">
        <div class="tei-med-cat-notes">
            <span class="tei-label">
                <xsl:copy-of select="bod:standardText('Medieval Catalogue Notes:')"/>
                <xsl:text>&#x20;</xsl:text>
            </span>
            <xsl:apply-templates/>
        </div>
    </xsl:template>

</xsl:stylesheet>
