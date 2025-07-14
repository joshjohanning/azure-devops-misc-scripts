# The iteration CSV should look something like this (no header):

# 20.6\1\1
# 20.6\1\2
# 20.6\2\1
# 20.6\2\2
# 19.1
# 19.1\1
# 19.1\1\2
# 19.3
# 16.4

# We can either run this on Friday or you can run this before we meet to create the nodes.

# Generate a PAT for your username and create a powershell variable for it:
# $pat = “mylongpat”

# To run the command, use this format:
# .\create-iterations.ps1 -pat $pat -csvFile .\Iterations.csv -teamName "The Elders"
# .\create-iterations.ps1 -pat $pat -csvFile .\Iterations.csv -teamName "Hotshots"

param(
    $pat,
    $url = "http://howitzer:8080/DefaultCollection/",
    $csvFile,
    $teamName
)

$headers = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)")) }

function New-Node {
    param(
        $Name,
        $ParentPath
    )

    $postUrl = $url + "Demos/_apis/wit/classificationnodes/Iterations/$($ParentPath)?api-version=5.1"
    $postBody = @{
        name = $Name
    } | ConvertTo-Json -Depth 5

    try {
        Write-Host "Creating node $Name under $ParentPath" -ForegroundColor Yellow
        $res = Invoke-WebRequest -Method POST -Headers $headers -Uri $postUrl -Body $postBody -ContentType "application/json"
    }
    catch {
        $code = $_.Exception.Response.StatusCode.Value__
        if ($code -ne 409) { # swallow 409 (Conflict) since the node exists already
            Write-Host "Response code: $($code)" -ForegroundColor Red
            $_.Exception.Message
        }
    }
}

$rows = Import-Csv -Header Path -Path $csvFile
Write-Host "Imported $($paths.length) iterations" -ForegroundColor Yellow

New-Node -Name "$teamName" -ParentPath ""

foreach($row in $rows) {
    $pathParts = $row.Path -split "\\"
    for ($i = 0; $i -lt $pathParts.length; $i++) {
        $node = $pathParts[$i]
        $parent = "$teamName"
        for ($j = 0; $j -le $i - 1; $j++) {
            $parent += "\" + $pathParts[$j]
        }
        New-Node -Name $node -ParentPath $parent
    }
}
