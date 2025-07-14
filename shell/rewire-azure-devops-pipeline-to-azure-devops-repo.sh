#!/bin/bash

# Rewires an Azure DevOps pipeline to an Azure DevOps repository (useful if unwiring a pipeline that was rewired to a GitHub repo with `gh ado2gh rewire-pipeline`).

# Function to display usage
usage() {
    echo "Usage: $0 -o <organization> -p <project> -d <definition_id> -r <repo_name> [-t <token>] [-rp <repo_project>]"
    echo "  -o, --organization   Azure DevOps organization name"
    echo "  -p, --project        Azure DevOps project name"
    echo "  -d, --definition     Pipeline definition ID"
    echo "  -r, --repo           Azure DevOps repository name"
    echo "  -rp, --repo-project  Repository project (optional, defaults to pipeline project)"
    echo "  -t, --token          Personal Access Token (optional, can use AZURE_DEVOPS_TOKEN env var)"
    echo "  -h, --help           Show this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--organization)
            ORGANIZATION="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT="$2"
            shift 2
            ;;
        -d|--definition)
            DEFINITION_ID="$2"
            shift 2
            ;;
        -r|--repo)
            REPO_NAME="$2"
            shift 2
            ;;
        -rp|--repo-project)
            REPO_PROJECT="$2"
            shift 2
            ;;
        -t|--token)
            TOKEN="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option $1"
            usage
            ;;
    esac
done

# Check required parameters
if [[ -z "$ORGANIZATION" || -z "$PROJECT" || -z "$DEFINITION_ID" || -z "$REPO_NAME" ]]; then
    echo "Error: Missing required parameters"
    usage
fi

# Default repo project to pipeline project if not specified
if [[ -z "$REPO_PROJECT" ]]; then
    REPO_PROJECT="$PROJECT"
fi

# Use token from parameter or environment variable
if [[ -z "$TOKEN" ]]; then
    TOKEN="$AZURE_DEVOPS_TOKEN"
fi

if [[ -z "$TOKEN" ]]; then
    echo "Error: No authentication token provided. Set AZURE_DEVOPS_TOKEN environment variable or use -t option"
    exit 1
fi

# Construct API URL
API_URL="https://dev.azure.com/${ORGANIZATION}/${PROJECT}/_apis/build/definitions/${DEFINITION_ID}?api-version=6.0"

# First, get the current pipeline definition
echo "Fetching current pipeline definition..."
CURRENT_DEF=$(curl -s -H "Authorization: Basic $(echo -n ":$TOKEN" | base64)" \
     -H "Content-Type: application/json" \
     "$API_URL")

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to fetch pipeline definition"
    exit 1
fi

# Create temporary file for modified definition
TEMP_FILE=$(mktemp)

# Update the repository section to use Azure DevOps
echo "$CURRENT_DEF" | jq --arg repo_name "$REPO_NAME" \
                          --arg repo_project "$REPO_PROJECT" \
                          --arg org "$ORGANIZATION" \
    '.repository = {
        "id": $repo_name,
        "name": $repo_name,
        "url": ("https://dev.azure.com/" + $org + "/" + $repo_project + "/_git/" + $repo_name),
        "type": "TfsGit",
        "defaultBranch": "refs/heads/main",
        "clean": "false",
        "checkoutSubmodules": false
    } |
    .triggers = [
        {
            "branchFilters": ["+refs/heads/main"],
            "pathFilters": [],
            "batchChanges": false,
            "maxConcurrentBuildsPerBranch": 1,
            "triggerType": "continuousIntegration"
        }
    ]' > "$TEMP_FILE"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to modify pipeline definition. Make sure jq is installed."
    rm -f "$TEMP_FILE"
    exit 1
fi

# Update the pipeline definition
echo "Updating pipeline definition to use Azure DevOps repository: $REPO_NAME"
RESPONSE=$(curl -s -X PUT \
     -H "Authorization: Basic $(echo -n ":$TOKEN" | base64)" \
     -H "Content-Type: application/json" \
     -d @"$TEMP_FILE" \
     "$API_URL")

# Clean up temporary file
rm -f "$TEMP_FILE"

# Check if update was successful
if echo "$RESPONSE" | jq -e '.repository.type == "TfsGit"' > /dev/null 2>&1; then
    echo "Pipeline repository successfully updated to Azure DevOps!"
    echo "New repository: $REPO_NAME"
else
    echo "Error: Failed to update pipeline repository"
    echo "Response: $RESPONSE"
    exit 1
fi
