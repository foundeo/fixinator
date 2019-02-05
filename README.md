# fixinator-client

## Command Line Arguments

When running the `fixinator` command via the command line you can set the following arguments:

### path

The folder or file to scan.

## Environment Variables

The following environment variables are used by fixinator:

### FIXINATOR_API_KEY

The `FIXINATOR_API_KEY` environment variable holds an API key which will be passed to the Fixinator API service via the `x-api-key` HTTP request header. Please visit <https://fixinator.app/> to obtain a key.

### FIXINATOR_API_URL

The `FIXINATOR_API_URL` environment variable points to the URL of the Fixinator API service. If you are running fixinator locally you will want to point this to your local API instance. If you are using the public API then you do not need to set this variable.

## .fixinator.json

A `.fixinator.json` configuration file can be placed in the root of a folder to be scanned. For Example:

	{
		"ignoredPaths":["some/folder-to-ignore", "some/file-to-ignore.cfm"],
		"ignoredExtensions":["ign","ore"],
		"ignoreScanners":[],
		"minSeverity": "low",
		"minConfidence": "low"
	}

Note that `.fixinator.json` files placed in a subfolder of the base scan path are currently ignored.

### ignoredPaths

An array of path patterns to ignore. Certain paths are always ignored such as `.git` or `.svn` paths.

### ignoredExtensions

An array of file extensions to ignore. Certain file extensions such as image files (png, gif, jpg, etc) are always ignored.

### ignoreScanners 

An array of scanner name slugs to ignore.

### minSeverity

Default: `low` - The minimum severity level that will be flagged. Set this to `high` if you only care about severe issues. 

### minConfidence

Default: `high` - The minimum confidence level that will be flagged. Issues with `low` confidence will be more likely to be false positives.

