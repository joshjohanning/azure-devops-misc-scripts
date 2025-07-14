<#
.SYNOPSIS
    Rewires an Azure DevOps pipeline to an Azure DevOps repository.

.DESCRIPTION
    This script rewires an Azure DevOps pipeline to an Azure DevOps repository. 
    This is useful if unwiring a pipeline that was rewired to a GitHub repo with `gh ado2gh rewire-pipeline`.

.PARAMETER Organization
    Azure DevOps organization name (required)

.PARAMETER Project
    Azure DevOps project name (required)

.PARAMETER DefinitionId
    Pipeline definition ID (required)

.PARAMETER RepoName
    Azure DevOps repository name (required)

.PARAMETER RepoProject
    Repository project (optional, defaults to pipeline project)

.PARAMETER Token
    Personal Access Token (optional, can use AZURE_DEVOPS_TOKEN env var)

.EXAMPLE
    .\rewire-azure-devops-pipeline-to-azure-devops-repo.ps1 -Organization "myorg" -Project "myproject" -DefinitionId "123" -RepoName "myrepo" -Token "pat-token"

.EXAMPLE
    .\rewire-azure-devops-pipeline-to-azure-devops-repo.ps1 -Organization "myorg" -Project "myproject" -DefinitionId "123" -RepoName "myrepo" -RepoProject "otherproject"
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="Azure DevOps organization name")]
    [string]$Organization,
    
    [Parameter(Mandatory=$true, HelpMessage="Azure DevOps project name")]
    [string]$Project,
    
    [Parameter(Mandatory=$true, HelpMessage="Pipeline definition ID")]
    [string]$DefinitionId,
    
    [Parameter(Mandatory=$true, HelpMessage="Azure DevOps repository name")]
    [string]$RepoName,
    
    [Parameter(HelpMessage="Repository project (optional, defaults to pipeline project)")]
    [string]$RepoProject,
    
    [Parameter(HelpMessage="Personal Access Token (optional, can use AZURE_DEVOPS_TOKEN env var)")]
    [string]$Token
)

# Default repo project to pipeline project if not specified
if ([string]::IsNullOrWhiteSpace($RepoProject)) {
    $RepoProject = $Project
}

# Use token from parameter or environment variable
if ([string]::IsNullOrWhiteSpace($Token)) {
    $Token = $env:AZURE_DEVOPS_TOKEN
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Host "Error: No authentication token provided. Set AZURE_DEVOPS_TOKEN environment variable or use -Token parameter" -ForegroundColor Red
    exit 1
}

# Construct API URL
$ApiUrl = "https://dev.azure.com/$Organization/$Project/_apis/build/definitions/$DefinitionId" + "?api-version=6.0"

# Create authorization header
$EncodedToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Token"))
$Headers = @{
    Authorization = "Basic $EncodedToken"
    'Content-Type' = 'application/json'
}

try {
    # First, get the current pipeline definition
    Write-Host "Fetching current pipeline definition..." -ForegroundColor Yellow
    $CurrentDef = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers -Method GET
    
    Write-Host "Current pipeline found: $($CurrentDef.name)" -ForegroundColor Green
    
    # Update the repository section to use Azure DevOps
    $CurrentDef.repository = @{
        id = $RepoName
        name = $RepoName
        url = "https://dev.azure.com/$Organization/$RepoProject/_git/$RepoName"
        type = "TfsGit"
        defaultBranch = "refs/heads/main"
        clean = "false"
        checkoutSubmodules = $false
    }
    
    # Update triggers for CI
    $CurrentDef.triggers = @(
        @{
            branchFilters = @("+refs/heads/main")
            pathFilters = @()
            batchChanges = $false
            maxConcurrentBuildsPerBranch = 1
            triggerType = "continuousIntegration"
        }
    )
    
    # Convert to JSON
    $RequestBody = $CurrentDef | ConvertTo-Json -Depth 10
    
    # Update the pipeline definition
    Write-Host "Updating pipeline definition to use Azure DevOps repository: $RepoName" -ForegroundColor Yellow
    Write-Host "Target repository URL: https://dev.azure.com/$Organization/$RepoProject/_git/$RepoName" -ForegroundColor Gray
    
    $Response = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers -Method PUT -Body $RequestBody
    
    # Check if update was successful
    if ($Response.repository.type -eq "TfsGit") {
        Write-Host "Pipeline repository successfully updated to Azure DevOps!" -ForegroundColor Green
        Write-Host "Pipeline Name: $($Response.name)" -ForegroundColor Blue
        Write-Host "New Repository: $RepoName" -ForegroundColor Blue
        Write-Host "Repository Type: $($Response.repository.type)" -ForegroundColor Blue
        Write-Host "Repository URL: $($Response.repository.url)" -ForegroundColor Blue
    }
    else {
        Write-Host "Warning: Pipeline updated but repository type is not TfsGit" -ForegroundColor Yellow
        Write-Host "Repository Type: $($Response.repository.type)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Error: Failed to update pipeline repository" -ForegroundColor Red
    Write-Host "Error Details: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.Value__
        Write-Host "HTTP Status Code: $statusCode" -ForegroundColor Red
        
        if ($statusCode -eq 401) {
            Write-Host "Authentication failed. Please check your Personal Access Token." -ForegroundColor Red
        }
        elseif ($statusCode -eq 403) {
            Write-Host "Access denied. Please ensure your token has the necessary permissions." -ForegroundColor Red
        }
        elseif ($statusCode -eq 404) {
            Write-Host "Pipeline definition not found. Please check the organization, project, and definition ID." -ForegroundColor Red
        }
    }
    
    exit 1
}
