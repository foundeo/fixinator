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
	function run( string path=".", string resultFile, string resultFormat="json", boolean verbose=true, string listBy="type", string severity="default", string confidence="default", string ignoreScanners="", autofix="off")  {
		var fileInfo = "";
		var severityLevel = 1;
		var confLevel = 1;
		var config = {};
		var toFix = [];
		if (arguments.verbose) {
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

		if (configService.getSetting("modules.fixinator.accept_policy", "UNDEFINED") == "UNDEFINED") {
			print.line();
			print.line("Fixinator will send source code to: " & fixinatorClient.getAPIURL());
			print.line("for scanning. The code is kept in RAM during scanning and is not persisted.");
			print.line();
			print.line("Note: The enterprise version allows you to run the code scanner on your own servers.");
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


		
		arguments.path = fileSystemUtil.resolvePath( arguments.path );



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


		if (!fileExists(arguments.path) && !directoryExists(arguments.path)) {
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
				job.start("Scanning " & arguments.path);
				progressBar.update( percent=0 );
				local.results = fixinatorClient.run(path=arguments.path,config=config, progressBar=progressBar);	
				progressBar.clear();
			} else {
				//no progress bar or interactive job output
				local.results = fixinatorClient.run(path=arguments.path,config=config);	
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
				return;
			} else {
				rethrow;
			}
		} finally {
			if (arguments.verbose) {
				progressBar.clear();
				job.complete();	
			}
		}
		


		if (arrayLen(local.results.results) == 0 && arrayLen(local.results.warnings) == 0)   {
			print.boldGreenLine("0 Issues Found");
			if (arguments.verbose) {
				if (local.results.config.minSeverity != "low" || local.results.config.minConfidence != "low") {
					print.line().greenLine("Tip: For additional results try decreasing the severity or confidence level to medium or low");
					print.greenLine("    Currently: severity=#local.results.config.minSeverity# confidence=#local.results.config.minConfidence# ")	
				}
				
			}
		} else {
			print.boldRedLine("FINDINGS: " & arrayLen(local.results.results));

			if (len(arguments.resultFile)) {
				arguments.resultFile = fileSystemUtil.resolvePath( arguments.resultFile );
				fixinatorReport.generateReport(resultFile=arguments.resultFile, format=arguments.resultFormat, listBy=arguments.listBy, data=local.results);
			}

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

				print.boldYellowLine(local.typeKey);
				for (local.i in local.resultsByType[local.typeKey]) {
					if (arguments.listBy == "type") {
						local.line = "#local.i.path#:#local.i.line#";
						
					} else {
						local.line = "[#local.i.id#] on line #local.i.line#";
					}
					if (local.i.severity == 3) {
						print.redLine("#chr(9)##local.line#");
					} else if (local.i.severity == 2) {
						print.magentaLine("#chr(9)##local.line#");
					} else if (local.i.severity == 1) {
						print.aquaLine("#chr(9)##local.line#");
					} else {
						print.yellowLine("#chr(9)##local.line#");
					}
					
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
							print.redLine("#chr(9)#[HIGH] #local.i.message##local.conf#");
						} else if (local.i.severity == 2) {
							print.magentaLine("#chr(9)#[MEDIUM] #local.i.message##local.conf#");
						} else if (local.i.severity == 1) {
							print.aquaLine("#chr(9)#[LOW] #local.i.message##local.conf#");
						} else {
							print.yellowLine("#chr(9)#[WARN] #local.i.message##local.conf#");
						}
						if (local.i.keyExists("description") && len(local.i.description)) {
							print.line(chr(9) & local.i.description);
						}
						if (len(local.i.context)) {
							print.greyLine("#chr(9)##local.i.context#");
						}
						if (local.i.keyExists("link") && len(local.i.link)) {
							print.greyLine(chr(9) & local.i.link);
						}
						if (local.i.keyExists("fixes") && arrayLen(local.i.fixes) > 0) {
							print.greyLine("#chr(9)#Possible Fixes:");
							local.fixIndex = 0;
							local.fixOptions = "";
							for (local.fix in local.i.fixes) {
								local.fixIndex++;
								local.fixOptions = listAppend(local.fixOptions, local.fixIndex);
								print.greyLine(chr(9)&chr(9)&local.fixIndex&": "&local.fix.title & ": " & local.fix.fixCode);
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
    							local.fix = ask(message="Do you want to fix this? Enter [#local.fixOptions#] or no: ");


								if (isNumeric(local.fix) && local.fix >= 1 && local.fix <= arrayLen(local.i.fixes)) {
									toFix.append({"fix":local.i.fixes[local.fix], "issue":local.i});
								} 

							}
						}
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
					print.grayLine(serializeJSON(local.w));
				}
			}

			if (arrayLen(toFix) > 0) {
				print.line();
				local.msg = "FIXING #arrayLen(toFix)# issue" & ((arrayLen(toFix)>0) ? "s" :"");
				print.boldOrangeLine(local.msg);
				local.fixResults = fixinatorClient.fixCode(basePath=arguments.path, fixes=toFix);

			}



			setExitCode( 1 );
		}

		if (fixinatorClient.hasClientUpdate()) {
			print.line();
			print.boldGreenLine("Yay! There is a fixinator client update! Please run the following command to update your client:");
			print.boldGreenLine("    box update fixinator");
		}



	}

	private boolean function isRunningInCI() {
		var env = server.system.environment;
		if (env.keyExists("CI") && isBoolean(env.CI) && env.CI) {
			return true;
		}
		if (env.keyExists("CONTINUOUS_INTEGRATION") && isBoolean(env.CONTINUOUS_INTEGRATION) && env.CONTINUOUS_INTEGRATION) {
			return true;
		}

		return false;
	}

}