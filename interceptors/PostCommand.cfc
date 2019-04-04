component {
	
	property inject="FixinatorClient@fixinator" name="fixinatorClient";
	property name='fileSystem' inject='fileSystem';

	function postCommand(interceptData) {
		var previousExitCode = shell.getExitCode();
		try {
			if ( listFind("install,update,uninstall", interceptData.commandInfo.commandString) ) {
				var boxPath = fileSystem.resolvePath( './box.json' );
				if (fileExists(boxPath)) {
					shell.printString( chr( 10 ) );
					shell.printString( "Running Fixinator to Check for Vulnerabilities... #chr( 10 )#" );
					getinstance( name='CommandDSL', initArguments={ name : "fixinator" } ).params(path=boxPath).run();	
				}
			}
		} catch (any err) {
			if (err.message contains "exit code (1)") {
				shell.setExitCode( 1 );
			} else {
				rethrow;
			}
		} finally {
			if( shell.getExitCode() != previousExitCode && shell.getExitCode() == 0 ) {
                shell.setExitCode( previousExitCode );
            }
		}
		
	}

	function onCLIStart( required struct interceptData ) {

    }

}