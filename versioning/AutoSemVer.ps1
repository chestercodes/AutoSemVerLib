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
    param(
        $builtLibPath,
        $currentApiPath
    )
    $cmd = "synver --decompile --surface-of $builtLibPath --output $currentApiPath"
    Write-Verbose "Running cmd '$cmd'"
    Invoke-expression -command $cmd
}

function GetLatestTag {
    param($tagVersionRegex)
    $tags = git tag
    Write-Verbose "All tags: $tags"
    $filtered = $tags | Where-Object { $_ -match $tagVersionRegex }
    Write-Verbose "Filtered tags: $filtered"
    $lastTag = $filtered | Select-Object -Last 1
    Write-Host "Last tag: $lastTag"
    return $lastTag
}

function GetCommitMessagesSinceLastTag {
    param($lastVersion)
    $commitsSinceTagCmd = "git log $lastVersion..head --oneline"
    Write-Verbose "Running command '$commitsSinceTagCmd'"
    $commits = Invoke-expression -command $commitsSinceTagCmd
    return $commits
}

function RunAutoSemVer {
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

    Write-Host "Running auto SemVer with:
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
    
    $commits = GetCommitMessagesSinceLastTag -lastVersion $lastVersion
    if($commits.Length -eq 0){
        Write-host "No commits since last version tag."
        exit 0
    }
    Write-Verbose " Commits found: $commits"

    if(-not(Test-Path $currentApiPath)){
        Write-Warning "Previous api file not present at '$currentApiPath'. 
Can't find version diff with syntactic difference, use just semantic differences.
Write file to current location for next run."
        WriteCurrentApiToFile -builtLibPath $builtLibPath -currentApiPath $currentApiPath
        return
    }

}

$versioningDir = "$PSScriptRoot"

RunAutoSemVer `
    -projFile            "$versioningDir/../src/AutoSemVerLib.csproj" `
    -builtLib            "$versioningDir/../src/bin/Debug/netstandard2.0/AutoSemVerLib.dll" `
    -currentApiFile      "$versioningDir/AutoSemVerLibApi.lson" `
    -documentationFile   "$versioningDir/Changes.md" `
    -tagVersionRegex     "v(?<Major>`\d+).(?<Minor>`\d+).(?<Fix>`\d+)"

