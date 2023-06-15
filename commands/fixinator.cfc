/**
 * Scans CFML Source Code for Issues
 * .
 * Examples
 * {code:bash}
 * fixinator path
 * {code}
 **/
component extends="commandbox.system.BaseCommand" excludeFromHelp=false {

	property inject="FixinatorClient@fixinator" name="fixinatorClient";
	property inject="FixinatorReport@fixinator" name="fixinatorReport";
	property inject="progressBarGeneric" name="progressBar";
	property name="configService" inject="configService";
	property name="shell" inject="shell";


	/**
	* @path.hint A file or directory to scan
	* @resultFile.hint A file path to write the results to - see resultFormat
	* @resultFormat.hint The format to write the results in [json,html,pdf,junit,findbugs,sast,csv]
	* @resultFormat.optionsUDF resultFormatComplete
	* @verbose.hint When false limits the output
	* @listBy.hint Show results by type or file
	* @severity.hint The minimum severity warn, low, medium or high
	* @severity.optionsUDF severityComplete
	* @confidence.hint The minimum confidence level none, low, medium or high
	* @confidence.optionsUDF confidenceComplete
	* @ignoreScanners.hint A comma seperated list of scanner ids to ignore
	* @autofix.hint Use either off, prompt or automatic
	* @failOnIssues.hint Determines if an exit code is set to 1 when issues are found.
	* @debug.hint Enable debug mode
	* @listScanners.hint List the types of scanners that are enabled, enabled automatically when verbose=true
	* @ignorePaths.hint A globber paths pattern to exclude
	* @ignoreExtensions.hint A list of extensions to exclude
	* @gitLastCommit.hint Scan only files changed in the last git commit
	* @gitWorkingCopy.hint Scan only files changed since the last commit in the working copy
	**/
	function run(
        string path=".",
        string resultFile,
        string resultFormat="json",
        boolean verbose=true,
        string listBy="type",
        string severity="default",
        string confidence="default",
        string ignoreScanners="",
        autofix="off",
        boolean failOnIssues=true,
        boolean debug=false,
        boolean listScanners=false,
        string ignorePaths="",
        string ignoreExtensions="",
		boolean gitLastCommit=false,
		boolean gitChanged=false,
    )  {
		var fileInfo = "";
		var severityLevel = 1;
		var confLevel = 1;
		var config = {};
		var toFix = [];
		var paths = [];
		if (arguments.verbose) {
			//arguments.listScanners = true;
			
			print.greenLine("fixinator v#fixinatorClient.getClientVersion()# built by Foundeo Inc.").line();
			print.grayLine("    ___                      _             ");
			print.grayLine("   / __)                    | |            ");		
			print.grayLine(" _| |__ ___  _   _ ____   __| |_____  ___  ");
			print.grayLine("(_   __) _ \| | | |  _ \ / _  | ___ |/ _ \ ");
			print.grayLine("  | | | |_| | |_| | | | ( (_| | ____| |_| |");
			print.grayLine("  |_|  \___/|____/|_| |_|\____|_____)\___/ ");
			print.grayLine("                                         inc.");
			print.line();
		}



		if (configService.getSetting("modules.fixinator.api_key", "UNDEFINED") != "UNDEFINED") {
			fixinatorClient.setAPIKey(configService.getSetting("modules.fixinator.api_key", "UNDEFINED"));
		}

		if (fixinatorClient.getAPIKey() == "UNDEFINED") {
			print.boldOrangeLine("Missing Fixinator API Key");
			print.orangeLine("  Set via commandbox: config set modules.fixinator.api_key=YOUR_API_KEY");
			print.orangeLine("  Or set an environment variable FIXINATOR_API_KEY=YOUR_API_KEY");
			print.line();
			print.line("For details please visit: https://fixinator.app/");
			print.line();
			if (isRunningInCI()) {
				//in CI we don't want to prompt
				print.line("Detected CI Envrionment. Please add the FIXINATOR_API_KEY as a secure environment variable to your CI platform.");

				if (isTravisCI()) {
					print.line("Documentation: https://github.com/foundeo/fixinator/wiki/Running-Fixinator-on-Travis-CI");
				}

				if (isBitbucketPipeline()) {
					print.line("Documentation: https://github.com/foundeo/fixinator/wiki/Running-Fixinator-on-Bitbucket");	
				}
				if (isTFS()) {
					print.line("Documentation: https://github.com/foundeo/fixinator/wiki/Running-Fixinator-on-Azure-DevOps-Pipelines-or-TFS");		
				}
				if (isCircleCI()) {
					print.line("Documentation: https://github.com/foundeo/fixinator/wiki/Running-Fixinator-on-CircleCI");	
				}
				if (isCodeBuild()) {
					print.line("Documentation: https://github.com/foundeo/fixinator/wiki/Running-Fixinator-on-AWS-CodeBuild");	
				}
				if (isJenkins()) {
					print.line("Documentation: https://github.com/foundeo/fixinator/wiki/Running-Fixinator-on-Jenkins");
				}


				setExitCode(1);
				return;
			} else {

			}
			local.email = ask(message="Do you want to request a free key? Please enter your email: ");
			if (isValid("email", local.email)) {
				local.phone = ask(message="Phone Number (Optional): ");
				cfhttp(method="POST", url="https://foundeo.us1.list-manage.com/subscribe/post?u=c10e46f0371b0cedc2340d2d4&id=37b8e52f1a", result="local.httpResult") {
					cfhttpparam(name="EMAIL", value=local.email, type="formfield");
					cfhttpparam(name="PHONE", value=local.phone, type="formfield");
				}
				if (local.httpResult.statusCode contains "200") {
					print.boldGreenLine("Thanks, your request has been submitted.");
				} else {
					print.boldRedLine("Looks like there was an error submitting your request, please contact Foundeo inc. directly.");
				}
			}

			return;
		}

		//since api url is referenced below, set this first
		if (configService.getSetting("modules.fixinator.api_url", "UNDEFINED") != "UNDEFINED") {
			fixinatorClient.setAPIURL(configService.getSetting("modules.fixinator.api_url", "UNDEFINED"));
		}

		if (fixinatorClient.isCloudAPIURL() && configService.getSetting("modules.fixinator.accept_policy", "UNDEFINED") == "UNDEFINED") {
			print.line();
			print.line("Fixinator will send source code to: " & fixinatorClient.getAPIURL());
			print.line("for scanning. The code is kept in RAM during scanning and is not persisted.");
			print.line("For details see: https://github.com/foundeo/fixinator/wiki/How-Does-Fixinator-Work");
			print.line();
			print.yellowBoldLine("Note: The enterprise version allows you to run the code scanner fully on your own servers.");
			if (isRunningInCI()) {
				print.line("Detected CI Environment, I will continue without prompting");
			} else {
				local.response = ask("Please type ok or hit enter to accept (ok):");
				if (len(local.response) == 0 || local.response == "ok") {
					print.greenLine("✓ Policy accepted.");
					command("config set").params("modules.fixinator.accept_policy"="yes").run();
				} else {
					print.redLine("Canceling scan request.");
					setExitCode(1);
					return;
				}
			}
			
		}

		

		if (configService.getSetting("modules.fixinator.max_payload_size", "UNDEFINED") != "UNDEFINED") {
			fixinatorClient.setMaxPayloadSize(configService.getSetting("modules.fixinator.max_payload_size", "UNDEFINED"));
		}

		if (configService.getSetting("modules.fixinator.max_payload_file_count", "UNDEFINED") != "UNDEFINED") {
			fixinatorClient.setMaxPayloadFileCount(configService.getSetting("modules.fixinator.max_payload_file_count", "UNDEFINED"));
		}

		if (configService.getSetting("modules.fixinator.api_timeout", "UNDEFINED") != "UNDEFINED") {
			fixinatorClient.setAPITimeout(configService.getSetting("modules.fixinator.api_timeout", "35"));
		}

		if (arguments.verbose) {
			print.greenLine("Fixinator API Server: #fixinatorClient.getAPIURL()#");
		}

		if (arguments.debug) {
			fixinatorClient.setDebugMode(true);
			print.greenLine("✓ DEBUG MODE ENABLED: #fixinatorClient.isDebugModeEnabled()#");
			print.greenLine("   ↳ #expandPath("{lucee-web}/logs/fixinator-client-debug.log")#");
		}

		
		if (arguments.gitLastCommit || arguments.gitChanged) {
			//we are going to use git data to build file list
			if (arguments.gitLastCommit && arguments.gitChanged) {
				//this might be handy to enable 
				error("You cannot enable both gitLastCommit and gitChanged at the same time");
			}
			try {
				if (arguments.gitLastCommit && arguments.verbose) {
					print.yellowLine("Scanning only files changed in the last git commit.");
				} else {
					print.yellowLine("Scanning only files changed since the last git commit.");
				}
				arguments.path = fileSystemUtil.resolvePath( arguments.path );
				local.gitChanges = getGitChanges(path=arguments.path, lastCommit=arguments.gitLastCommit);
				for (local.change in local.gitChanges) {
					if (change.type == "DELETE") {
						if (arguments.verbose) {
							print.redLine("  D: #change.previousPath#");
						}
					} else if (change.type == "MODIFY") {
						if (arguments.verbose) {
							print.greenLine("  M: #change.path#");
						}
						arrayAppend(paths, getDirectoryFromPath(arguments.path) & change.path);
					} else if (change.type == "ADD") {
							if (arguments.verbose) {
								print.greenLine("  A: #change.path#");
							}
							arrayAppend(paths, getDirectoryFromPath(arguments.path) & change.path);
					} else {
						if (arguments.verbose) {
							print.yellowLine("  #change.type#: #change.path# #change.previousPath#");
						}
						arrayAppend(paths, getDirectoryFromPath(arguments.path) & change.path);
					}
				}
				
				if (arrayLen(paths) == 0) {
					print.redLine("No scannable paths found.");
					return;
				} else if (len(arguments.ignorePaths)) {
					error("Sorry ignorePaths is not currently supported with gitLastCommit or gitChanged");
				}
			} catch (any err) {
				error("Error checking for git files, make sure this is a git repository and path is pointing to the root of it: #err.message# - #err.detail# -- #err.stacktrace#")
			}			
		} else if (arguments.path contains "*" || arguments.path contains "," || len(arguments.ignorePaths)) {
			local.newPath = arguments.path.listMap( (p) => {
				p = fileSystemUtil.resolvePath( p );
				if ( directoryExists( p ) ) {
					return p & "**";
				}
				return p;
			} );
			local.glob = globber(local.newPath);
			if ( val(listFirst(shell.getVersion(), ".")) GTE 5 ) {
				local.ignorePathPatterns = arguments.ignorePaths.listMap( ( p ) => {
					p = fileSystemUtil.resolvePath( p );
					if ( directoryExists( p ) ) {
						return p & "**";
					}
					return p;
				} );
				local.glob = local.glob.setExcludePattern(local.ignorePathPatterns);
			} else if (len(arguments.ignorePaths)) {
				error("You specified ignorePaths, but you are using an old version of CommandBox: #shell.getVersion()#. Upgrade to the latest version >=5");
			}
			paths = local.glob.asArray().matches();
			if (arrayLen(paths) == 0) {
				//no files match globber
				error("No files matched your globber patterns");
			}
			print.greenLine(serializeJSON(paths));
			if (find("*", arguments.path) || find(",", arguments.path)) {
				arguments.path = "";
				local.pathsBelowCurrent = 0;
				for (local.p in paths) {
					if (find(shell.pwd(), local.p) == 1) {
						local.pathsBelowCurrent++;
					}
				}
				if (local.pathsBelowCurrent == arrayLen(paths)) {
					//all paths are under current path so set that as the base path
					arguments.path = shell.pwd();
				}
			} else {
				arguments.path = fileSystemUtil.resolvePath( arguments.path );
			}
			//return;
		} else {
			//single path
			arguments.path = fileSystemUtil.resolvePath( arguments.path );
		}

		
		
		



		if (!listFindNoCase("warn,low,medium,high", arguments.severity)) {
			if (arguments.severity !="default") {
				print.redLine("Invalid minimum severity level, use: warn,low,medium,high");
				return;
			}
		} else {
			config.minSeverity = arguments.severity;
		}

		if (!listFindNoCase("none,low,medium,high", arguments.confidence)) {
			if (arguments.confidence != "default") {
				print.redLine("Invalid minimum confidence level, use: none,low,medium,high");
				return;	
			}
			
		} else {
			config.minConfidence = arguments.confidence;
		}

		if (len(arguments.ignoreScanners)) {
			config.ignoreScanners = listToArray(replace(arguments.ignoreScanners, " ", "", "ALL"));
		}

		if (len(arguments.ignoreExtensions)) {
			config.ignoreExtensions = listToArray(replace(arguments.ignoreExtensions, " ", "", "ALL"));
		}


		if (!fileExists(arguments.path) && !directoryExists(arguments.path) && !arrayLen(paths)) {
			print.boldRedLine("Sorry: #arguments.path# is not a file or directory.");
			return;
		}

		fileInfo = getFileInfo(arguments.path);
		
		if (!fileInfo.canRead) {
			print.boldRedLine("Sorry: No read permission for source path");
			return;
		}

		
		
		try {
			
			/*
			if (arguments.verbose) {
				//show status dots
				variables.fixinatorRunning = true;
				variables.fixinatorThread = "fixinator" & createUUID();
				
				thread action="run" name="#variables.fixinatorThread#" print="#print#" {
	 				// do single thread stuff 
	 				thread.i = 0;
	 				for (thread.i=0;thread.i<50;thread.i++) {
	 					attributes.print.text(".").toConsole();
	 					thread action="sleep" duration="1000";
	 					cflock(name="fixinator-command-lock", type="readonly", timeout=1) {
	 						if (!variables.fixinatorRunning) {
	 							break;
	 						}
	 					}
	 				}
				}
			}

			local.results = fixinatorClient.run(path=arguments.path,config=config);	
			if (arguments.verbose) {
				//stop status indicator
				cflock(name="fixinator-command-lock", type="exclusive", timeout="5") {
					variables.fixinatorRunning = false;

				}
				thread action="terminate", name="#variables.fixinatorThread#";
				print.line();
			}*/
			
			/* progress bar version */
			if (arguments.verbose) {
				//show progress bars
				print.line().toConsole();
				progressBar.clear();
				//job.start("Scanning " & arguments.path);
				print.greenLine("Scanning " & arguments.path);
				if (arguments.debug && arrayLen(paths)) {
					for (local.p in paths) {
						print.greenLine(" " & local.p);
					}
				}
				progressBar.update( percent=0 );
				local.results = fixinatorClient.run(path=arguments.path, config=config, progressBar=progressBar, paths=paths);	
				progressBar.clear();
			} else {
				//no progress bar or interactive job output
				local.results = fixinatorClient.run(path=arguments.path, config=config, paths=paths);	
			}
			

			
		} catch(err) {
			cflock(name="fixinator-command-lock", type="exclusive", timeout="5") {
				variables.fixinatorRunning = false;
			}
			if (err.type == "FixinatorClient") {
				if (arguments.verbose) {
					progressBar.clear();
				}
				print.line().boldRedLine("---- Fixinator Client Error ----").line();
				print.redLine(err.message);
				if (structKeyExists(err, "detail")) {
					print.whiteLine(err.detail);	
				}
				error("Fixinator Exiting Due to Error");
				return;
			} else {
				rethrow;
			}
		} finally {
			if (arguments.verbose) {
				progressBar.clear();
				//job.complete( dumpLog=true );	
			}
		}
		
		if (len(arguments.resultFile)) {
			local.resultIndex = 0;
			//allow a list of formats and file paths
			for (local.rFormat in listToArray(arguments.resultFormat)) {
				local.resultIndex++;
				local.rFile = listGetAt(arguments.resultFile, local.resultIndex);
				local.rFile = fileSystemUtil.resolvePath( local.rFile );	
				fixinatorReport.generateReport(resultFile=local.rFile, format=local.rFormat, listBy=arguments.listBy, data=local.results, fixinatorClientVersion=fixinatorClient.getClientVersion());	
			}
		}


		if (arrayLen(local.results.results) == 0 && arrayLen(local.results.warnings) == 0)   {
			print.line().boldGreenLine("✓ 0 Issues Found");
			if (arguments.verbose) {
				if (local.results.config.minSeverity != "low" || local.results.config.minConfidence != "low") {
					print.line().line("Tip: For additional results try decreasing the severity or confidence level to medium or low");
					print.line("For example: box fixinator confidence=low path=/some/file.cfm");
					print.line("    Currently: severity=#local.results.config.minSeverity# confidence=#local.results.config.minConfidence# ");

				}
			}
		} else {
			print.boldRedLine("FINDINGS: " & arrayLen(local.results.results));

			

			local.resultsByType = {};
			for (local.i in local.results.results) {
				local.typeKey = "";
				if (arguments.listBy == "type") {
					local.typeKey = local.i.title & " [" & local.i.id & "]";
				} else {
					local.typeKey = local.i.path;
				}
				if (!local.resultsByType.keyExists(local.typeKey)) {
					local.resultsByType[local.typeKey] = [];
				}
				arrayAppend(local.resultsByType[local.typeKey], local.i);
			}

			for (local.typeKey in local.resultsByType) {
				if (arguments.verbose) {
					print.boldYellowLine(repeatString("-", 65));	
				}
				if (arguments.listBy == "type" && shell.getTermWidth() >= 65 && arguments.verbose) {
					if (len(local.typeKey) > 61) {
						print.boldYellowLine("| " & left(local.typeKey, 61) & " |");
					} else {
						print.boldYellowLine("| " & left(local.typeKey, 61) & repeatString(" ", 61-len(local.typeKey)) & " |");		
					}
					
				} else {
					print.boldYellowLine(local.typeKey);
				}
				if (arguments.verbose) {
					print.boldYellowLine(repeatString("-", 65));	
				}
				
				local.firstOfType = true;
				for (local.i in local.resultsByType[local.typeKey]) {
					if (!local.firstOfType && arguments.verbose) {
						print.line();
						//print.grayLine(repeatString("-", shell.getTermWidth()));
					} else {
						local.firstOfType = false;
					}
					if (arguments.listBy == "type") {
						local.line = "#local.i.path#:#local.i.line#";
						
					} else {
						local.line = "#local.i.title# [#local.i.id#] on line #local.i.line#";
					}
					/*
					if (local.i.severity == 3) {
						print.redLine("#local.line#");
					} else if (local.i.severity == 2) {
						print.magentaLine("#local.line#");
					} else if (local.i.severity == 1) {
						print.aquaLine("#local.line#");
					} else {
						print.yellowLine("#local.line#");
					}*/
					
					if (arguments.verbose) {
						print.line();
						local.conf = "";
						
						if (local.i.keyExists("confidence") && local.i.confidence > 0 && local.i.confidence <=3) {
							local.confMap = ["low confidence", "medium confidence", "high confidence"];
							local.conf = " " & local.confMap[local.i.confidence];
							if (local.i.confidence == 3) {
								local.possible = "";
							}
						}
						if (local.i.severity == 3) {
							print.redBoldLine("[HIGH] #local.i.message##local.conf#");
							//print.redBoldLine(repeatString("-", shell.getTermWidth()));
						} else if (local.i.severity == 2) {
							print.magentaBoldLine("[MEDIUM] #local.i.message##local.conf#");
							//print.magentaBoldLine(repeatString("-", shell.getTermWidth()));
						} else if (local.i.severity == 1) {
							print.aquaBoldLine("[LOW] #local.i.message##local.conf#");
							//print.aquaBoldLine(repeatString("-", shell.getTermWidth()));
						} else {
							print.yellowBoldLine("[WARN] #local.i.message##local.conf#");
							//print.aquaBoldLine("[WARN] #local.i.message##local.conf#");
						}
						if (local.i.keyExists("description") && len(local.i.description)) {
							print.line(local.i.description);
						}
						if (local.i.keyExists("link") && len(local.i.link)) {
							print.line("  " & local.i.link);
						}
						print.boldLine(local.line);
						if (len(local.i.context)) {
							print.boldGrayLine("#repeatString(" ", 5-len(local.i.line))##local.i.line#: #local.i.context#");
							print.line();
						}
						
						
						if (local.i.keyExists("fixes") && arrayLen(local.i.fixes) > 0) {
							print.greyLine("Possible Fixes:");
							local.fixIndex = 0;
							local.fixOptions = "";
							local.queryparamFix = 0;
							for (local.fix in local.i.fixes) {
								local.fixIndex++;
								local.fixOptions = listAppend(local.fixOptions, local.fixIndex);
								print.greyLine("        "&local.fixIndex&") "&local.fix.title & ": " & trim(local.fix.fixCode) );
								if ( findNoCase('cfsqltype="cf_sql_varchar"', local.fix.fixCode) ) {
									local.queryparamFix = local.fixIndex;
								}
							}
							if (arguments.autofix == "prompt") {
								print.toConsole();
								/*
								local.fix = multiselect()
									.setQuestion( 'Do you want to fix this?' )
									.setOptions( listAppend(local.fixOptions, "skip") )
									.ask();
								*/
								local.fixOptions = "1-#arrayLen(local.i.fixes)#";
								if (arrayLen(local.i.fixes) == 1) {
									local.fixOptions = "1";
								}

								if (local.queryparamFix == 0) {
									local.fix = ask(message="Do you want to fix this? Enter [#local.fixOptions#] or no: ");
								} else {
									local.fix = ask(message="Do you want to fix this? Enter [#local.fixOptions#] or cf_sql_whatever or no: ");
								}

								


								if (isNumeric(local.fix) && local.fix >= 1 && local.fix <= arrayLen(local.i.fixes)) {
									toFix.append({"fix":local.i.fixes[local.fix], "issue":local.i});
								} else if (len(local.fix) && !isNumeric(local.fix) && local.queryparamFix != 0 && !isBoolean(local.fix)) {
									//fixing with a custom cfsqltype
									local.customFix = duplicate( local.i.fixes[local.queryparamFix] );
									local.customFix.fixCode = replaceNoCase(local.customFix.fixCode, 'cfsqltype="cf_sql_varchar"', 'cfsqltype="#local.fix#"');
									arrayAppend(local.i.fixes, local.customFix);
									toFix.append({"fix":local.customFix, "issue":local.i});
								}

							} else if (arguments.autofix == "auto" || arguments.autofix == "automatic") {
								toFix.append({"fix":local.i.fixes[1], "issue":local.i});
							}
						}
					} else {
						print.line(local.line);
						if (local.i.keyExists("context") && len(local.i.context)) {
							print.grayLine("    " & left(local.i.context, shell.getTermWidth()-4));
						}
					}
				}
			}

			if (arguments.listScanners && local.results.keyExists("categories")) {
				print.line();
				print.line("Results by Scanner (confidence=#local.results.config.minConfidence#, severity=#local.results.config.minSeverity#):");
				for (local.cat in local.results.categories) {
					local.issues = 0;
					for (local.i in local.results.results) {
						if (local.i.id == local.cat) {
							local.issues++;
						}
					}
					if (local.issues == 0) {
						print.greenLine("  ✓ " & local.results.categories[cat].name & " [" & cat & "]" );
					} else {
						print.redLine("  ! " & local.results.categories[cat].name & " [" & cat & "] (" & local.issues & ")"  );
					}
				}
			}

			/*
			for (local.i in local.results.results) {
				if (arguments.verbose) {
					print.line();
					print.redLine(local.i.message);
					print.greyLine("#chr(9)##local.i.path#:#local.i.line#");
					if (len(local.i.context)) {
						print.greyLine("#chr(9)##local.i.context#");
					}
				} else {
					print.redLine("[#local.i.id#] #local.i.path#:#local.i.line#");
				}
			}*/
			if (arguments.verbose && arrayLen(local.results.warnings)) {
				print.line();
				print.boldOrangeLine("WARNINGS");
				for (local.w in local.results.warnings) {
					if (local.w.keyExists("message") && local.w.keyExists("path")) {
						print.grayLine(local.w.message);
						print.grayLine("  " & replaceNoCase(local.w.path, getDirectoryFromPath(arguments.path), ""));
					} else {
						print.grayLine(serializeJSON(local.w));
					}
					
				}
			}

			if (arrayLen(toFix) > 0) {
				print.line();
				local.msg = "FIXING #arrayLen(toFix)# issue" & ((arrayLen(toFix) != 1) ? "s" :"");
				print.boldOrangeLine(local.msg);
				local.fixResults = fixinatorClient.fixCode(basePath=arguments.path, fixes=toFix);

			}


			if (arguments.debug) {
				local.debugLogFile = expandPath("{lucee-web}/logs/fixinator-client-debug.log");
				print.line();
				if (fileExists(local.debugLogFile)) {
					print.boldGreenLine("Debug information logged to: #local.debugLogFile#");
				} else {
					print.boldRedLine("Expected debug information to be logged to: #local.debugLogFile# but the file does not exist.");
				}
			}

			if (arguments.failOnIssues) {
				setExitCode( 1 );	
			}
			
		}

		if (fixinatorClient.hasClientUpdate()) {
			print.line();
			print.boldGreenLine("Yay! There is a fixinator client update! Please run the following command to get the latest version:");
			print.boldGreenLine("    box install fixinator");
		}



	}

	function resultFormatComplete() {
		return [ 'html', 'json', 'pdf', 'junit', 'findbugs', 'sast', 'csv' ];
	}

	function confidenceComplete() {
		return [ 'low', 'medium', 'high', 'none' ];
	}

	function severityComplete() {
		return [ 'low', 'medium', 'high', 'warn' ];
	}


	private boolean function isRunningInCI() {
		var env = server.system.environment;
		if (env.keyExists("CI") && isBoolean(env.CI) && env.CI) {
			return true;
		}
		if (env.keyExists("CONTINUOUS_INTEGRATION") && isBoolean(env.CONTINUOUS_INTEGRATION) && env.CONTINUOUS_INTEGRATION) {
			return true;
		}
		if ( isTFS() || isCodeBuild() || isJenkins() || isTravisCI() || isCircleCI() || isBitbucketPipeline() ) {
			return true;
		}
		
		return false;
	}

	private boolean function isTravisCI() {
		return server.system.environment.keyExists("TRAVIS") && server.system.environment.TRAVIS;
	}

	private boolean function isCircleCI() {
		return server.system.environment.keyExists("CIRCLECI") && server.system.environment.CIRCLECI;
	}

	private boolean function isBitbucketPipeline() {
		return server.system.environment.keyExists("BITBUCKET_BUILD_NUMBER");
	}

	private boolean function isTFS() {
		var env = server.system.environment;
		return env.keyExists("TF_BUILD") && isBoolean(env.TF_BUILD) && env.TF_BUILD;
	}

	private boolean function isCodeBuild() {
		var env = server.system.environment;
		return (env.keyExists("CODEBUILD_BUILD_ID") && len(env.CODEBUILD_BUILD_ID));
	}

	private boolean function isJenkins() {
		var env = server.system.environment;
		return env.keyExists("BUILD_NUMBER") && len(env.BUILD_NUMBER) && env.keyExists("JENKINS_HOME") && len(env.JENKINS_HOME);
	}

	private function getGitChanges(path, lastCommit=true) {
		var gitDir = path & ".git/";
		var gitDirFileObject = createObject("java", "java.io.File").init(gitDir);
		var gitRepo = "";
		var reader = "";
		var results = [];
		var result = "";
		var disIO = createObject("java", "org.eclipse.jgit.util.io.DisabledOutputStream").INSTANCE;
		if (!gitDirFileObject.exists()) {
			throw(message="The path: #path# is not a git repository root path");
		}
		gitRepo = createObject("java", "org.eclipse.jgit.storage.file.FileRepositoryBuilder").create(gitDirFileObject);

		reader = gitRepo.newObjectReader();

		if (lastCommit) {
			oldTreeIter = createObject("java", "org.eclipse.jgit.treewalk.CanonicalTreeParser");
			oldTree = gitRepo.resolve( "HEAD~1^{tree}" );
			oldTreeIter.reset( reader, oldTree );
			newTreeIter = createObject("java", "org.eclipse.jgit.treewalk.CanonicalTreeParser");
			
			newTree = gitRepo.resolve( "HEAD^{tree}" );
			newTreeIter.reset( reader, newTree );
		} else {
			oldTreeIter = createObject("java", "org.eclipse.jgit.treewalk.CanonicalTreeParser");
			oldTree = gitRepo.resolve( "HEAD^{tree}" );
			oldTreeIter.reset( reader, oldTree );
			
			newTreeIter = createObject("java", "org.eclipse.jgit.treewalk.FileTreeIterator").init(gitRepo);
		}
		

		diffFormatter = createObject("java", "org.eclipse.jgit.diff.DiffFormatter").init( disIO );
		diffFormatter.setRepository( gitRepo );
		entries = diffFormatter.scan( oldTreeIter, newTreeIter );

		for( entry in entries.toArray() ) {
			result = {"type": entry.getChangeType().toString(), "path": "", "previousPath":""}
			if (!isNull(entry.getNewPath())) {
				result.path = entry.getNewPath().toString();
			}
			if (!isNull(entry.getOldPath())) {
				result.previousPath = entry.getOldPath().toString();
			}
			arrayAppend(results, result);
		}
		return results;
	}

}