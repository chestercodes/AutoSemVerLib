# If dll file doesn't exist then stop

# get last version, bail if doesnt exist

# get commits since last version, if none then stop

# if api file doesnt exist then find new version 
# from semantic changes and write current api to file

# if api file exists then find syntactic diff in version and combine
# with semantic version diff to find biggest and next version


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
    if($majorCommits.Length -gt 0){
        return "Major"
    }
    $minorCommits = $commitInfos | Where-Object { $_.ChangeType -eq "Minor" }
    if($minorCommits.Length -gt 0){
        return "Minor"
    }
    return "Patch"
}

function Bump {
    [CmdletBinding()]
    param(
        $projFile,
        $builtLib,
        $currentApiFile,
        $documentationFile,
        $tagVersionRegex
    )

    $projPath = GetPath $projFile
    $builtLibPath = GetPath $builtLib
    $currentApiPath = GetPath $currentApiFile
    $documentationPath = GetPath $documentationFile

    Write-Verbose "Running auto SemVer with:
Project file          - $projPath
Built lib path        - $builtLibPath
Current api lson file - $currentApiPath
Documentation file    - $documentationPath
Tag regex             - $tagVersionRegex"

    if(-not(Test-Path $builtLibPath)){
        Write-Error "Dll not present at '$builtLibPath'. Can't continue."
        exit 1
    }

    $lastVersion = GetLatestTag -tagVersionRegex $tagVersionRegex
    
    $commits = GetCommitInfoSinceLastTag -lastVersion $lastVersion
    if($commits.Length -eq 0){
        Write-Verbose "No commits since last version tag."
        exit 0
    }
    Write-Verbose " Commits found: $commits"
    
    # save semantic text differences to file, only commits that are feat etc
    
    # find the semantic biggest difference

    # find the syntactic biggest difference if file exists using the --magnitude
    $syntacticDiff = GetSyntacticDifferenceOrPatch `
                        -currentApiPath $currentApiPath `
                        -builtLibPath $builtLibPath

    # combine semantic and syntactic differences and get new version

    # write api changes to file if appropriate
    #WriteCurrentApiToFile -builtLibPath $builtLibPath -currentApiPath $currentApiPath
}

$versioningDir = "$PSScriptRoot"

$nextVersion = Bump -Verbose `
    -projFile            "$versioningDir/../src/AutoSemVerLib.csproj" `
    -builtLib            "$versioningDir/../src/bin/Debug/netstandard2.0/AutoSemVerLib.dll" `
    -currentApiFile      "$versioningDir/AutoSemVerLibApi.lson" `
    -documentationFile   "$versioningDir/Changes.md" `
    -tagVersionRegex     "v(?<Major>`\d+).(?<Minor>`\d+).(?<Patch>`\d+)"

