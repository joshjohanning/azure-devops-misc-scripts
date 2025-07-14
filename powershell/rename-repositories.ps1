# Rename Repositories in Azure DevOps

<#
Set up your rename-repositories.csv like:

OldRepoName,NewRepoName
Repo4,Repo1
Repo5,Repo2
Repo6,Repo3

#>

[CmdletBinding()]
param (
    [string]$OrganizationName,
    [string]$ProjectName,
    [parameter (Mandatory = $true)][string]$PersonalAccessToken
)

if ([String]::IsNullOrEmpty($PersonalAccessToken)) { exit }

echo $($PersonalAccessToken) | az devops login
az devops configure --defaults organization=https://dev.azure.com/$($OrganizationName) project=$($ProjectName)

$csv = Import-Csv ./rename-repositories.csv | ForEach-Object {
    Write-Host "Renaming $($_.OldRepoName) to $($_.NewRepoName)"
    az repos update --repository $($_.OldRepoName) --name $($_.NewRepoName)
}