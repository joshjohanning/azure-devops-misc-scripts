
  
 <# param (
    [string]$dacpacFile = "test.dacpac", 
    [string]$publishProfile = "test.xml",
    [string]$targetDBServer = "testServer",
    [string]$targetDBName = "testName",
    [string]$outputPath = "testOutput.xml"

 )#>

param (
    [string]$dacpacFile = $(throw "dacpacFile is mandatory, please provide a value."), 
    [string]$publishProfile = $(throw "publishProfile is mandatory, please provide a value."),
    [string]$targetDBServer = $(throw "targetDBServer is mandatory, please provide a value."),
    [string]$targetDBName = $(throw "targetDBName is mandatory, please provide a value."),
    [string]$outputPath = $(throw "outputPath is mandatory, please provide a value."),
    [string]$otherArgs = ""
 )


 Import-Module "$PSScriptRoot\SqlPackageOnTargetMachines.ps1"


function Get-SqlPackageCmdArgsDeployReport
{
    param (
    [string]$dacpacPath,
    [string]$publishProfile,
    [string]$server,
    [string]$dbName
    )

    try
    {
        # validate dacpac file
        if ([System.IO.Path]::GetExtension($dacpacPath) -ne ".dacpac")
        {
            throw "Invalid Dacpac file [ $dacpacPath ] provided"
        }
    }
    catch [System.Exception]
    {
        Write-Verbose ("Could not verify DacPac : " + $_.Exception.Message) -Verbose
    }

    $sqlPkgCmdArgs = [string]::Format(' /SourceFile:"{0}" /Action:DeployReport', $dacpacPath)

    try
        {
            # validate output file
            if ([System.IO.Path]::GetExtension($outputPath) -ne ".xml")
            {
                throw "Invalid output file [ $outputPath ] provided, that should be an xml file really"
            }
            $sqlPkgCmdArgs = [string]::Format('{0} /OutputPath:"{1}"', $sqlPkgCmdArgs, $outputPath)
            }
        catch [System.Exception]
        {
            Write-Verbose ("Could not verify ouput path : " + $_.Exception.Message) -Verbose
        }

    if( ![string]::IsNullOrWhiteSpace($publishProfile) )
    {
         try
        {
            # validate publish profile
            if ([System.IO.Path]::GetExtension($publishProfile) -ne ".xml")
            {
                throw "Invalid Publish Profile [ $publishProfile ] provided"
            }
            $sqlPkgCmdArgs = [string]::Format('{0} /Profile:"{1}"', $sqlPkgCmdArgs, $publishProfile)
            }
        catch [System.Exception]
        {
            Write-Verbose ("Could not verify profile : " + $_.Exception.Message) -Verbose
        }
        
    }

    if( ![string]::IsNullOrWhiteSpace($dbName) )
    {
       $sqlPkgCmdArgs = [string]::Format('{0} /TargetServerName:"{1}" /TargetDatabaseName:"{2}" {3}', $sqlPkgCmdArgs, $server, $dbName, $otherArgs)
    }

   #Write-Verbose "Sqlpackage.exe arguments : $sqlPkgCmdArgs" -Verbose
    return $sqlPkgCmdArgs
}

function Format-XML ([xml]$xml, $indent=2) 
{ 
    $StringWriter = New-Object System.IO.StringWriter 
    $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter 
    $xmlWriter.Formatting = “indented” 
    $xmlWriter.Indentation = $Indent 
    $xml.WriteContentTo($XmlWriter) 
    $XmlWriter.Flush() 
    $StringWriter.Flush() 
    Write-Output $StringWriter.ToString() 
}

$sqlPackage = Get-SqlPackageOnTargetMachine 

#Write-Verbose "So the path the SQL Package is $sqlPackage ?" -Verbose

$sqlPackageArguments = Get-SqlPackageCmdArgsDeployReport $dacPacFile $publishProfile $targetDBServer $targetDBName

If (Test-Path $outputPath){
    Write-Verbose("Deleting old report")
    #[xml]$report = Get-Content $outputPath 

    #Format-XML $report -indent 4 | Write-Verbose -Verbose
	Remove-Item $outputPath
}

Write-Verbose("Running ExecuteCommand -FileName ""$sqlPackage""  -Arguments $sqlPackageArguments") -Verbose

try{
    ExecuteCommand -FileName "$sqlPackage"  -Arguments $sqlPackageArguments
} catch [System.Exception]
{
     Write-Verbose ("Running the report failed : " + $_.Exception.Message) -Verbose
} catch 
{
    Write-Verbose("An error of some kind happened, sorry.") -Verbose
}

[xml]$report = Get-Content $outputPath 

Format-XML $report -indent 4 | Write-Verbose -Verbose

<#todo
Write-Verbose("Alerts : ") -Verbose
$report.DeploymentReport.Alerts | Format-Table -AutoSize |Write-Verbose -Verbose
Write-Verbose("Operations : ") -Verbose
$report.DeploymentReport.Operations | Format-Table -AutoSize |Out-String |Write-Verbose -Verbose
$report.DeploymentReport.Operations | Format-Table -AutoSize |Out-String |Write-Verbose -Verbose
$report.DeploymentReport.Operations | Format-Table -AutoSize |Out-String |Write-Verbose -Verbose
#>