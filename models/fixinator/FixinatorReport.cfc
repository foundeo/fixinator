<cfcomponent>
	
	<cfif server.keyExists("lucee") AND NOT getTagList().cf.keyExists( 'document' )>
		<cfset variables.hasCFDocument = false>
	<cfelse>
		<cfset variables.hasCFDocument = true>
		<cfinclude template="../../mixins/generate-pdf.cfm">
	</cfif>

	<cffunction name="generateReport" output="false" access="public">
		<cfargument name="format" default="html">
		<cfargument name="resultFile" default="">
		<cfargument name="data">
		<cfargument name="listBy" type="string" default="type">
		<cfif format IS "json">
			<cfset fileWrite(arguments.resultFile, serializeJSON(arguments.data))>
		<cfelseif format IS "html">
			<cfset fileWrite(arguments.resultFile, generateHTMLReport(data=arguments.data, listBy=arguments.listBy))>
		<cfelseif format IS "pdf">
			<cfif variables.hasCFDocument>
				<cfset generatePDF(resultFile=arguments.resultFile, html=generateHTMLReport(data=arguments.data, listBy=arguments.listBy))>
			<cfelse>
				<cfthrow message="The cfdocument extension failed to load, so I'm unable to generate a PDF">
			</cfif>
		<cfelseif format IS "junit">
			<cfset fileWrite(arguments.resultFile, generateJUnitReport(data=arguments.data))>
		<cfelseif format IS "sast">
			<cfset fileWrite(arguments.resultFile, generateSASTReport(data=arguments.data))>
		<cfelse>
			<cfthrow message="Unsupported result file format">
		</cfif>
	</cffunction>

	<cffunction name="generateHTMLReport" output="false" access="public">
		<cfargument name="data">
		<cfargument name="listBy" type="string" default="type">
		<cfset var html = "">
		<cfset var resultsByType = {}>
		<cfset var typeKey = "">
		<cfset var result = "">

		<cfloop array="#arguments.data.results#" index="local.i">
			<cfset local.typeKey = "">
			<cfif arguments.listBy IS "type">
					<cfif local.i.keyExists("title") AND len(local.i.title)>
						<cfset local.typeKey = local.i.title>
					</cfif>
					<cfset local.typeKey = local.typeKey & " [" & local.i.id & "]">
			<cfelse>
					<cfset local.typeKey = local.i.path>
			</cfif>
			<cfif NOT resultsByType.keyExists(local.typeKey)>
					<cfset resultsByType[local.typeKey] = []>
			</cfif>
			<cfset arrayAppend(resultsByType[local.typeKey], local.i)>
		</cfloop>

			
		<cfsavecontent variable="html">
			<!doctype html>
			<head>
				<title>Fixinator Scan Report</title>
				<style>	
					body, td, th {
						font-family: "Helvetica Neue", Helvetica;
						font-weight: 200;
					}
					.type-key {
						border-bottom: 1px solid black;
					}
					.issue-message { 
						color:#bbb;
						margin-left: 15px;
					}
					.issue-context {
						margin-left: 15px;
						border-left: 1px solid black;
						padding: 10px;
					}
					.issue-badges {
						margin-left: 15px;
						margin-bottom: 10px;
					}
					.issue {
						padding-left: 5px;
					}
					.badge { width: 30px; padding: 4px; }
					.ind-1 { background-color:RebeccaPurple; color:white; }
					.ind-2 { background-color:orange; color:white; }
					.ind-3 { background-color:red; color:white; }
				</style>
			</head>
			<body>
				<h1>Fixinator Scan Results</h1>
				<p>Report generated on <cfoutput>#dateTimeFormat(now(), "full")#</cfoutput>
				<cfoutput>
					<cfif arrayLen(data.results) GT 0>
						<cfif arguments.listBy IS "type">
							<table border="0" cellspacing="0" cellpadding="8">
								<tr>
									<th>Issue Type</th>
									<th>Occurrences</th>
								</tr>
								<cfloop item="typeKey" collection="#resultsByType#"> 
									<tr>
										<td>#encodeForHTML(typeKey)#</td>
										<th><a href="###hash(typeKey, "SHA-256")#">#int(arrayLen(resultsByType[typeKey]))#</a></th>
									</tr>
								</cfloop>
							</table>
						</cfif>

						<cfloop item="typeKey" collection="#resultsByType#"> 
							<h2 class="type-key" id="#hash(typeKey, "SHA-256")#">#encodeForHTML(typeKey)#</h2>
							<cfloop array="#resultsByType[typeKey]#" index="local.i">
								<div class="issue">
									<cfif arguments.listBy IS "type">
										<h3>#encodeForHTML(local.i.path)#:#int(local.i.line)#</h3>
									<cfelse>
										<h3>#encodeForHTML(local.i.id)# on line #int(local.i.line)#</h3>
									</cfif>
									<div class="issue-badges">
										 <span class="badge ind-#int(local.i.severity)#">Severity: #getIndicatorAsText(local.i.severity)#</span>
										<span class="badge ind-#int(local.i.confidence)#">Confidence: #getIndicatorAsText(local.i.confidence)#</span>

									</div>
									<cfif local.i.keyExists("message") AND len(local.i.message)>
										<div class="issue-message">
											#encodeForHTML(local.i.message)#
										</div>	
									</cfif>
									
									<cfif len(local.i.context)>
										<pre class="issue-context">#encodeForHTML(local.i.context)#</pre>
									</cfif>
								</div>
							</cfloop>
						</cfloop>
					<cfelse>
						<p><strong>0 findings.</strong></p>
					</cfif>
					<cfif structKeyExists(data, "config")>
						<h4>Configuration Summary</h4>
						<table border="0" cellspacing="0" cellpadding="6">
							<tr>
								<th align="right">Minimum Severity:</th>
								<td><cfif structKeyExists(data.config, "minSeverity")>#encodeForHTML(data.config.minSeverity)#<cfelse>-</cfif></td>
							</tr>
							<tr>
								<th align="right">Minimum Confidence:</th>
								<td><cfif structKeyExists(data.config, "minConfidence")>#encodeForHTML(data.config.minConfidence)#<cfelse>-</cfif></td>
							</tr>
							<tr>
								<th align="right">Ignored Extensions:</th>
								<td>
									<cfif structKeyExists(data.config, "ignoreExtensions") AND isArray(data.config.ignoreExtensions)>
										<cfif arrayLen(data.config.ignoreExtensions) EQ 0>
											<em>None</em>
										<cfelse>
											#encodeForHTML(arrayToList(data.config.ignoreExtensions, ", "))#
										</cfif>
									<cfelse>
										-
									</cfif>
								</td>
							</tr>
							<tr>
								<th align="right">Ignored Paths:</th>
								<td>
									<cfif structKeyExists(data.config, "ignorePaths") AND isArray(data.config.ignorePaths)>
										<cfif arrayLen(data.config.ignorePaths) EQ 0>
											<em>None</em>
										<cfelse>
											#encodeForHTML(arrayToList(data.config.ignorePaths, ", "))#
										</cfif>
									<cfelse>
										-
									</cfif>
								</td>
							</tr>
							<tr>
								<th align="right">Ignored Scanners:</th>
								<td>
									<cfif structKeyExists(data.config, "ignoreScanners") AND isArray(data.config.ignoreScanners)>
										<cfif arrayLen(data.config.ignoreScanners) EQ 0>
											<em>None</em>
										<cfelse>
											#encodeForHTML(arrayToList(data.config.ignoreScanners, ", "))#
										</cfif>
									<cfelse>
										-
									</cfif>
								</td>
							</tr>
						</table>
					</cfif>
				</cfoutput>
			</body>
		</cfsavecontent>	
		<cfreturn html>
	</cffunction>

	<cffunction name="generateJUnitReport" returntype="string" output="false">
		<cfargument name="data">
		<cfset var xml = "">
		<cfset var resultsByScanner = {}>
		<cfset var scannerCounts = {}>
		<cfset var totalTypes = 0>
		<cfset var typeTitle = {}>
		<cfset var typeKey = "">
		<cfset var result = "">
		<!--- sort into types --->
		<cfloop array="#arguments.data.results#" index="local.i">
			<cfset local.scanner = local.i.scanner>
			<cfif NOT resultsByScanner.keyExists(local.scanner)>
				<cfset resultsByScanner[local.scanner] = {}>
				<cfset scannerCounts[local.scanner] = 0>
			</cfif>
			<cfset local.typeKey = local.i.id>
			<cfif NOT resultsByScanner[local.scanner].keyExists(local.typeKey)>
				<cfset resultsByScanner[local.scanner][local.typeKey] = []>
				<cfset totalTypes = totalTypes + 1>
				<cfif local.i.keyExists("title")>
					<cfset typeTitle[local.i.id] = local.i.title>
				<cfelse>
					<cfset typeTitle[local.i.id] = local.i.id>
				</cfif>
			</cfif>
			<cfset scannerCounts[local.scanner] = scannerCounts[local.scanner]+1>
			<cfset arrayAppend(resultsByScanner[local.scanner][local.typeKey], local.i)>
		</cfloop>
		<cfsavecontent variable="xml"><?xml version="1.0" encoding="UTF-8" ?>
			<cfoutput>
			<testsuites id="#dateTimeFormat(now(), 'yyyymmdd-HHmmss')#" name="Fixinator Scan Results (#dateTimeFormat(now(), 'yyyy-mm-dd HH:mm:ss')#" tests="#int(totalTypes)#" failures="#arrayLen(data.results)#" time="0">
				<cfloop list="#structKeyList(resultsByScanner)#" index="local.scanner">
					<testsuite id="#encodeForXML(local.scanner)#" name="#encodeForXML(local.scanner)#" tests="#structCount(resultsByScanner[local.scanner])#" failures="#scannerCounts[local.scanner]#" time="0">
						<cfloop list="#structKeyList(resultsByScanner[local.scanner])#" index="local.typeKey">
							<testcase id="#encodeForXMLAttribute(local.typeKey)#" name="#typeTitle[local.typeKey]# [#local.typeKey#]" time="0">
								<cfloop array="#resultsByScanner[local.scanner][local.typeKey]#" index="result">
									<failure message="#encodeForXMLAttribute(result.message)#" type="#getIndicatorAsText(result.severity)#">#getIndicatorAsText(result.severity)#: #encodeForXML(result.message)##chr(10)#File: #encodeForXML(result.path)##chr(10)#Line: #encodeForXML(result.line)#</failure>
								</cfloop>
							</testcase>
						</cfloop>
					</testsuite>
				</cfloop>
			</testsuites>
			</cfoutput>
		</cfsavecontent>
		<cfreturn xml>
	</cffunction>

	<cffunction name="generateSASTReport" returntype="string" output="false">
		<cfargument name="data">
		<cfset var sast = {"version"="2.0", "vulnerabilities"=[]}>
		<cfset var i = "">
		<cfset var v = "">
		<!--- docs: https://gitlab.com/help/user/application_security/sast/index#reports-json-format --->
		<cfloop array="#arguments.data.results#" index="i">
			<cfset v = {"category"="sast", "name"="", "message"="", "description"="", "severity"="", "confidence"="", "scanner"={"id"="", "name"=""}, "location"={}, "identifiers"=[]}>
			<cfif i.keyExists("title")>
				<cfset v.name = i.title>
			</cfif>
			<cfif i.keyExists("message")>
				<cfset v.message = i.message>
			</cfif>
			<cfif i.keyExists("description")>
				<cfset v.description = i.description>
			</cfif>
			<cfif i.keyExists("severity")>
				<cfif i.severity EQ 3>
					<cfset v.severity = "High">
				<cfelseif i.severity EQ 2>
					<cfset v.severity = "Medium">
				<cfelse>
					<cfset v.severity = "Low">
				</cfif>
			</cfif>
			<cfif i.keyExists("confidence")>
				<cfif i.confidence EQ 3>
					<cfset v.confidence = "High">
				<cfelseif i.confidence EQ 2>
					<cfset v.confidence = "Medium">
				<cfelse>
					<cfset v.confidence = "Low">
				</cfif>
			</cfif>
			<cfif i.keyExists("id")>
				<cfset v.scanner.id = "fixinator-" & i.id>
			</cfif>
			<cfif i.keyExists("category")>
				<cfset v.scanner.name = i.category & " (#v.scanner.id#)">
			</cfif>
			<cfif i.keyExists("path")>
				<cfset local.p = i.path>
				<cfif left(local.p, 1) IS "/">
					<cfset local.p = replace(local.p, "/", "", "ONE")>
				</cfif>
				<cfset v.location["file"] = local.p>
				<cfif right(local.p, 3) IS "cfc">
					<cfset local.className = left(local.p, len(local.p) - 4)>
					<cfset replace(local.p, "/", ".", "ALL")>
					<cfset replace(local.p, "\", ".", "ALL")>
					<cfset v.location["class"] = local.className>
				</cfif>
			</cfif>
			<cfif i.keyExists("function") AND len(i.function)>
				<cfset v.location["method"] = i.function>
			</cfif>
			<cfif i.keyExists("line")>
				<cfset v.location["start_line"] = i.line>
			</cfif>
			<cfset local.cveRaw = "#v.file#:#v.start_line#">
			<cfif i.keyExists("column")>
				<cfset local.cveRaw &= ":#i.column#">
			</cfif>
			<cfif i.keyExists("context")>
				<cfset local.cveRaw &= ":#i.context#">
			</cfif>
			<cfset v["cve"] = hash(local.cveRaw, "SHA-256") & ":" & v.scanner.id>
			<cfset v.location["dependency"] = {}>
			<cfset arrayAppend(v.identifiers, {"type"="fixinator_test_id", "name"="Fixinator Test ID", "value"=i.id, "url"="https://fixinator.app/"})>
			<cfif i.keyExists("link") AND len(i.link)>
				<cfset arrayAppend(v.identifiers, {"type"="fixinator_link", "name"="More Info Link", "value"=i.link, "url"=i.link})>
			</cfif>
			<cfset arrayAppend(sast.vulnerabilities, v)>
		</cfloop>
		<cfreturn serializeJSON(sast)>
	</cffunction>

	<cffunction name="getIndicatorAsText" access="private">
		<cfargument name="indicator" type="numeric">
		<cfswitch expression="#arguments.indicator#">
			<cfcase value="0"><cfreturn "NONE"></cfcase>
			<cfcase value="1"><cfreturn "LOW"></cfcase>
			<cfcase value="2"><cfreturn "MEDIUM"></cfcase>
			<cfcase value="3"><cfreturn "HIGH"></cfcase>
			<cfdefaultcase><cfreturn "UNKNOWN"></cfdefaultcase>
		</cfswitch>	
	</cffunction>

</cfcomponent>