component {
    property name='fileSystem' inject='fileSystem';
    property name='print' inject='print';
    property inject="FixinatorClient@fixinator" name="fixinatorClient";

    variables.cachedResults = {};
    
    function onBulletTrain( interceptData ) {
        
        
        
        var previousExitCode = shell.getExitCode();
        
        try {
            var boxPath = fileSystem.resolvePath( './box.json' );
            
            if( !fileExists(boxPath) ) {
                //hide car when no box.js
                interceptData.cars.delete( 'fixinator', false );
            } else {
                
                local.fileHash = hash( fileRead(boxPath), "SHA-256" );
                if (variables.cachedResults.keyExists(boxPath) && variables.cachedResults[boxPath].fileHash == local.fileHash) {
                    local.results = variables.cachedResults[boxPath].results;
                } else {
                    local.results = fixinatorClient.run(path=boxPath);
                    variables.cachedResults[boxPath] = { fileHash=local.fileHash, results=local.results };    
                }


                if (arrayLen(local.results.results) > 0) {
                    interceptData.cars.fixinator.background = "Maroon";  
                    local.additional = arrayLen(local.results.results) & " vulnerable " & ( arrayLen(local.results.results)==1 ? "dependency" : "dependencies" );
                    interceptData.cars.fixinator.text = print.text( ' <!> Fixinator: #local.additional# ', 'whiteOn#interceptData.cars.fixinator.background#' );
                } else {
                    interceptData.cars.fixinator.background = "DarkGreen";  
                    interceptData.cars.fixinator.text = print.text( ' <✓> ', 'whiteOn#interceptData.cars.fixinator.background#' );
                }

                

            }
            
        
        } catch( any var e ) {
            // If there was an issue, hide the car
            interceptData.cars.delete( 'fixinator', false );
            
            // If it was a "real" error, log it
            if( !e.message.findNoCase( 'not implemented' ) ) {
                log.error( 'Error in Fixinator Bullet Train ', e.message & ' ' & e.detail );
            }
        } finally {
            
            // Put this guy back in case one of my cars above clobbered him
            if( shell.getExitCode() != previousExitCode ) {
                shell.setExitCode( previousExitCode );
            }
        }
        
    }
    
    
    function onCLIStart( required struct interceptData ) {
        // This is a dummy placeholder so the InterceptorService 
        // doesn't reject this CFC as having no valid states if Bullet Train isn't installed. 
    }
    
}