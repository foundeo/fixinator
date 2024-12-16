# fixinator-client

[![Demo](https://foundeo.com/images/fixinator-demo.gif)](https://fixinator.app)

## Installing Fixinator

If you are familiar with CommandBox simply run the command:

	box install fixinator

Check out the [Getting Started Guide](https://github.com/foundeo/fixinator/wiki/Getting-Started) or the [Wiki](https://github.com/foundeo/fixinator/wiki) for more info.

## Command Line Arguments

When running the `fixinator` command via the command line you can set the following arguments:

### path

The folder or file to scan. As of version 2.0 you can also pass a [file globber](https://commandbox.ortusbooks.com/usage/parameters/globbing-patterns) pattern, eg: `path=c:\code\**.cfc`

### confidence

Default: `high` 

Possible values are `none`, `low`, `medium` or `high`. This setting is used to filter out results that the scanner is not confident about. Setting it to a lower value will show more issues but may have some false positives.

### severity

Default: `low`

Possible values are: `low`, `medium` or `high`. Filter by severity of the issues found.

### autofix

Default: `off`

* `off` - does not fix code
* `prompt` - prompts at each issue that can be fixed, if you select a fix the file will be updated with the fix code
* `auto` - does not prompt, it will fix each issue with the first choice

It is highly recommended that you use `autofix` only with code that is under version control so you can review the diff.

### resultFile

Writes results to a file specified by the path in resultFile. You may specify a comma separated list of paths if you want to write multiple formats.

### resultFormat

Specify a format for the `resultFile`:  `json` (default), `html`, `pdf`, `csv`, `junit`, `sast`, or `findbugs`. You may specify a comma separated list of formats and `resultFile` paths if you want to write multiple files.

### ignorePaths

A file globber pattern of paths to ignore from the scan.

### failOnIssues

Default: `true` - When true returns an exit code of `1` when issues are found, this will cause your build to fail if you are running in CI. If you do not want the build to fail when issues are found, set this to `false`.

### listScanners

Default: `false` - Prints out a list of scanners supported by the server in the results. Automatically set to `true` when `verbose` is `true`

### gitLastCommit

Default: `false` - When `true` scans only files changed in the HEAD git commit, this is useful in CI to scan only the files changed in a specific commit. 

### gitWorkingCopy

Default: `false` - When `true` scans only the files changed in the working copy (compared to the HEAD git commit). This is useful to scan only the files you have modified since your last git commit. 

### engines

Default: `lucee,adobe` - A comma separated list of CFML engines that your code will run on. This setting is useful to exclude issues specific to Lucee, or Adobe ColdFusion if you only use one or the other. You can pass the list using version numbers as well, for example: `engines=adobe@2021,adobe@2023` or `engines=lucee@6,adobe@2023` - it follows the same syntax used by the commandbox server command's `cfengine` argument. 

Added in Fixinator version 4.

### includeScanners

Default: _Empty_ - A comma separated list of scanners ids to scan (use `--listScanners` to see the options). For example if you only want to scan for SQL Injection, you can use: `includeScanners=sqlinjection` and you will only see SQL Injection Results.

Added in Fixinator version 4.

### configFile

The path to a `.fixinator.json` configuration file to use. See below for details on the file contents. The command line argument overrides the default search path (looking in the base directory).

### goals

Default: `security` - a comma separated list of goals for the scan. Possible values are `security` and `compatibility` 

When the `compatibility` goal is passed it will return compatibility issues found in the code for the `engines` specified. Typically when you use the `compatibility` mode you will specify the `engines` argument as well. Example

	fixinator path=c:\mycode\ goals=security,compatibility engines=adobe@2023

Added in Fixinator Version 5.

## Environment Variables

The following environment variables are used by fixinator:

### FIXINATOR_API_KEY

The `FIXINATOR_API_KEY` environment variable holds an API key which will be passed to the Fixinator API service via the `x-api-key` HTTP request header. Please visit <https://fixinator.app/> to obtain a key.

You can also set this value by running:

	box config set modules.fixinator.api_key=YOUR_API_KEY

### FIXINATOR_API_URL `ENTERPRISE EDITION`

The `FIXINATOR_API_URL` environment variable points to the URL of the Fixinator API service. If you are running fixinator locally you will want to point this to your local API instance (enterprise edition). If you are using the public API then you do not need to set this variable.

You can also set this value by running:

	box config set modules.fixinator.api_url=http://127.0.0.1:1234/scan/


### FIXINATOR_MAX_PAYLOAD_SIZE `ENTERPRISE EDITION`

The `FIXINATOR_MAX_PAYLOAD_SIZE` environment variables controls the size of a payload that is sent to the fixinator api server at a time, as well as the max file size. The unit for this setting is bytes.

You can also set this value by running:

	box config set modules.fixinator.max_payload_size=numberOfBytes

This variable should only be used with the enterprise edition otherwise you may run into issues.

### FIXINATOR_MAX_PAYLOAD_FILE_COUNT `ENTERPRISE EDITION`

The `FIXINATOR_MAX_PAYLOAD_FILE_COUNT` environment variables controls the maximum number of files sent the fixinator api server at a time.

You can also set this value by running:

	box config set modules.fixinator.max_payload_file_count=numberOfFiles

This variable should only be used with the enterprise edition otherwise you may run into issues.

### FIXINATOR_API_TIMEOUT `ENTERPRISE EDITION`

The `FIXINATOR_API_TIMEOUT` environment variables specifies the http timeout for connecting to the
fixinator api server.

You can also set this value by running:

	box config set modules.fixinator.api_timeout=35

This variable should only be used with the enterprise edition.

### FIXINATOR_MAX_CONCURRENCY `ENTERPRISE EDITION`

The `FIXINATOR_MAX_CONCURRENCY` environment variable specifies the maximum number of 
threads to use

You can also set this value by running:

	box config set modules.fixinator.max_concurrency=8

The default value is `8`

## .fixinator.json

A `.fixinator.json` configuration file can be placed in the root of a folder to be scanned. For Example:

	{
		"ignorePaths":["some/folder-to-ignore", "some/file-to-ignore.cfm"],
		"ignoreExtensions":["ign","ore"],
		"ignoreScanners":["xss"],
		"minSeverity": "low",
		"minConfidence": "low",
		"ignorePatterns": {},
		"engines": ["lucee","adobe"],
		"includeScanners":[]
	}

Note that `.fixinator.json` files placed in a subfolder of the base scan path are currently ignored.

As of Fixinator version 4 you can now specify the `configFile=/path/to/.fixinator.json` to override the default path.

### ignorePaths

An array of path patterns to ignore. Certain paths are always ignored such as `.git` or `.svn` paths.

### ignoreExtensions

An array of file extensions to ignore. Certain file extensions such as image files (png, gif, jpg, etc) are always ignored.

### ignoreScanners 

An array of scanner name slugs to ignore. For example `["sqlinjection","xss","pathtraversal"]` would ignore or omit the results of the _SQL Injection Scanner_ the _Cross Site Scripting (XSS) Scanner_ and the _Path Traversal_ scanner.

### minSeverity

Default: `low` - The minimum severity level that will be flagged. Set this to `high` if you only care about severe issues. 

### minConfidence

Default: `high` - The minimum confidence level that will be flagged. Issues with `low` confidence will be more likely to be false positives.

### ignorePatterns

Some applications may have their own functions for safely encoding varaibles to prevent Cross Site Scripting (XSS). Suppose you have a `customEncodeHTML()` function that is similar to `encodeForHTML()`, we can tell Fixinator's XSS scanner to ignore variables that have the `customEncodeHTML` function call

	"ignorePatterns": {
			"xss": ["customEncodeHTML("]
	}

Now suppose you have an a few application variables that are used in SQL, they are not vulnerable to SQL injection because they are hard coded in the application. We can ignore those by adding some patterns for the `sqlinjection` scanner:

	"ignorePatterns": {
			"xss": ["customEncodeHTML("],
			"sqlinjection": ["application.table_prefix", "application.items_per_page"]
	}

This is a very powerful feature, so make sure you only use it on variables, functions or patterns you know are safe.

### engines

An array of CFML engines that the code runs on.

### includeScanners

An array of scanner ids which to use, all other scanners will be ignored.

## Ignoring issues in code

You can ignore an issue in your source code by adding a comment like this:

	<cfquery>
		SELECT x FROM table
		<!--- ignore:sqlinjection - #id# is not vulnerable to SQL injection because of XYZ --->
		WHERE id = #id#
	</cfquery>

The comment must be on the same line as the issue, or on the line above the issue. It must include `ignore:issueType` where `issueType` is the fixinator id type for the issue. Fully supported in cfscript as well, for example:

	//ignore:iif - b and a are safe variables because... 
	x = iif(c, b, a);

Also take a look at the `ignorePatterns` object in the `.fixinator.json` file for another way to ignore code from fixinator.
