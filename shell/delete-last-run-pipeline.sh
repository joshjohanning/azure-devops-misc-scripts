#!/bin/bash

# Deletes the most recently run pipeline in a specified Azure DevOps project (for cleaning up a test)

AZURE_DEVOPS_EXT_PAT=your_pat 
az pipelines delete --org $YOUR_ORG --project $YOUR_PROJECT --id $(az pipelines list --org $YOUR_ORG --project $YOUR_PROJECT | jq -r .[].id)
