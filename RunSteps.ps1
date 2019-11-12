$srcDir = "$PSScriptRoot/src"
$libFilesDir = "$PSScriptRoot/LibFiles"

if(-not(Test-Path $srcDir)){
    # create new library
    dotnet new classlib -o src -n AutoSemVerLib
    rm "$srcDir/Class1.cs"
    git tag 0.0.1

    dotnet tool install -g synver
}

$libFile = "$srcDir/Lib.cs"

cp -force "$libFilesDir/Lib.0.cs" "$srcDir/Lib.cs" 

dotnet build src/AutoSemVerLib.csproj
.\versioning\AutoSemVer.ps1

#cp -force "$libFilesDir/Lib.1.WithAnotherMethod.cs" "$srcDir/Lib.cs" 
#cp -force "$libFilesDir/Lib.2.WithDifferentSignature.cs" "$srcDir/Lib.cs" 
#cp -force "$libFilesDir/Lib.3.WithOptionalArg.cs" "$srcDir/Lib.cs" 




