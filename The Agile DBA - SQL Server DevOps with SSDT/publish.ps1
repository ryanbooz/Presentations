<#
This is a (slightly more than minimal) example of a publish script that can work
with Visual Studio Team Services and a local build/publish agent. As with the build
script, this is specifically tied to my demos and needs some TLC to be more modular.

Keys to success with this script:

1. The working directory parameter must be supplied, and is the directory that 
   contains the ouput of the build script. If not otherwise specified in the build
   script, this will be the project name configured through the project properties.

2. SqlPackage.exe must be available on the deployment machine. This is a cross-platform
   tool that can be installed separately, apart from SQL Server or VS tooling.

3. There is a specific publish profile referenced below for the demos. This is an 
   essential key to having consistent deployment rules. When you make a publish
   profile, make sure to select "copy always" from the file properties so that it
   will be copied into the same directory as the DACPAC and can be referenced here. 

All other parameters help determine how to build the connection string and call SqlPackage
to do the deployment.

#>

param(
    [string] $WorkingDir,
    [string] $ServerName,
    [bool] $UseIntegratedSecurity = $true,
    [string] $UserName,
    [securestring] $Password,
    [string] $Database
)

<#
 The working directory is whatever directory the build process put the output files.

 Most build tooling (VSTS included) generally provides constants for these locations
 that you can use. Otherwise, if using this script locally, you would typically
 point the working directory to your "bin/debug" directory where the DACPAC and 
 publish profile are stored.

#>
if($WorkingDir -eq "") {
    throw "You must pass in the working directory for the build script to work"
}

# The location of SqlPackage on the machine running this script
$SQLPackageExe = "C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin\SqlPackage.exe"

# Create valid paths to each of the two file necessary to do the deployments/publish
$DacpacFile = Join-Path $WorkingDir -ChildPath "BabbyNames.dacpac"
$PublishProfile = Join-Path $WorkingDir -ChildPath "develop.BabbyNames.publish.xml"

$connectionString = ""

<#
If a server name is provided, then we will begin to create the connection string of the
target database. If it was NOT provided, then we assume the target specified in the
deployment profile is the target of these changes.
#>
if($ServerName)
{
    $connectionString += ("Server={0}" -f $ServerName)

    If ($UseIntegratedSecurity)
    {
        Write-Verbose "Using integrated security"
        $connectionString += ";Trusted_Connection=True"
    }
    Else{
        Write-Verbose "Using standard security"
        $connectionString += (";Uid={0};Pwd={1}" -f $UserName, $Password)
    }

    If ($Database)
    {
        $connectionString += (";Initial Catalog={0}" -f $Database)
    }
}

<#
Depending on the status of the connection string, publish the database changes
#>
if([string]::IsNullOrWhiteSpace($connectionString))
{
    & $SQLPackageExe "/a:Publish" ("/pr:" + $PublishProfile) ("/sf:" + $DacpacFile) 
}
else {
    & $SQLPackageExe "/a:Publish" ("/tcs:" + $connectionString) ("/pr:" + $PublishProfile) ("/sf:" + $DacpacFile)
}


if($LASTEXITCODE -ne 0)
{
  exit $LASTEXITCODE
}