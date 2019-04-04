/**
 * Scans box.json files for Security Issues
 * .
 * Examples
 * {code:bash}
 * audit box.json
 * {code}
 **/
component extends="commandbox.system.BaseCommand" excludeFromHelp=false {

	


	/**
	* @path.hint A file or directory to scan
	* @resultFile.hint A file path to write JSON results to
	* @resultFormat.hint The format to write the results in [json]
	* @verbose.hint When false limits the output
	* @listBy.hint Show results by type or file
	* @severity.hint The minimum severity warn, low, medium or high
	* @confidence.hint The minimum confidence level none, low, medium or high
	* @ignoreScanners.hint A comma seperated list of scanner ids to ignore
	* @autofix.hint Use either off, prompt or automatic
	**/
	function run(path="./box.json", string resultFile, string resultFormat="json", boolean verbose=true, string listBy="type", string severity="default", string confidence="default", string ignoreScanners="", autofix="off")  {
		

		arguments.path = fileSystemUtil.resolvePath(arguments.path);
		if (directoryExists(arguments.path)) {
			arguments.path = arguments.path & "box.json";
		}
		if (fileExists(arguments.path) && getFileFromPath(arguments.path) == "box.json") {
			print.line("Auditing box.json dependencies...");
		} else { 
			print.redLine("You must run audit against a box.json file or from a directory that contains one");
			setExitCode(1);
			return;
		}
		

		try {
			command( "fixinator" )
    		.params( argumentCollection=arguments )
    		.run();	
		} catch (any err) {
			if (err.message contains "exit code (1)") {
				setExitCode( 1 );
			} else {
				rethrow;
			}
			
		}
		

	}

	

}