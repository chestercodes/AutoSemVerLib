
function GetPath($p){
    return [IO.Path]::GetFullPath($p)
}

function WriteCurrentApiToFile {
    [CmdletBinding()]
    param(
        $builtLibPath,
        $currentApiPath
    )
    $cmd = "synver --decompile --surface-of $builtLibPath --output $currentApiPath"
    Write-Verbose "Running cmd '$cmd'"
    Invoke-expression -command $cmd
}

function GetLatestTag {
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

function CreateCommitInfo {
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

function GetCommitInfoSinceLastTag {
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
        $commitInfos += (CreateCommitInfo -commitHash $commitHash -commitMessage $commitMessage)
    }

    return $commitInfos
}

function GetSyntacticDifferenceOrPatch {
    [CmdletBinding()]
    param($currentApiPath, $builtLibPath)
    if((Test-Path $currentApiPath)){
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

function GetSymanticDifferenceFromCommitInfos {
    [CmdletBinding()]
    param($commitInfos)
    $majorCommits = $commitInfos | Where-Object { $_.ChangeType -eq "Major" }
    if($majorCommits.Length -gt 0 -or $majorCommits -ne $null){
        return "Major"
    }
    $minorCommits = $commitInfos | Where-Object { $_.ChangeType -eq "Minor" }
    if($minorCommits.Length -gt 0 -or $minorCommits -ne $null){
        return "Minor"
    }
    return "Patch"
}

function GetCombinedDiff {
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

function ParseVersionPartAsInt {
    [CmdletBinding()]
    param($lastVersion, $part, $tagVersionRegex)
    $matches = [regex]::Match($lastVersion, $tagVersionRegex)
    [int]$current = $matches[0].Groups[$part].Value
    return $current
}

function GetNewVersionFromOldAndDiff {
    [CmdletBinding()]
    param($diff, $lastVersion, $tagVersionRegex)
    
    if(-not($lastVersion -match $tagVersionRegex))
    {
        Write-Error "Tag '$lastVersion' does not match regex '$tagVersionRegex'"
        exit 1
    }
    
    $currentMajor = ParseVersionPartAsInt 'Major' $lastVersion $tagVersionRegex

    if($diff -eq "Major"){
        $newMajor = $currentMajor + 1
        return "$newMajor.0.0"
    }
    
    $currentMinor = ParseVersionPartAsInt 'Minor' $lastVersion $tagVersionRegex
    if($diff -eq "Minor"){
        $newMinor = $currentMinor + 1
        return "$currentMajor.$newMinor.0"
    }
    
    $currentPatch = ParseVersionPartAsInt 'Patch' $lastVersion $tagVersionRegex
    if($diff -eq "Patch"){
        $newPatch = $currentPatch + 1
        return "$currentMajor.$currentMinor.$newPatch"
    }

    Write-Error "Cannot perform for diff value '$diff'"
    exit 1
}

function Bump {
    [CmdletBinding()]
    param(
        $builtLib,
        $currentApiFile,
        $tagVersionRegex
    )

    $builtLibPath = GetPath $builtLib
    $currentApiPath = GetPath $currentApiFile
    
    Write-Verbose "Running auto SemVer with:
Built lib path        - $builtLibPath
Current api lson file - $currentApiPath
Tag regex             - $tagVersionRegex"

    if(-not(Test-Path $builtLibPath)){
        Write-Error "Dll not present at '$builtLibPath'. Can't continue."
        exit 1
    }

    $lastVersion = GetLatestTag -tagVersionRegex $tagVersionRegex
    
    $commits = GetCommitInfoSinceLastTag -lastVersion $lastVersion
    if($commits.Length -eq 0){
        Write-Host "No commits since last version tag."
        exit 1
    }
    Write-Verbose " Commits found: $commits"
    
    $semanticDiff = GetSymanticDifferenceFromCommitInfos $commits

    $syntacticDiff = GetSyntacticDifferenceOrPatch `
                        -currentApiPath $currentApiPath `
                        -builtLibPath $builtLibPath

    $diff = GetCombinedDiff -syntacticDiff $syntacticDiff -semanticDiff $semanticDiff
    
    $newVersion = GetNewVersionFromOldAndDiff -lastVersion $lastVersion -diff $diff -tagVersionRegex $tagVersionRegex
    
    return $newVersion
}

$versioningDir = "$PSScriptRoot"

$nextVersion = Bump -Verbose `
    -builtLib            "$versioningDir/../src/bin/Debug/netstandard2.0/AutoSemVerLib.dll" `
    -currentApiFile      "$versioningDir/AutoSemVerLibApi.lson" `
    -tagVersionRegex     "v(?<Major>`\d+).(?<Minor>`\d+).(?<Patch>`\d+)"
    #-projFile            "$versioningDir/../src/AutoSemVerLib.csproj" `
    
Write-Host "$nextVersion"