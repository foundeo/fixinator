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
					<cfset local.typeKey = local.i.id>
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
				<title>Fixinator Report</title>
			</head>
			<body>
				<h1>Fixinator Report</h1>
				<cfoutput>
					<cfloop item="typeKey" collection="#resultsByType#"> 
						<h2>#encodeForHTML(typeKey)#</h2>
						<cfloop array="#resultsByType[typeKey]#" index="local.i">
							<cfif arguments.listBy IS "type">
								<h3>#encodeForHTML(local.i.path)#:#int(local.i.line)#</h3>
							<cfelse>
								<h3>#encodeForHTML(local.i.id)# on line #int(local.i.line)#</h3>
							</cfif>
							<cfif len(local.i.context)>
								<pre>#local.i.context#</pre>
							</cfif>
						</cfloop>
					</cfloop>
				</cfoutput>
			</body>
		</cfsavecontent>	
		<cfreturn html>
	</cffunction>	

</cfcomponent>