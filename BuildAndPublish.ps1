
. "./BuildVersioning.ps1"

if((NeedToRun) -eq $false){
    Write-Host "Dont need to run script"
    exit 0
}

$projFile = "src/MyProject.csproj"

dotnet build $projFile -c Release 

$nextVersion = Bump

dotnet pack $projFile -c Release /p:Version=$nextVersion -o out

WriteApiFileAndPush

$packagePath = ls -Path ./out -Filter "*.nupkg" | sort LastWriteTime `
                | select -last 1 | select -ExpandProperty FullName
PushToFeed $packagePath