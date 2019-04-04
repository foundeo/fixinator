/**
 * Downloads and Scans a package with Fixinator for Security Issues
 * .
 * Examples
 * {code:bash}
 * package-scan packageName@version
 * {code}
 **/
component extends="commandbox.system.BaseCommand" excludeFromHelp=false {

	
	property name="endpointService"	inject="endpointService";
	property name='fileSystem' inject='fileSystem';

	/**
	* @package.hint A package to scan
	* @package.optionsUDF packageComplete
	* @resultFile.hint A file path to write JSON results to
	* @resultFormat.hint The format to write the results in [json]
	* @verbose.hint When false limits the output
	* @listBy.hint Show results by type or file
	* @severity.hint The minimum severity warn, low, medium or high
	* @confidence.hint The minimum confidence level none, low, medium or high
	* @ignoreScanners.hint A comma seperated list of scanner ids to ignore
	* @autofix.hint Use either off, prompt or automatic
	**/
	function run(required package, string resultFile, string resultFormat="json", boolean verbose=true, string listBy="type", string severity="default", string confidence="default", string ignoreScanners="", autofix="off")  {
		
		var tempDir = getTempDirectory() & createUUID();
		var currentDir = fileSystem.resolvePath( './' );

		try {
			directoryCreate(tempDir);
			command("cd").params(directory=tempDir).run();
			command("install").params(id=package, directory=tempDir, production=true).run();

			arguments.path = tempDir;

			command( "fixinator" )
    		.params( argumentCollection=arguments )
    		.run();	
		} catch (any err) {
			if (err.message contains "exit code (1)") {
				setExitCode( 1 );
			} else {
				rethrow;
			}
			
		} finally {
			command("cd").params(directory=currentDir).run();
			directoryDelete(tempDir, true);
		}
		

	}


	function packageComplete( string paramSoFar ) {
		// Only hit forgebox if they've typed something.
		if( !len( trim( arguments.paramSoFar ) ) ) {
			return [];
		}
		try {
			
						
			var endpointName = configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );
			
			try {		
				var oEndpoint = endpointService.getEndpoint( endpointName );
			} catch( EndpointNotFound var e ) {
				error( e.message, e.detail ?: '' );
			}
			
			var forgebox = oEndpoint.getForgebox();
			var APIToken = oEndpoint.getAPIToken();
			
			// Get auto-complete options
			return forgebox.slugSearch( searchTerm=arguments.paramSoFar, APIToken=APIToken );
		} catch( forgebox var e ) {
			// Gracefully handle ForgeBox issues
			print
				.line()
				.yellowLine( e.message & chr( 10 ) & e.detail )
				.toConsole();
			// After outputting the message above on a new line, but the user back where they started.
			getShell().getReader().redrawLine();
		}
		// In case of error, break glass.
		return [];
	}

	

}