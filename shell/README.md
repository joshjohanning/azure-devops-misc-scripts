# shell

## scripts

### delete-last-run-pipeline.sh

Deletes the most recently run pipeline in a specified Azure DevOps project (for cleaning up a test).

### delete-process-template.sh

Deletes a process template in Azure DevOps. Note: This won't delete the process template if there are any projects currently using it.

### get-pipeline.sh

Retrieves the pipeline build definition.

### push-to-nuget-repository.sh

Pushes a package to a NuGet repository.

### rewire-azure-devops-pipeline-to-azure-devops-repo.sh

Rewires an Azure DevOps pipeline to an Azure DevOps repository (useful if unwiring a pipeline that was rewired to a GitHub repo with `gh ado2gh rewire-pipeline`).
