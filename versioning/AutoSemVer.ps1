function EnsureSynVerIsInstalled 
{
    $Push_Pop = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"

    $whereSynver = where.exe synver

    if($whereSynver -eq $null){
        Write-Host "Install synver"
        dotnet tool install -g synver
    } else {
        Write-Verbose "synver installed"
    }

    $ErrorActionPreference = $Push_Pop
}

function _GetPath($p){
    return [IO.Path]::GetFullPath($p)
}

function _GetLatestTag {
    [CmdletBinding()]
    param($tagVersionRegex)
    $tags = git tag
    Write-Verbose "All tags: $tags"
    $filtered = $tags | Where-Object { $_ -match $tagVersionRegex }
    Write-Verbose "Filtered tags: $filtered"
    $lastTag = $filtered | Select-Object -Last 1
    Write-Verbose "Last tag: $lastTag"
    return $lastTag
}

function _CreateCommitInfo {
    [CmdletBinding()]
    param($commitHash, $commitMessage)
    
    $changeType = "Patch"
    if($commitMessage.StartsWith("feat")){
        $changeType = "Minor"
    }
    if($commitMessage.StartsWith("BREAKING CHANGE")){
        $changeType = "Major"
    }
    $object = New-Object PSObject -Property @{
        ChangeType = $changeType
        CommitHash = $commitHash
        CommitMessage = $commitMessage
    }
    return $object
}

function _GetCommitInfoSinceLastTag {
    [CmdletBinding()]
    param($lastVersion)
    $commitsSinceTagCmd = "git log $lastVersion..head --oneline"
    Write-Verbose "Running command '$commitsSinceTagCmd'"
    $commits = Invoke-expression -command $commitsSinceTagCmd
    $commitInfos = @()
    foreach($commit in $commits){
        Write-Verbose "$commit"
        $commitHash = $commit.Substring(0, 7)
        $commitMessage = $commit.Substring(8)
        $commitInfos += (_CreateCommitInfo -commitHash $commitHash -commitMessage $commitMessage)
    }

    return $commitInfos
}

function _GetSyntacticDifferenceOrPatch {
    [CmdletBinding()]
    param($currentApiPath, $builtLibPath)
    if((Test-Path $currentApiPath)){
        EnsureSynVerIsInstalled
        $cmd = "synver --magnitude $currentApiPath $builtLibPath"
        Write-Verbose "Running cmd '$cmd'"
        $magnitude = Invoke-expression -command $cmd
        return $magnitude
    } else {
        Write-Verbose "Previous api file not present at '$currentApiPath'. 
Can't find version diff with syntactic difference"
    }

    return "Patch"
}

function _GetSymanticDifferenceFromCommitInfos {
    [CmdletBinding()]
    param($commitInfos)
    $major = $commitInfos | Where-Object { $_.ChangeType -eq "Major" }
    if($major.Length -gt 0 -or $major -ne $null){
        return "Major"
    }
    $minorCommits = $commitInfos | Where-Object { $_.ChangeType -eq "Minor" }
    if($minorCommits.Length -gt 0 -or $minorCommits -ne $null){
        return "Minor"
    }
    return "Patch"
}

function _GetCombinedDiff {
    [CmdletBinding()]
    param($syntacticDiff, $semanticDiff)
    if($syntacticDiff -eq "Major" -or $synmanticDiff -eq "Major"){
        return "Major"
    }
    if($syntacticDiff -eq "Minor" -or $synmanticDiff -eq "Minor"){
        return "Minor"
    }
    return "Patch"
}

function _ParseVersionPartAsInt {
    [CmdletBinding()]
    param($part, $lastVersion, $tagVersionRegex)
    $matches = [regex]::Match($lastVersion, $tagVersionRegex)
    [int]$current = $matches[0].Groups[$part].Value
    return $current
}

function _ReplaceGroup {
    [CmdletBinding()]
    param($str, $regex, $groupName, $groupValue)
    
    $matchResults = ([regex]$regex).match($str)
    if($matchResults.Success -eq $false){
        return $str
    }
    
    $group = $matchResults.Groups[$groupName]
    foreach($capture in $group.Captures){
        $str = $str.Substring(0, $capture.Index) + $groupValue + $str.Substring($capture.Index + $capture.Length) 
    }

    return $str
}

function _GetNewVersionFromOldAndDiff {
    [CmdletBinding()]
    param($diff, $lastVersion, $tagVersionRegex)
    
    if(-not($lastVersion -match $tagVersionRegex))
    {
        Write-Error "Tag '$lastVersion' does not match regex '$tagVersionRegex'"
        exit 1
    }
    
    $major = _ParseVersionPartAsInt 'Major' $lastVersion $tagVersionRegex
    $minor = _ParseVersionPartAsInt 'Minor' $lastVersion $tagVersionRegex
    $patch = _ParseVersionPartAsInt 'Patch' $lastVersion $tagVersionRegex
    
    if($diff -eq "Major"){
        $major = $major + 1
        $minor = 0
        $patch = 0
    }
    
    if($diff -eq "Minor"){
        $minor = $minor + 1
        $patch = 0
    }
    
    if($diff -eq "Patch"){
        $patch = $patch + 1
    }

    Write-Verbose "New version - $major, $minor, $patch"
    return "$major.$minor.$patch"
}

