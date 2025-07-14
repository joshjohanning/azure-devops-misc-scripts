# powershell

## scripts

### cleanup-users.ps1

Removes users in Azure DevOps who no longer appear in Azure Active Directory.

### collection-reconnaissance.ps1

Export a list of:

- Team Projects
- last work item modified and created in this project
- how many repos
- who was the last committer,
- tfvc details
- and test artifacts

### create-iterations.ps1

This script creates iterations in Azure DevOps based on a CSV file input.

### rename-repositories.ps1

This script renames repositories in Azure DevOps based on a CSV file input.

### reparent-workitems.ps1

This script reparents work items in Azure DevOps.

### rewire-azure-devops-pipeline-to-azure-devops-repo.ps1

Rewires an Azure DevOps pipeline to an Azure DevOps repository (useful if unwiring a pipeline that was rewired to a GitHub repo with `gh ado2gh rewire-pipeline`).

### trigger-pipeline-with-variables-or-parameters-simple.ps1

A simple (non-parameterized) script to trigger an Azure DevOps pipeline with variables or parameters. Use the `trigger-pipeline.ps1` script for more realistic scenarios.

### trigger-pipeline.ps1

This script triggers an Azure DevOps pipeline with optional parameters for branch, variables, etc.
