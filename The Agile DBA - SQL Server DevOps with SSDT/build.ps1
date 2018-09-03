<#
This is an simple, example build script for SQL Server Data Projects.

See this post by the Data Tools team which mentions the need to have environment variables
setup for the overall process to work. The entire 5-part series is worth reading to better
understand the process

The keys here are three fold:

 1. The MSBuild Data Tools must be installed in the source directory somewhere. Genrally, I
    do this at the root of the solution directory in a folder called "build". That folder, and
    the tools inside, are referenced in the first line of this script. Adjust accordingly.

 2. The environment variables must currently be set to that build path. Again, see the article
    mentioned above for that detail and direction.

 3. The path to MSBuild must be set accordingly. If Visual Studio (with SSDT/Data Projects) is
    installed, then you can point to that as I've done below (my demo machine). HOWEVER, if this
    is a build machine, then you can simply install the MSBuild tools without having to install
    and maintane Visual Studio. See (https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2017)

With those three pieces in place, this script, in the root of the solution/source directory, can 
be executed by your build service.

The output of the build process will be a DACPAC and whatever artifacts you indicated should be
"copied always", like the deployment profile. As with any MSBuild script, there are multiple
parameters and options you can pass in or appent to actual execution of MSBuild to attain the
behavior you would like.

#>

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
