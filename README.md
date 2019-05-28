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

Specify either json (default), html or pdf.

## Environment Variables

The following environment variables are used by fixinator:

### FIXINATOR_API_KEY

The `FIXINATOR_API_KEY` environment variable holds an API key which will be passed to the Fixinator API service via the `x-api-key` HTTP request header. Please visit <https://fixinator.app/> to obtain a key.

### FIXINATOR_API_URL

The `FIXINATOR_API_URL` environment variable points to the URL of the Fixinator API service. If you are running fixinator locally you will want to point this to your local API instance. If you are using the public API then you do not need to set this variable.

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

