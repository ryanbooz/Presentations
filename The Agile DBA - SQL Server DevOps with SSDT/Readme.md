# The Agile DBA - SQL Server DevOps with SSDT #

## Included Files ##

* **BabbyNamesDemo-VSProject.ZIP** - This is the end of the example project with the tables, views, functions and stored procedures already created. Reset it to the head of Master of Dev to "start over".

* **TrigramDemoCode.sql** - This file includes the SQL functions, etc. needed to get from a clean DB to one that can search names based on trigrams.

* **BabbyNames_Testing.sql** - This file has the SQL necessary to check your progress and actually search names.

* **build.ps1** - This is a simple, example build script. It can be used with any build environment that has MSBuild installed. As of January 2019, MSBuild is still not cross-platform for database projects. This means that you will have to still run this build in a Windows environment. Notice the environment variables at the beginning of the script. These are needed so that MSBuild knows where to find the DacFx build tooling that you loaded from the NuGet package in the slide deck.

* **publish.ps1** - This is a simple, example publish script. This takes the output files from the build script and actually deploys your changes to a target database. There is a lot of room to customize and improve for your environment. For instance, you can take in a variable name that specifies the database name and server and doesn't rely on the named database in the publish profile. Use this as a starting point.

* **publish-withContributor.ps1** - This script adds the use of a deployment contributor from Ed Elliot. Links to his blog are in the slide deck.

