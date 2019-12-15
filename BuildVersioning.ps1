$repoDir = "$PSScriptRoot"
$versioningDir = "$repoDir/versioning"

Write-Host "Load AutoSemVer"
. "$versioningDir/AutoSemVer.ps1"

function PushToGithub {
    [CmdletBinding()]
    param()
    $ghUsername = $env:GH_USERNAME
    $ghOrg = $env:GH_ORG
    $ghRepo = $env:GH_REPO
    $gitToken = $env:GIT_TOKEN    
    
    $pushUrl = "https://$ghUsername`:{0}@github.com/$ghOrg/$ghRepo.git"
    Write-Host "Pushing to $pushUrl"
    $pushUrl = ($pushUrl -f $gitToken)
    Invoke-Expression -command "git push $pushUrl head:master --follow-tags -q" | Out-String -OutVariable out
}

function ConfigureGit {
    [CmdletBinding()]
    param()
    $gitEmail = $env:GH_EMAIL
    $gitName = $env:GH_NAME
    git config user.email $gitEmail
    git config user.name $gitName
}

function WriteApiFileAndPush {
    [CmdletBinding()]
    param()
    Write-Host "Write api file and push"
    $version = Bump
    $version = FormatVersion $version "v0.0.0"

    $versionChangeFile = "versioning/$version.txt"
    WriteCurrentApiChange $versionChangeFile
    $commitMessages = CommitMessagesSinceLastVersion
    [IO.File]::AppendAllText($versionChangeFile, "`n`nCommits:`n`n$commitMessages")
    
    WriteCurrentApiToFile
    
    $ErrorActionPreference = "Continue";
    ConfigureGit
    git add -A
    git commit -m  'Updated API file and docs'
    git tag -a $version -m 'Created by github action.'
    
    PushToGithub
}

function PushToFeed {
    [CmdletBinding()]
    param($packagePath)
    Write-Host "Push to feed"
    $ghUsername = $env:GH_USERNAME
    $ghOrg = $env:GH_ORG
    $ghRepo = $env:GH_REPO
    $gitToken = $env:GIT_TOKEN
    $nugetUrl = "https://nuget.pkg.github.com/$ghOrg/index.json"
    nuget source Add -Name "GPR" -Source $nugetUrl -UserName $ghOrg -Password $gitToken
    nuget setapikey $gitToken -source $nugetUrl
    nuget push $packagePath -Source "GPR"
}
