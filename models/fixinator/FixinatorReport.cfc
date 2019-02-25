<cfcomponent>

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
			<cfdocument format="PDF" filename="#arguments.resultFile#" overwrite="true"><cfoutput>#generateHTMLReport(data=arguments.data, listBy=arguments.listBy)#</cfoutput></cfdocument>
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
				</cfoutput>
			</body>
		</cfsavecontent>	
		<cfreturn html>
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