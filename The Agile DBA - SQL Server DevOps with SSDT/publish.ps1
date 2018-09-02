param(
    [string] $WorkingDir,
    [string] $ServerName,
    [bool] $UseIntegratedSecurity = $true,
    [string] $UserName,
    [securestring] $Password,
    [string] $Database
)

if($WorkingDir -eq "") {
    throw "You must pass in the working directory for the build script to work"
}

$SQLPackageExe = "C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin\SqlPackage.exe"

$DacpacFile = Join-Path $WorkingDir -ChildPath "BabbyNames.dacpac"
$PublishProfile = Join-Path $WorkingDir -ChildPath "develop.BabbyNames.publish.xml"



$connectionString = ""

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

if([string]::IsNullOrWhiteSpace($connectionString))
{
    & $SQLPackageExe "/a:Publish" ("/pr:" + $PublishProfile) ("/sf:" + $DacpacFile) 
}
else {
    & $SQLPackageExe "/a:Publish" ("/tcs:" + $connectionString) ("/pr:" + $PublishProfile) ("/sf:" + $DacpacFile)
}


if($LASTEXITCODE -ne 0)
{
  exit $LASTEXITCOD
}