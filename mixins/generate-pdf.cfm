<!--- this exists as a mixin because in some cases the cfdocument tag may not be 
	avaliable on lucee (lucee light, or some error loading extensions) --->
<cffunction name="generatePDF" output="false" access="public">
	<cfargument name="resultFile" default="">
	<cfargument name="html">
	<cfdocument format="PDF" filename="#arguments.resultFile#" overwrite="true"><cfoutput>#arguments.html#</cfoutput></cfdocument>
</cffunction>