#!/bin/bash

# Retrieves the pipeline build definition.

# Function to display usage
usage() {
    echo "Usage: $0 -o <organization> -p <project> -d <definition_id> [-t <token>]"
    echo "  -o, --organization   Azure DevOps organization name"
    echo "  -p, --project        Azure DevOps project name"
    echo "  -d, --definition     Pipeline definition ID"
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
if [[ -z "$ORGANIZATION" || -z "$PROJECT" || -z "$DEFINITION_ID" ]]; then
    echo "Error: Missing required parameters"
    usage
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

# Make API call
echo "Fetching pipeline definition from: $API_URL"
curl -s -H "Authorization: Basic $(echo -n ":$TOKEN" | base64)" \
     -H "Content-Type: application/json" \
     "$API_URL"
