<# Resources:
    https://stackoverflow.com/questions/60852825/azure-devops-yaml-pipeline-parameters-not-working-from-rest-api-trigger
    https://stackoverflow.com/questions/34343084/start-a-build-and-passing-variables-through-azure-devops-rest-api
    https://stackoverflow.com/questions/63654387/azure-rest-api-for-running-builds-or-pipelines
#>

param(
    [Parameter(Mandatory=$true)]$pat = "",
    $url = "https://dev.azure.com/jjohanning0798/",
    $pipelineId = "77"
)

$headers = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)")) }

function Run-Pipeline {
    param(
        $pipelineId
    )

    $postUrl = $url + "PartsUnlimited/_apis/pipelines/$pipelineId/runs?api-version=6.0-preview.1"
    $postBody = '
    { 
        "stagesToSkip": [],
        "resources": {
            "repositories": {
                "self": {
                    "refName": "refs/heads/master"
                }
            }
        },
        "templateParameters": {
            "testParam": "new value for parameter"
        },
        "variables": {
            "testVar": { 
                "value": "new value for variable"
            }
        }
    }
    '

    try {
        Write-Host "Creating pipeline run for ID $pipelineId" -ForegroundColor Yellow
        $res = Invoke-WebRequest -Method POST -Headers $headers -Uri $postUrl -Body $postBody -ContentType "application/json" | ConvertFrom-Json -Depth 5
        if ($res.url -ne "") {
            write-host ("Url: {0}" -f $res.url) -ForegroundColor Blue
        }
        else {
            Write-Host "Bad PAT" -ForegroundColor Red
        }
    }
    catch {
        if($_.Exception.Message -like "Conversion from JSON failed*"){
            Write-Host "Conversion from JSON failed - check the validity of the PAT" -ForegroundColor Red
        }
        else {
            $code = $_.Exception.Response.StatusCode.Value__
            Write-Host "Response code: $($code)" -ForegroundColor Red
            $_.Exception.Message
        }
    }
}

if ($pat -ne "") {
    Run-Pipeline -pipelineId $pipelineId
}
else {
    Write-Host "PAT is empty" -ForegroundColor Red
}