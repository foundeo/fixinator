# fixinator-client

[![Build Status](https://foundeo.com/images/fixinator-demo.gif)](https://fixinator.app)


## Command Line Arguments

When running the `fixinator` command via the command line you can set the following arguments:

### path

The folder or file to scan.

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

Writes results to a file specified by the path in resultFile.

### resultFormat

Specify either `json` (default), `html`, `pdf`, `junit`, `sast`, or `findbugs`.

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

## .fixinator.json

A `.fixinator.json` configuration file can be placed in the root of a folder to be scanned. For Example:

	{
		"ignorePaths":["some/folder-to-ignore", "some/file-to-ignore.cfm"],
		"ignoreExtensions":["ign","ore"],
		"ignoreScanners":["xss"],
		"minSeverity": "low",
		"minConfidence": "low"
	}

Note that `.fixinator.json` files placed in a subfolder of the base scan path are currently ignored.

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

### failOnIssues

Default: `true` - When true returns an exit code of `1` when issues are found, this will cause your build to fail if you are running in CI. If you do not want the build to fail when issues are found, set this to `false`.

### listScanners

Default: `false` - Prints out a list of scanners supported by the server in the results. Automatically set to `true` when `verbose` is `true`

## Ignoring issues in code

You can ignore an issue in your source code by adding a comment like this:

	<cfquery>
		SELECT x FROM table
		<!--- ignore:sqlinjection - #id# is not vulnerable to SQL injection because of XYZ --->
		WHERE id = #id#
	</cfquery>

The comment must be on the same line as the issue, or on the line above the issue. It must include `ignore:issueType` where `issueType` is the fixinator id type for the issue. Fully supported in cfscript as well.
