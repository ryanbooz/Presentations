$SSDTToolsPath = $PSScriptRoot + "\build\Microsoft.Data.Tools.Msbuild.10.0.61804.210\lib\net46"
$env:SQLDBExtensionsRefPath=$SSDTToolsPath
$env:SSDTPath=$SSDTToolsPath

$MSBuildPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\Bin\MSBuild.exe"
$SSDTProject = ".\BabbyNames-DB\BabbyNames-DB.sqlproj"

& $MSBuildPath "/p:PostBuildEvent=" $SSDTProject

if($LASTEXITCODE -ne 0)
{
  exit $LASTEXITCODE
}
