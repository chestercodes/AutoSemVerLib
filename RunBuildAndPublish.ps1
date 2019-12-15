function SetIfNotExists($varName, $varValue){
    $v = [System.Environment]::GetEnvironmentVariable($varName)
    if($v -ne $null){
        return
    }
    [System.Environment]::SetEnvironmentVariable($varName, $varValue, [System.EnvironmentVariableTarget]::Process)
}
SetIfNotExists 'TAG_VERSION_REGEX' "v(?<Major>`\d+).(?<Minor>`\d+).(?<Patch>`\d+)"
SetIfNotExists 'BUILT_NAME_REL' 'src/bin/Release/netstandard2.0/MyProject.dll'
SetIfNotExists 'CURRENT_API_NAME' 'versioning/MyProject.lson'
SetIfNotExists 'GH_USERNAME' 'chestercodes'
SetIfNotExists 'GH_ORG' 'chestercodes'
SetIfNotExists 'GH_REPO' 'AutoSemVerLib'
SetIfNotExists 'GH_EMAIL' 'chesterbot@example.com'
SetIfNotExists 'GH_NAME' 'chesterbot'
$ErrorActionPreference = "Stop";
$repoDir = "$PSScriptRoot"
. "$repoDir/BuildAndPublish.ps1"