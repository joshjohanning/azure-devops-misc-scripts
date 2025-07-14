#!/bin/bash

# note - this won't delete the process template if there are any project(s) currently using it

org="jjohanning0569"
pat=""
processToDelete="roi"

count=0

output=$(curl -s -u :${pat} "https://dev.azure.com/${org}/_apis/work/processes?api-version=6.1-preview.2" | jq '.value')
for row in $(echo "${output}" | jq -r '.[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }

    if [[ $(_jq '.name') = "${processToDelete}" ]]; then
        id=$(echo $(_jq '.typeId'))
        count=1
    fi

done

if [[ ${count} == 1 ]]; then
    echo "ID to delete: $id"
    curl -s -u :${pat} -X DELETE "https://dev.azure.com/${org}/_apis/work/processes/${id}?api-version=6.1-preview.2"
else
    echo "process template not found: ${processToDelete}"
    exit -1
fi
