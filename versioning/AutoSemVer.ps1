function GetPath($p){
    return [IO.Path]::GetFullPath($p)
}

function WriteCurrentApiToFile {
    param(
        $builtLibPath,
        $currentApiPath
    )
    $cmd = "synver --decompile --surface-of $builtLibPath --output $currentApiPath"
    Write-Debug "Running cmd '$cmd'"
    Invoke-expression -command $cmd
}

function GetCommitMessagesSinceLastTag {
    param($tagVersionRegex)

    $tags = git tag
    Write-Debug "All tags: $tags"
    $filtered = $tags | Where-Object { $_ -match $tagVersionRegex }
    Write-Debug "Filtered tags: $filtered"
    $lastTag = $filtered | Select-Object -Last 1
    $commitsSinceTagCmd = "git log $lastTag..head --oneline"
    Write-Debug "Running command '$commitsSinceTagCmd'"
    $commits = Invoke-expression -command $commitsSinceTagCmd
    
}

function RunAutoSemVer {
    param(
        $projFile,
        $builtLib,
        $semanticChangesFile,
        $currentApiFile,
        $documentationFile,
        $tagVersionRegex
    )

    $projPath = GetPath $projFile
    $builtLibPath = GetPath $builtLib
    $semanticChangesPath = GetPath $semanticChangesFile
    $currentApiPath = GetPath $currentApiFile
    $documentationPath = GetPath $documentationFile

    Write-Host "Running auto SemVer with:
Project file          - $projPath
Built lib path        - $builtLibPath
Semantic changes file - $semanticChangesPath
Current api lson file - $currentApiPath
Documentation file    - $documentationPath
Tag regex             - $tagVersionRegex"

    if(-not(Test-Path $builtLibPath)){
        Write-Error "Dll not present at '$builtLibPath'. Can't continue."
        exit 1
    }

    GetCommitMessagesSinceLastTag -tagVersionRegex $tagVersionRegex
    
    if(-not(Test-Path $currentApiPath)){
        Write-Error "Previous api file not present at '$currentApiPath'. Can't find version diff.
Write file to current location and tag with current version."
        WriteCurrentApiToFile -builtLibPath $builtLibPath -currentApiPath $currentApiPath
        exit 1
    }

}

$versioningDir = "$PSScriptRoot"

RunAutoSemVer `
    -projFile            "$versioningDir/../src/AutoSemVerLib.csproj" `
    -builtLib            "$versioningDir/../src/bin/Debug/netstandard2.0/AutoSemVerLib.dll" `
    -semanticChangesFile "$versioningDir/SemanticChanges.json" `
    -currentApiFile      "$versioningDir/AutoSemVerLibApi.lson" `
    -documentationFile   "$versioningDir/Changes.md" `
    -tagVersionRegex     "v(?<Major>`\d+).(?<Minor>`\d+).(?<Fix>`\d+)"

