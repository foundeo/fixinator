component singleton="true" {

	variables.maxPayloadSize = 1 * 640 * 1024;//half mb+128b
	variables.maxPayloadFileCount = 25;
	variables.apiURL = "https://api.fixinator.app/v1/scan";
	variables.system = createObject("java", "java.lang.System");
	if (!isNull(variables.system.getenv("FIXINATOR_API_URL"))) {
		variables.apiURL = variables.system.getenv("FIXINATOR_API_URL");
	}

	variables.clientUpdate = false;
	
	public function getClientVersion() {
		if (!structKeyExists(variables, "clientVersion")) {
			//pull version number from box.json
			local.path = getCurrentTemplatePath();
			local.path = replace(local.path, "\", "/", "ALL");
			local.path = replace(local.path, "/models/fixinator/FixinatorClient.cfc", "/box.json");
			local.data = deserializeJSON(fileRead(local.path));
			variables.clientVersion = local.data.version;
		}
		return variables.clientVersion;	
		
	}

	public function run(string path, struct config={}, any progressBar="", any job="") {
		var files = "";
		var payload = {"config"=getDefaultConfig(), "files"=[]};
		var results = {"warnings":[], "results":[], "payloads":[]};
		var size = 0;
		var pathData = getFileInfo(arguments.path);
		var fileCounter = 0;
		var percentValue = 0;
		var hasProgressBar = isObject(arguments.progressBar);
		var hasJob = isObject(arguments.job);
		var baseDir = getDirectoryFromPath(arguments.path);
		if (fileExists(baseDir & ".fixinator.json")) {
			local.fileConfig = fileRead(getDirectoryFromPath(arguments.path) & ".fixinator.json");
			if (isJSON(local.fileConfig)) {
				local.fileConfig = deserializeJSON(local.fileConfig);
				structAppend(payload.config, local.fileConfig, true);
			} else {
				throw(message="Invalid .fixinator.json config file, was not valid JSON");
			}
		}

		structAppend(payload.config, arguments.config, true);
		arguments.config = payload.config;
		if (pathData.type == "file") {
			files = [arguments.path];
		} else {
			if (isFreeAPIKey()) {
				throw(message="Sorry you can only scan one file at a time using a Free API key. With a purchased key you can scan directories. Visit https://fixinator.app to purchase.", type="FixinatorClient");
			}
			files = directoryList(arguments.path, true, "path");
			files = filterPaths(arguments.path, files, payload.config);	
		}
		for (local.f in files) {
			fileCounter++;
			if (fileExists(local.f)) {
				local.fileInfo = getFileInfo(local.f);
				if (local.fileInfo.canRead && local.fileInfo.type == "file") {
					local.ext = listLast(local.f, ".");
					if (local.fileInfo.size > variables.maxPayloadSize && local.ext != "jar") {
						results.warnings.append( { "message":"File was too large, #local.fileInfo.size# bytes, max: #variables.maxPayloadSize#", "path":local.f } );
						continue;
					} else {
						
						if (size + local.fileInfo.size > variables.maxPayloadSize || arrayLen(payload.files) > variables.maxPayloadFileCount) {
							if (hasJob) {
								job.start( ' Scanning Payload (#arrayLen(payload.files)# of #arrayLen(files)# files) this may take a sec...' );
								if (hasProgressBar) {
									progressBar.update( percent=percentValue, currentCount=fileCounter, totalCount=arrayLen(files) );	
								}
								local.msStart = getTickCount();
							}
							local.result = sendPayload(payload);
							if (hasJob) {
								job.addSuccessLog( ' Scan Payload Complete, took #getTickCount()-local.msStart#ms ' );
								job.complete(dumpLog=false);

							}
							arrayAppend(results.results, local.result.results, true);
							payload.result = local.result;
							//arrayAppend(results.payloads, payload);
							size = 0;
							payload = {"config"=arguments.config, "files"=[]};
						} else {
							size+= local.fileInfo.size;
							payload.files.append({"path":replace(local.f, baseDir, ""), "data":(local.ext == "jar") ? "" : fileRead(local.f), "sha1":fileSha1(local.f)});
						}
					}
				} else {
					results.warnings.append( { "message":"Missing Read Permission", "path":local.f } );
				}
				percentValue = int( (fileCounter/arrayLen(files)) * 90);
				if (percentValue >= 100) {
					percentValue = 90;
				}
				if (hasProgressBar) {
					progressBar.update( percent=percentValue, currentCount=fileCounter, totalCount=arrayLen(files) );	
				}
			}
		}
		if (arrayLen(payload.files)) {
			if (hasJob) {
				job.start( ' Scanning Payload (#arrayLen(payload.files)# of #arrayLen(files)# files) this may take a sec...' );
				local.msStart = getTickCount();
			}
			local.result = sendPayload(payload);
			if (hasJob) {
				job.addSuccessLog ( ' Scan Payload Complete, took #getTickCount()-local.msStart#ms ' );
				job.complete(dumpLog=false);
			}
			payload.result = local.result;
			//arrayAppend(results.payloads, payload);
			arrayAppend(results.results, local.result.results, true);
		}
		structDelete(results, "payloads");
		if (hasProgressBar) {
			progressBar.update( percent=100, currentCount=arrayLen(files), totalCount=arrayLen(files) );	
		}
		results["config"] = payload.config;
		return results;
	}

	public function sendPayload(payload, isRetry=0) {
		var httpResult = "";
		cfhttp(url=variables.apiURL, method="POST", result="httpResult") {
			cfhttpparam(type="header", name="Content-Type", value="application/json");
			cfhttpparam(type="header", name="x-api-key", value=getAPIKey());
			cfhttpparam(type="header", name="X-Client-Version", value=getClientVersion());
			cfhttpparam(value="#serializeJSON(payload)#", type="body");
		}
		if (httpResult.statusCode contains "403") {
			//FORBIDDEN -- API KEY ISSUE
			if (getAPIKey() == "UNDEFINED") {
				throw(message="Fixinator API Key must be defined in an environment variable called FIXINATOR_API_KEY", detail="If you have already set the environment variable you may need to reopen your terminal or command prompt window. Please visit https://fixinator.app/ for more information", type="FixinatorClient");
			} else {
				throw(message="Fixinator API Key (#getAPIKey()#) is invalid, disabled or over the API request limit. Please contact Foundeo Inc. for assistance. Please provide your API key in correspondance. https://foundeo.com/contact/ ", detail="#httpResult.statusCode# #httpResult.fileContent#", type="FixinatorClient");
			}
		} else if (httpResult.statusCode contains "429") { 
			//TOO MANY REQUESTS
			if (arguments.isRetry == 1) {
				throw(message="Fixinator API Returned 429 Status Code (Too Many Requests). This is usually due to an exceded monthly quote limit. You can either purchase a bigger plan or request a one time limit increase.", type="FixinatorClient");
			} else {
				//retry it once
				sleep(500);
				return sendPayload(payload=arguments.payload, isRetry=1);
			}
		} else if (httpResult.statusCode contains "502") { 
			//BAD GATEWAY - lambda timeout issue
			if (arguments.isRetry >= 2) {
				throw(message="Fixinator API Returned 502 Status Code (Bad Gateway). Please try again shortly or contact Foundeo Inc. if the problem persists.", type="FixinatorClient");
			} else {
				//retry it
				sleep(500);
				return sendPayload(payload=arguments.payload, isRetry=arguments.isRetry+1);
			}
		}
		if (!isJSON(httpResult.fileContent)) {
			throw(message="API Result was not valid JSON", detail=httpResult.fileContent);
		}
		if (httpResult.statusCode does not contain "200") {
			throw(message="API Returned non 200 Status Code (#httpResult.statusCode#)", detail=httpResult.fileContent, type="FixinatorClient");
		}
		if (structKeyExists(httpResult.responseHeader, "X-Client-Update")) {
			variables.clientUpdate = true;
		}

		return deserializeJSON(httpResult.fileContent);
	}

	public function getAPIKey() {
		if (structKeyExistS(variables, "fixinatorAPIKey")) {
			return variables.fixinatorAPIKey;
		} else if (!isNull(variables.system.getenv("FIXINATOR_API_KEY"))) {
			return variables.system.getenv("FIXINATOR_API_KEY");
		} else {
			return "UNDEFINED";
		}
	}

	public boolean function isFreeAPIKey() {
		return left(getAPIKey(), 2) == "fr";
	}

	public function setAPIKey(string key) {
		variables.fixinatorAPIKey = arguments.key;
	}

	public function filterPaths(baseDirectory, paths, config) {
		var f = "";
		var ignoredPaths = ["/.git/","\.git\","/.svn/","\.svn\", ".git/"];
		var ignoredExtensions = ["jpg","png","txt","pdf","doc","docx","gif","css","zip","bak","exe","pack","log","csv","xsl","xslx","psd","ai"];
		var filteredPaths = [];
		//always ignore git paths
		if (arguments.config.keyExists("ignoredPaths") && arrayLen(arguments.config.ignoredPaths)) {
			arrayAppend(ignoredPaths, arguments.config.ignoredPaths, true);
		}
		//always ignore certain extensions
		if (arguments.config.keyExists("ignoredExtensions") && arrayLen(arguments.config.ignoredExtensions)) {
			arrayAppend(ignoredExtensions, arguments.config.ignoredExtensions, true);
		}
		for (f in paths) {
			if (directoryExists(f)) {
				continue;
			}
			local.p = replace(f, arguments.baseDirectory, "");
			local.skip = false;
			local.fileName = getFileFromPath(f);
			local.ext = listLast(local.fileName, ".");

			if (arrayFindNoCase(ignoredExtensions, local.ext)) {
				continue;
			}

			for (local.ignore in ignoredPaths) {
				if (find(local.ignore, local.p) != 0) {
					local.skip = true;
					continue;
				}
			}

			if (!local.skip) {
				arrayAppend(filteredPaths, f);
			}
		}
		return filteredPaths;
	}

	public function fixCode(basePath, fixes) {
		var fix = "";
		var basePathInfo = getFileInfo(arguments.basePath);
		//sort issues by file then line number
		arraySort(
  		  arguments.fixes,
    		function (e1, e2){
    			if (e1.issue.path == e2.issue.path) {
    				return e1.issue.line < e2.issue.line;
    			} else {
    				return compare(e1.issue.path, e2.issue.path);	
    			}
        		
    		}
		);
		local.lastFile = "";
		local.filePositionOffset = 0;
		for (fix in arguments.fixes) {
			if (basePathInfo.type == "file") {
				local.filePath = arguments.basePath;
			} else {
				local.filePath = arguments.basePath & fix.issue.path;
			}


			if (!fileExists(local.filePath)) {
				throw(message="Unable to autofix, file: #local.filePath# does not exist");
			}

			if (local.lastFile != local.filePath) {
				local.lastFile = local.filePath;
				local.filePositionOffset = 0;
				local.fileContent = fileRead(local.filePath);
			}

			/*
				 fix.fix = {
					fixCode=codeToReplaceWith
					replacePosition=posInFile, 
					replaceString="fix"}
			*/
			
			local.fixStartPos = local.filePositionOffset + fix.fix.replacePosition;
			local.fileSnip = mid(local.fileContent, local.fixStartPos, len(fix.fix.replaceString));
			if (local.fileSnip != fix.fix.replaceString) {
				throw(message="Snip does not match: #local.fileSnip# expected: #fix.fix.replaceString# #serializeJSON(local)# FPO:#local.filePositionOffset# FSP:#local.fixStartPos#  #local.fileContent# ");
			} else {
				local.prefix = mid(local.fileContent, 1, local.fixStartPos-1);
				local.suffix = mid(local.fileContent, local.fixStartPos + len(local.fix.fix.replaceString), len(fileContent)- local.fixStartPos + len(local.fix.fix.replaceString));
				local.fileContent = local.prefix & local.fix.fix.fixCode & local.suffix;

				local.filePositionOffset = ( len(fix.fix.fixCode) - len(fix.fix.replaceString) );

				//throw(message="FPO:#local.filePositionOffset# FileContent:#local.fileContent#");

				if (fix.fix.replaceString contains chr(13)) {
					throw(message="rs contains char(13)");
				}
				if (fix.fix.replaceString contains chr(10)) {
					throw(message="rs contains char(13)");
				}

				fileWrite(local.filePath, local.fileContent);

			}

			

		}
	}

	public function hasClientUpdate() {
		return variables.clientUpdate;
	}


	public struct function getDefaultConfig() {
		return {
			"ignoredPaths":[],
			"ignoredExtensions":[],
			"ignoreScanners":[],
			"minSeverity": "low",
			"minConfidence": "high"
		};
	}

	public string function fileSha1(path) {
		var fIn = createObject("java", "java.io.FileInputStream").init(path);
		return createObject("java", "org.apache.commons.codec.digest.DigestUtils").sha1Hex(fIn);
	}




}