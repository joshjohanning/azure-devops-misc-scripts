<# 
Azure DevOps Pipeline Trigger Script

This script triggers Azure DevOps pipelines via REST API with configurable parameters.

Resources:
    https://stackoverflow.com/questions/60852825/azure-devops-yaml-pipeline-parameters-not-working-from-rest-api-trigger
    https://stackoverflow.com/questions/34343084/start-a-build-and-passing-variables-through-azure-devops-rest-api
    https://stackoverflow.com/questions/63654387/azure-rest-api-for-running-builds-or-pipelines

Usage Examples:

1. Basic usage (minimal required parameters):
   .\trigger-pipeline.ps1 -pat "your-pat-token" -organizationUrl "https://dev.azure.com/yourorg/" -project "YourProject" -pipelineId "123"

2. With custom branch:
   .\trigger-pipeline.ps1 -pat "your-pat-token" -organizationUrl "https://dev.azure.com/yourorg/" -project "YourProject" -pipelineId "123" -refName "refs/heads/develop"

3. With template parameters:
   .\trigger-pipeline.ps1 -pat "your-pat-token" -organizationUrl "https://dev.azure.com/yourorg/" -project "YourProject" -pipelineId "123" -templateParameters @{'environment'='staging'; 'deployRegion'='eastus'}

4. With variables:
   .\trigger-pipeline.ps1 -pat "your-pat-token" -organizationUrl "https://dev.azure.com/yourorg/" -project "YourProject" -pipelineId "123" -variables @{'BuildConfiguration'='Release'; 'Version'='1.2.3'}

5. With stages to skip:
   .\trigger-pipeline.ps1 -pat "your-pat-token" -organizationUrl "https://dev.azure.com/yourorg/" -project "YourProject" -pipelineId "123" -stagesToSkip @('UnitTests', 'SecurityScan')

6. Complete example with all parameters:
   .\trigger-pipeline.ps1 -pat "your-pat-token" -organizationUrl "https://dev.azure.com/yourorg/" -project "YourProject" -pipelineId "123" -refName "refs/heads/release" -templateParameters @{'environment'='production'} -variables @{'Version'='2.0.0'} -stagesToSkip @('DevelopmentTests')
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="Personal Access Token for Azure DevOps")]
    [string]$pat,
    
    [Parameter(Mandatory=$true, HelpMessage="Azure DevOps organization URL")]
    [string]$organizationUrl = "https://dev.azure.com/jjohanning0798/",
    
    [Parameter(Mandatory=$true, HelpMessage="Azure DevOps project name")]
    [string]$project = "PartsUnlimited",
    
    [Parameter(Mandatory=$true, HelpMessage="Pipeline ID to trigger")]
    [string]$pipelineId = "77",
    
    [Parameter(HelpMessage="Git branch/ref to use (e.g., refs/heads/main, refs/heads/develop)")]
    [string]$refName = "refs/heads/main",
    
    [Parameter(HelpMessage="Template parameters as hashtable (e.g., @{'param1'='value1'; 'param2'='value2'})")]
    [hashtable]$templateParameters = @{},
    
    [Parameter(HelpMessage="Pipeline variables as hashtable (e.g., @{'var1'='value1'; 'var2'='value2'})")]
    [hashtable]$variables = @{},
    
    [Parameter(HelpMessage="Stages to skip as array (e.g., @('stage1', 'stage2'))")]
    [string[]]$stagesToSkip = @()
)

$headers = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)")) }

function Run-Pipeline {
    param(
        [string]$pipelineId,
        [string]$organizationUrl,
        [string]$project,
        [string]$refName,
        [hashtable]$templateParameters,
        [hashtable]$variables,
        [string[]]$stagesToSkip
    )

    $postUrl = "$organizationUrl$project/_apis/pipelines/$pipelineId/runs?api-version=6.0-preview.1"
    
    # Build the request body dynamically
    $requestBody = @{
        stagesToSkip = $stagesToSkip
        resources = @{
            repositories = @{
                self = @{
                    refName = $refName
                }
            }
        }
    }
    
    # Add template parameters if provided
    if ($templateParameters.Count -gt 0) {
        $requestBody.templateParameters = $templateParameters
    }
    
    # Add variables if provided
    if ($variables.Count -gt 0) {
        $variablesFormatted = @{}
        foreach ($key in $variables.Keys) {
            $variablesFormatted[$key] = @{ value = $variables[$key] }
        }
        $requestBody.variables = $variablesFormatted
    }
    
    $postBody = $requestBody | ConvertTo-Json -Depth 5

    try {
        Write-Host "Creating pipeline run for ID $pipelineId on branch $refName" -ForegroundColor Yellow
        Write-Host "Request URL: $postUrl" -ForegroundColor Gray
        Write-Host "Request Body:" -ForegroundColor Gray
        Write-Host $postBody -ForegroundColor Gray
        
        $res = Invoke-WebRequest -Method POST -Headers $headers -Uri $postUrl -Body $postBody -ContentType "application/json" | ConvertFrom-Json -Depth 5
        if ($res.url -ne "") {
            Write-Host "Pipeline triggered successfully!" -ForegroundColor Green
            Write-Host ("Pipeline URL: {0}" -f $res.url) -ForegroundColor Blue
            Write-Host ("Run ID: {0}" -f $res.id) -ForegroundColor Blue
        }
        else {
            Write-Host "Pipeline trigger failed - check your PAT and permissions" -ForegroundColor Red
        }
    }
    catch {
        if($_.Exception.Message -like "Conversion from JSON failed*"){
            Write-Host "Conversion from JSON failed - check the validity of the PAT" -ForegroundColor Red
        }
        else {
            $code = $_.Exception.Response.StatusCode.Value__
            Write-Host "Response code: $($code)" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Validate inputs
if ([string]::IsNullOrWhiteSpace($pat)) {
    Write-Host "Error: PAT (Personal Access Token) is required" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($organizationUrl)) {
    Write-Host "Error: Organization URL is required" -ForegroundColor Red
    exit 1
}

# Ensure organizationUrl always ends with a slash
if (-not $organizationUrl.EndsWith('/')) {
    $organizationUrl = $organizationUrl + '/'
}

if ([string]::IsNullOrWhiteSpace($project)) {
    Write-Host "Error: Project name is required" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($pipelineId)) {
    Write-Host "Error: Pipeline ID is required" -ForegroundColor Red
    exit 1
}

# Display configuration
Write-Host "Pipeline Trigger Configuration:" -ForegroundColor Cyan
Write-Host "  Organization: $organizationUrl" -ForegroundColor White
Write-Host "  Project: $project" -ForegroundColor White
Write-Host "  Pipeline ID: $pipelineId" -ForegroundColor White
Write-Host "  Branch/Ref: $refName" -ForegroundColor White
if ($templateParameters.Count -gt 0) {
    Write-Host "  Template Parameters: $($templateParameters.Keys -join ', ')" -ForegroundColor White
}
if ($variables.Count -gt 0) {
    Write-Host "  Variables: $($variables.Keys -join ', ')" -ForegroundColor White
}
if ($stagesToSkip.Count -gt 0) {
    Write-Host "  Stages to Skip: $($stagesToSkip -join ', ')" -ForegroundColor White
}
Write-Host ""

Run-Pipeline -pipelineId $pipelineId -organizationUrl $organizationUrl -project $project -refName $refName -templateParameters $templateParameters -variables $variables -stagesToSkip $stagesToSkip
