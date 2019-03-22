component singleton="true" {

	variables.maxPayloadSize = 1 * 640 * 1024;//half mb+128b
	variables.maxPayloadFileCount = 35;
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

	public function run(string path, struct config={}, any progressBar="") {
		var files = "";
		var payload = {"config"=getDefaultConfig(), "files"=[]};
		var results = {"warnings":[], "results":[], "payloads":[]};
		var size = 0;
		var pathData = getFileInfo(arguments.path);
		var fileCounter = 0;
		var percentValue = 0;
		var hasProgressBar = isObject(arguments.progressBar);
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
		local.filesPerBatch = arrayLen(files);
		local.numberOfBatches = 1;

		if (arrayLen(files) > (variables.maxPayloadFileCount * 20 )) {
			local.numberOfBatches = 4;
		} else if (arrayLen(files) > (variables.maxPayloadFileCount * 10)) {
			local.numberOfBatches = 3;
		} else if (arrayLen(files) > (variables.maxPayloadFileCount * 3)) {
			local.numberOfBatches = 2;
		}
		local.filesPerBatch = (arrayLen(files) / local.numberOfBatches) + 1;
		local.lock_name = createUUID();

		if (!variables.keyExists("fixinator_shared")) {
			variables.fixinator_shared = {};
		}
		variables.fixinator_shared[local.lock_name] = {fileCounter=0, pendingCounter=0, totalFileCount=arrayLen(files), lastPercentValue=0, error=0};
		local.batches = [{batchType:"progressBar", hasProgressBar:hasProgressBar, progressBar:progressBar, lock_name=local.lock_name}];
		
		local.batch = {files:[], batchType:"files", lock_name:local.lock_name, baseDir:baseDir, config:payload.config};
		
		for (local.f in files) {
			arrayAppend(local.batch.files, local.f);
			if (arrayLen(local.batch.files) >= local.filesPerBatch) {
				arrayAppend(local.batches, local.batch);
				local.batch = {files:[], batchType:"files", lock_name:local.lock_name, baseDir:baseDir, config:payload.config};
			}
		}

		if (arrayLen(local.batch.files)) {
			arrayAppend(local.batches, local.batch);
		}
		
		arrayEach(local.batches, processBatch, true, arrayLen(local.batches));
		for (local.batch in local.batches) {
			if (local.batch.keyExists("error")) {
				if (local.batch.error.keyExists("message")) {
					local.detail = "";
					if (local.batch.error.keyExists("detail")) {
						local.detail = local.batch.error.detail;
					}
					throw(message=local.batch.error.message, type="FixinatorClient", detail=local.detail);	
				}
				
			}
			if (local.batch.batchType == "files" && local.batch.keyExists("results")) {
			 	if(local.batch.results.keyExists("results")) {
					if (arrayLen(local.batch.results.results) > 0) {
						arrayAppend(results.results, local.batch.results.results, true);
					}
				}
				if (local.batch.results.keyExists("warnings")) {
					if (arrayLen(local.batch.results.warnings) > 0) {
						arrayAppend(results.warnings, local.batch.results.warnings, true);
					}
				}
			}
		}

		

		
		structDelete(results, "payloads");
		if (hasProgressBar) {
			progressBar.update( percent=100, currentCount=arrayLen(files), totalCount=arrayLen(files) );	
		}
		results["config"] = payload.config;
		return results;
	}

	public function getAPIURL() {
		return variables.apiURL;
	}

	private function processBatch(element, index) {
		
		if (element.batchType == "progressBar") {
			//progress bar worker
			for (local.i=0;i<1000;i++) {
				updateProgressBar(element);
				cflock(name=element.lock_name, type="readonly", timeout="30") {
					if (variables.fixinator_shared[element.lock_name].error != 0) {
						//thread errored out
						return;
					}
					if (variables.fixinator_shared[element.lock_name].fileCounter == variables.fixinator_shared[element.lock_name].totalFileCount) {
						if (variables.fixinator_shared[element.lock_name].pendingCounter == 0) {
							//done
							return;
						}
					}
				}
				sleep(200);
			}
		} else {
			try {


				element.results = {"warnings":[], "results":[], "payloads":[]};
				local.size = 0;
				local.payload = {"config"=element.config, "files"=[]};

				for (local.f in element.files) {
					cflock(name=element.lock_name, type="exclusive", timeout="30") {
						variables.fixinator_shared[element.lock_name].fileCounter++;	
						if (variables.fixinator_shared[element.lock_name].error != 0) {
							//another thread errored out so quit
							return;
						}
					}
					if (fileExists(local.f)) {
						local.fileInfo = getFileInfo(local.f);
						if (local.fileInfo.canRead && local.fileInfo.type == "file") {
							local.ext = listLast(local.f, ".");
							if (local.fileInfo.size > variables.maxPayloadSize && local.ext != "jar") {
								element.results.warnings.append( { "message":"File was too large, #local.fileInfo.size# bytes, max: #variables.maxPayloadSize#", "path":local.f } );
								continue;
							} else {
								
								if (local.size + local.fileInfo.size > variables.maxPayloadSize || arrayLen(payload.files) > variables.maxPayloadFileCount) {
									cflock(name=element.lock_name, type="exclusive", timeout="30") {
										variables.fixinator_shared[element.lock_name].pendingCounter+=arrayLen(payload.files);	
									}
									local.result = sendPayload(payload);
									cflock(name=element.lock_name, type="exclusive", timeout="30") {
										variables.fixinator_shared[element.lock_name].pendingCounter-=arrayLen(payload.files);	
									}
									arrayAppend(element.results.results, local.result.results, true);
									payload.result = local.result;
									//arrayAppend(results.payloads, payload);
									local.size = 0;
									payload = {"config"=element.config, "files"=[]};
								} else {
									local.size+= local.fileInfo.size;
									payload.files.append({"path":replace(local.f, element.baseDir, ""), "data":(local.ext == "jar") ? "" : fileRead(local.f), "sha1":fileSha1(local.f)});
								}
							}
						} else {
							element.results.warnings.append( { "message":"Missing Read Permission", "path":local.f } );
						}
						
					}
				}
				if (arrayLen(payload.files)) {
					cflock(name=element.lock_name, type="exclusive", timeout="30") {
						variables.fixinator_shared[element.lock_name].pendingCounter+=arrayLen(payload.files);	
					}
					local.result = sendPayload(payload);
					cflock(name=element.lock_name, type="exclusive", timeout="30") {
						variables.fixinator_shared[element.lock_name].pendingCounter-=arrayLen(payload.files);	
					}
					payload.result = local.result;
					//arrayAppend(results.payloads, payload);
					arrayAppend(element.results.results, local.result.results, true);
				}

			} catch (any e) {
				element.error = e;
				cflock(name=element.lock_name, type="exclusive", timeout="30") {
					variables.fixinator_shared[element.lock_name].error+=1;
				}
			}
		}
	}

	private function updateProgressBar(element) {
		if (arguments.element.hasProgressBar) {
			local.lastPercentValue = 0;
			local.fileCounter = 0;
			local.pendingCounter = 0;
			local.totalFileCount = 0;
			cflock(name=element.lock_name, type="readonly", timeout="30") {
				local.lastPercentValue = variables.fixinator_shared[element.lock_name].lastPercentValue;
				local.fileCounter = variables.fixinator_shared[element.lock_name].fileCounter;
				local.pendingCounter = variables.fixinator_shared[element.lock_name].pendingCounter;
				local.totalFileCount = variables.fixinator_shared[element.lock_name].totalFileCount;
			}
			
			local.progress = fileCounter;
			local.progress -= (pendingCounter/2);
			local.percentValue = int( (local.progress/totalFileCount) * 100);
			local.upperBound = int( (fileCounter/totalFileCount) * 100 ) - 1;
			if (pendingCounter > 0) {
				if (local.percentValue <= local.upperBound && local.lastPercentValue <= local.upperBound) {
					//increment counter while waiting for HTTP response
					if (local.lastPercentValue >= local.percentValue) {
						local.percentValue = local.lastPercentValue+1;
					}
				}
			}
			
			if (local.lastPercentValue != local.percentValue) {
				cflock(name=element.lock_name, type="exclusive", timeout="30") {
					variables.fixinator_shared[element.lock_name].lastPercentValue = local.percentValue;
				}
			}
			element.progressBar.update( percent=local.percentValue, currentCount=fileCounter, totalCount=totalFileCount);	

		}
	}

	public function sendPayload(payload, isRetry=0) {
		var httpResult = "";
		cfhttp(url=getAPIURL(), method="POST", result="httpResult", timeout="35") {
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
		} else if (httpResult.statusCode contains "502" || httpResult.statusCode contains "504") { 
			//502 BAD GATEWAY or 504 Gateway Timeout - lambda timeout issue
			if (arguments.isRetry >= 2) {
				throw(message="Fixinator API Returned #httpResult.statusCode# Status Code. Please try again shortly or contact Foundeo Inc. if the problem persists.", type="FixinatorClient");
			} else {
				//retry it
				sleep(500);
				return sendPayload(payload=arguments.payload, isRetry=arguments.isRetry+1);
			}
		} else if (httpResult.statusCode contains "Connection Failure") {
			throw(message="Connection Failure", detail="Unable to connect to #getAPIURL()# please check your firewall settings and internet connection.");
		}
		if (httpResult.statusCode does not contain "200") {
			throw(message="API Returned non 200 Status Code (#httpResult.statusCode#)", detail=httpResult.fileContent, type="FixinatorClient");
		}
		if (!isJSON(httpResult.fileContent)) {
			throw(message="API Result was not valid JSON (#httpResult.statusCode#)", detail=httpResult.fileContent);
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
		if (arguments.config.keyExists("ignorePaths") && arrayLen(arguments.config.ignorePaths)) {
			arrayAppend(ignoredPaths, arguments.config.ignorePaths, true);
		}
		//always ignore certain extensions
		if (arguments.config.keyExists("ignoreExtensions") && arrayLen(arguments.config.ignoreExtensions)) {
			arrayAppend(ignoredExtensions, arguments.config.ignoreExtensions, true);
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
				throw(message="Snip does not match: |#local.fileSnip#| expected: |#fix.fix.replaceString#| FPO:#local.filePositionOffset# FSP:#local.fixStartPos#  #local.fileContent# ");
			} else {
				local.prefix = mid(local.fileContent, 1, local.fixStartPos-1);
				local.suffix = mid(local.fileContent, local.fixStartPos + len(local.fix.fix.replaceString), len(fileContent)- local.fixStartPos + len(local.fix.fix.replaceString));
				local.fileContent = local.prefix & local.fix.fix.fixCode & local.suffix;

				local.filePositionOffset += ( len(fix.fix.fixCode) - len(fix.fix.replaceString) );

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
			"ignorePaths":[],
			"ignoreExtensions":[],
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