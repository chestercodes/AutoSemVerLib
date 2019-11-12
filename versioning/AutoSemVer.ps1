function GetPath($p){
    return [IO.Path]::GetFullPath($p)
}

$versioningDir = "$PSScriptRoot"
$configPath = "$versioningDir/AutoSemVer.json"
$autoSemVerJson = Get-Content $configPath | ConvertFrom-Json

$projPath = GetPath "$versioningDir/$($autoSemVerJson.projFile)"
$builtLibPath = GetPath "$versioningDir/$($autoSemVerJson.builtLib)"
$semanticChangesPath = GetPath "$versioningDir/$($autoSemVerJson.semanticChangesFile)"
$currentApiPath = GetPath "$versioningDir/$($autoSemVerJson.currentApiFile)"
$documentationPath = GetPath "$versioningDir/$($autoSemVerJson.documentationFile)"

Write-Host "Project file          - $projPath"
Write-Host "Built lib path        - $builtLibPath"
Write-Host "Semantic changes file - $semanticChangesPath"
Write-Host "Current api lson file - $currentApiPath"
Write-Host "Documentation file    - $documentationPath"