function FormatVersion {
    [CmdletBinding()]
    param($version, $lastVersion, $tagVersionRegex)

    $versionRegex = "(?<Major>`\d+).(?<Minor>`\d+).(?<Patch>`\d+)"
    if(-not($version -match $versionRegex))
    {
        Write-Error "Tag '$version' does not match regex '$versionRegex'"
        exit 1
    }
    
    $tagVersionRegex = ArgOrEnv $tagVersionRegex $tagVersionRegexName
    
    $major = _ParseVersionPartAsInt 'Major' $version $versionRegex
    $minor = _ParseVersionPartAsInt 'Minor' $version $versionRegex
    $patch = _ParseVersionPartAsInt 'Patch' $version $versionRegex
    
    $newVersion = $lastVersion
    $newVersion = _ReplaceGroup -str $newVersion -regex $tagVersionRegex -groupName "Major" -groupValue $major
    $newVersion = _ReplaceGroup -str $newVersion -regex $tagVersionRegex -groupName "Minor" -groupValue $minor
    $newVersion = _ReplaceGroup -str $newVersion -regex $tagVersionRegex -groupName "Patch" -groupValue $patch
    
    return $newVersion
}

function ArgOrEnv {
    [CmdletBinding()]
    param($arg, $envName)
    if($arg -ne $null){
        return $arg
    }
    Write-Host "Getting env: $envName"
    $v = [System.Environment]::GetEnvironmentVariable($envName)
    if($v -eq $null){
        Write-Error "Env not present '$envName'"
        exit 1
    }
    return $v
}

$tagVersionRegexName = "TAG_VERSION_REGEX"
$builtLibName = "BUILT_NAME_REL"
$currentApiFileName = "CURRENT_API_NAME"

function NeedToRun {
    [CmdletBinding()]
    param($tagVersionRegex)
    $tagVersionRegex = ArgOrEnv $tagVersionRegex $tagVersionRegexName
    Write-Verbose "Tag regex - $tagVersionRegex"
    $lastVersion = _GetLatestTag -tagVersionRegex $tagVersionRegex
    if($lastVersion -eq $null){
        return $false
    }
    
    $commits = _GetCommitInfoSinceLastTag -lastVersion $lastVersion
    if($commits.Length -eq 0){
        return $false
    }
    
    return $true
}

function Bump {
    [CmdletBinding()]
    param(
        $builtLib,
        $currentApiFile,
        $tagVersionRegex
    )

    $builtLibPath = _GetPath (ArgOrEnv $builtLib $builtLibName)
    $currentApiPath = _GetPath (ArgOrEnv $currentApiFile $currentApiFileName)
    $tagVersionRegex = ArgOrEnv $tagVersionRegex $tagVersionRegexName
    
    if(-not(Test-Path $builtLibPath)){
        Write-Error "Dll not present at '$builtLibPath'. Can't continue."
        return $null
    }

    $lastVersion = _GetLatestTag -tagVersionRegex $tagVersionRegex
    if($lastVersion -eq $null){
        Write-Error "Cant find last version with '$tagVersionRegex'. Can't continue."
        return $null
    }
    
    $commits = _GetCommitInfoSinceLastTag -lastVersion $lastVersion
    if($commits.Length -eq 0){
        Write-Host "No commits since last version tag."
        return $null
    }
    Write-Verbose " Commits found: $commits"
    
    $semanticDiff = _GetSymanticDifferenceFromCommitInfos $commits

    $syntacticDiff = _GetSyntacticDifferenceOrPatch `
                        -currentApiPath $currentApiPath `
                        -builtLibPath $builtLibPath

    $diff = _GetCombinedDiff -syntacticDiff $syntacticDiff -semanticDiff $semanticDiff
    
    $newVersion = _GetNewVersionFromOldAndDiff -lastVersion $lastVersion -diff $diff -tagVersionRegex $tagVersionRegex
    
    return $newVersion
}

function WriteCurrentApiToFile {
    [CmdletBinding()]
    param($builtLib, $currentApiFile)
    EnsureSynVerIsInstalled
    $builtLibPath = _GetPath (ArgOrEnv $builtLib $builtLibName)
    $currentApiPath = _GetPath (ArgOrEnv $currentApiFile $currentApiFileName)
    $cmd = "synver --surface-of $builtLibPath --output $currentApiPath"
    Write-Verbose "Running cmd '$cmd'"
    Invoke-expression -command $cmd
}

function WriteCurrentApiChange {
    [CmdletBinding()]
    param($outputFile, $builtLibFile, $currentApiFile)
    EnsureSynVerIsInstalled
    $builtLibPath = _GetPath (ArgOrEnv $builtLib $builtLibName)
    $currentApiPath = _GetPath (ArgOrEnv $currentApiFile $currentApiFileName)
    $outputPath = _GetPath $outputFile
    $cmd = "synver --diff  $currentApiPath $builtLibPath --output $outputPath"
    Write-Verbose "Running cmd '$cmd'"
    Invoke-expression -command $cmd
}

function GetCommitsSinceLastVersion {
    [CmdletBinding()]
    param($tagVersionRegex)
    $tagVersionRegex = ArgOrEnv $tagVersionRegex $tagVersionRegexName
    
    $lastVersion = _GetLatestTag -tagVersionRegex $tagVersionRegex
    if($lastVersion -eq $null){
        Write-Error "Cant find last version with '$tagVersionRegex'. Can't continue."
        return $null
    }
    
    $commits = _GetCommitInfoSinceLastTag -lastVersion $lastVersion
    if($commits.Length -eq 0){
        Write-Host "No commits since last version tag."
        return $null
    }
    
    return $commits
}

function CommitMessagesSinceLastVersion {
    [CmdletBinding()]
    param()
    $commits = GetCommitsSinceLastVersion
    if($commits -eq $null){ return $null}
    $messages = ""

    foreach ($commit in $commits){
        $formattedCommit = "$($commit.CommitHash) - $($commit.ChangeType) - $($commit.CommitMessage)"
        $messages = "$messages$formattedCommit`n"
    }
    return $messages
}
