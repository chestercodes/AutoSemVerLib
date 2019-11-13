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

function RunAutoSemVer {
    param(
        $projFile,
        $builtLib,
        $semanticChangesFile,
        $currentApiFile,
        $documentationFile
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
Documentation file    - $documentationPath"

    if(-not(Test-Path $builtLibPath)){
        Write-Error "Dll not present at '$builtLibPath'. Can't continue."
        exit 1
    }
    
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
    -documentationFile   "$versioningDir/Changes.md"


