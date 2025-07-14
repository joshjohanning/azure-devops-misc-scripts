##############################################################
# Export a list of Team Projects, 
# last work item modified and created in this project, 
# how many repos, 
# who was the last committer,
# tfvc details,
# and test artifacts
#
# Expecting CollectionUrl like: http://tfs:8080/tfs/DefaultCollection
#
# Note: You wil see some 409 errors if you are accessing a team project w/o a TFVC repo
#
# Outputs: 
# * ExportSummary-$CollectionName.csv - the summary csv
# * ExportRepos-$CollectionName.csv - a list of repos and summary details
##############################################################

[CmdletBinding()]
param (
    [string]$CollectionUrl,
    [string]$PersonalAccessToken = "" # not needed for on prem w/ basic auth
)

function Invoke-RestCommand {
    param(
        [string]$uri,
        [string]$commandType,
        [string]$contentType = "application/json",
        [string]$jsonBody,
        [string]$personalAccessToken
    )
	
    if ($jsonBody -ne $null) {
        $jsonBody = $jsonBody.Replace("{{","{").Replace("}}","}")
    }

    try {
        if ([String]::IsNullOrEmpty($personalAccessToken)) {
            if ([String]::IsNullOrEmpty($jsonBody)) {
                $response = Invoke-RestMethod -Method $commandType -ContentType $contentType -Uri $uri -UseDefaultCredentials
            }
            else {
                $response = Invoke-RestMethod -Method $commandType -ContentType $contentType -Uri $uri -UseDefaultCredentials -Body $jsonBody
            }
        }
        else {
            $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $personalAccessToken)))
            if ([String]::IsNullOrEmpty($jsonBody)) {            
                $response = Invoke-RestMethod -Method $commandType -ContentType $contentType -Uri $uri -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
            }
            else {
                $response = Invoke-RestMethod -Method $commandType -ContentType $contentType -Uri $uri -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Body $jsonBody
            }
        }

	    if ($response.count) {
		    $response = $response.value
	    }

	    foreach ($r in $response) {
		    if ($r.code -eq "400" -or $r.code -eq "403" -or $r.code -eq "404" -or $r.code -eq "409" -or $r.code -eq "500") {
                Write-Error $_
			    Write-Error -Message "Problem occurred when trying to call rest method."
			    ConvertFrom-Json $r.body | Format-List
		    }
	    }

	    return $response
    }
    catch {
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($result)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Error "Exception Type: $($_.Exception.GetType().FullName)"
        Write-Error $responseBody
        Write-Error $_
        Write-Error -Message "Exception thrown calling REST method."
	}
}
function Get-TeamProjects {
    param
    (
        [string]$CollectionUrl,
        [string]$personalAccessToken
    )

    Write-Host "Getting Team Project List..."

    $uri = "$($CollectionURL)/_apis/projects/?$top=1000?api-version=5.1"

    $results = Invoke-RestCommand -uri $uri -commandType GET -jsonBody $wiqlJson -personalAccessToken $personalAccessToken
    
    return $results
}

function Get-WorkItemsWiql {
    param
    (
        [string]$collectionUrl,
        [string]$projectName,
        [string]$personalAccessToken
    )

    Write-Host "Getting work items from query..."

    $wiql = @{
        "query" = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.AssignedTo],[System.State],[System.Tags],[System.CreatedDate],[System.CreatedBy],[System.ChangedDate],[System.ChangedBy] from WorkItems where [System.TeamProject] = @project ORDER BY [System.CreatedDate] DESC"
    }

    $wiqlJson = $wiql | ConvertTo-Json
    $uri = "$($collectionUrl)/$($projectName)/_apis/wit/wiql?api-version=5.1"
    $results = Invoke-RestCommand -uri $uri -commandType POST -jsonBody $wiqlJson -personalAccessToken $personalAccessToken
    
    return $results.workItems
}

function Get-TestWorkItemsWiql {
    param
    (
        [string]$collectionUrl,
        [string]$projectName,
        [string]$testWorkItemType,
        [string]$personalAccessToken
    )

    Write-Host "Getting work items from query..."

    $wiql = @{
        "query" = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.AssignedTo],[System.State],[System.Tags],[System.CreatedDate],[System.CreatedBy],[System.ChangedDate],[System.ChangedBy] from WorkItems where [System.TeamProject] = @project AND [System.WorkItemType] = '$($testWorkitemType)' ORDER BY [System.CreatedDate] DESC"
    }

    $wiqlJson = $wiql | ConvertTo-Json
    $uri = "$($collectionUrl)/$($projectName)/_apis/wit/wiql?api-version=5.1"
    $results = Invoke-RestCommand -uri $uri -commandType POST -jsonBody $wiqlJson -personalAccessToken $personalAccessToken
    
    return $results.workItems
}

function Get-WorkItem {
    param
    (
        [string]$collectionUrl, 
        [string]$id,
        [string]$personalAccessToken
    )

    Write-Host "Getting work item..."

    $uri = "$($collectionUrl)/$($projectName)/_apis/wit/workitems/$($id)?api-version=5.1"

    $workItem = Invoke-RestCommand -uri $uri -commandType GET -personalAccessToken $personalAccessToken

    return $workItem
}

function Get-GitRepo {
    param
    (
        [string]$collectionUrl,
        [string]$projectName,
        [string]$repoId,
        [string]$personalAccessToken
    )

    Write-Host "Getting git repo..."

    $uri = "$($collectionUrl)/$($projectName)/_apis/git/repositories/$($repoId)?api-version=5.1"

    $repo = Invoke-RestCommand -uri $uri -commandType GET -personalAccessToken $personalAccessToken

    return $repo
}

function Get-GitRepos {
    param
    (
        [string]$collectionUrl,
        [string]$projectName,
        [string]$personalAccessToken
    )

    Write-Host "Getting git repos..."

    $uri = "$($collectionUrl)/$($projectName)/_apis/git/repositories?api-version=5.1"

    $repos = Invoke-RestCommand -uri $uri -commandType GET -personalAccessToken $personalAccessToken

    return $repos
}

function Get-Commits {
    param
    (
        [string]$collectionUrl,
        [string]$projectName,
        [string]$repoId,
        [string]$personalAccessToken
    )

    Write-Host "Getting git commits..."

    $uri = "$($collectionUrl)/$($projectName)/_apis/git/repositories/$($repoId)/commits?api-version=5.1"

    $commits = Invoke-RestCommand -uri $uri -commandType GET -personalAccessToken $personalAccessToken

    return $commits
}

# note - will throw errors if TFVC isn't present
function Get-Changesets {
    param
    (
        [string]$collectionUrl,
        [string]$projectName,
        [string]$personalAccessToken
    )

    Write-Host "Getting tfvc changesets..."

    $uri = "$($collectionUrl)/$($projectName)/_apis/tfvc/changesets?api-version=5.1"

    $changesets = Invoke-RestCommand -uri $uri -commandType GET -personalAccessToken $personalAccessToken

    return $changesets
}

function Get-TestRuns {
    param
    (
        [string]$collectionUrl,
        [string]$projectName,
        [string]$personalAccessToken
    )

    Write-Host "Getting test runs..."

    $uri = "$($collectionUrl)/$($projectName)/_apis/test/runs?api-version=5.1"

    $testRuns = Invoke-RestCommand -uri $uri -commandType GET -personalAccessToken $personalAccessToken

    return $testRuns
}

# create object
$exportList = New-Object System.Collections.ArrayList($null)
$commitList = New-Object System.Collections.ArrayList($null)

# get team projects in collection
$Projects = Get-TeamProjects -CollectionUrl $CollectionUrl

# for each team project
foreach ($project in $Projects) {
    # list for this project
    $commitListMostRecent = New-Object System.Collections.ArrayList($null)

    write-host "Project: $($project.name)"

    # get work items - sorted by most recently created
    $workItemsArray = Get-WorkItemsWiql -CollectionUrl $CollectionUrl -projectName $project.name
    write-host "Most recently created workitem id: $($workItemsArray.Id[0])"

    # get most recently created work items details
    $workItem = Get-WorkItem -CollectionUrl $CollectionUrl -id $workItemsArray.Id[0]

    # get list of git repos
    $repos = Get-GitRepos -CollectionUrl $CollectionUrl -projectName $project.name
    write-host "Git repo count: $($repos.count)"

    # git most recent commit in git repos
    foreach ($repo in $repos) {
        # $repoDetails = Get-GitRepo -CollectionUrl $CollectionUrl -projectName $Project -repoId $repo.id
        $commit = Get-Commits -CollectionUrl $CollectionUrl -projectName $project.name -repoId $repo.id

        # have to do this b/c if there is only 0 or 1 commits, it doesn't make a proper array.
        # more than 1 commits
        if($commit.count -gt 1) {
            $LastCommit = $($commit.commitId[0])
            $LastCommitAuthor = $($commit.author.name[0])
            $LastCommitAuthorEmail = $($commit.author.email[0])
            $LastCommitDate = $($commit.author.date[0])
        }
        # 0 or 1 commits - will be null if 0
        else {
            $LastCommit = $($commit.commitId)
            $LastCommitAuthor = $($commit.author.name)
            $LastCommitAuthorEmail = $($commit.author.email)
            $LastCommitDate = $($commit.author.date)
        }

        # For this project
        $commitListMostRecent.Add([PSCustomObject]@{
            CollectionUrl = $($CollectionUrl)
            ProjectName = $($project.name)
            RepoName = $($repo.name)
            LastCommit = $LastCommit
            LastCommitAuthor = $LastCommitAuthor
            LastCommitAuthorEmail = $LastCommitAuthorEmail
            LastCommitDate = $LastCommitDate
        }) | Out-Null

        # For all projects
        $commitList.Add([PSCustomObject]@{
            CollectionUrl = $($CollectionUrl)
            ProjectName = $($project.name)
            RepoName = $($repo.name)
            GitLatestCommit = $LastCommit
            GitLatestCommitAuthor = $LastCommitAuthor
            GitLatestCommitDate = $LastCommitDate
        }) | Out-Null
    }

    # get most recent commit
    $LastCommit = $commitListMostRecent | Sort-Object GitLatestCommitDate | Select-Object -last 1

    # get tfvc changesets
    $changesets = Get-Changesets -CollectionUrl $CollectionUrl -projectName $project.name

    # get test work items
    $TestCases = Get-TestWorkItemsWiql -CollectionUrl $CollectionUrl -projectName $project.name -testWorkItemType "Test Case"
    $TestPlans = Get-TestWorkItemsWiql -CollectionUrl $CollectionUrl -projectName $project.name -testWorkItemType "Test Plan"
    $TestSuites = Get-TestWorkItemsWiql -CollectionUrl $CollectionUrl -projectName $project.name -testWorkItemType "Test Suite"

    # get test runs
    $testRuns = Get-TestRuns -CollectionUrl $CollectionUrl -projectName $project.name

    # combine everything in a single object
    $exportList.Add([PSCustomObject]@{
        CollectionUrl = $($CollectionUrl)
        ProjectName = $($project.name)
        ProjectState = $($project.state)
        ProjectLastUpdateTime = $($project.lastUpdateTime)
        WorkItemCount = $($workItemsArray.count)
        LatestWorkItemId = $($workItemsArray.Id[0])
        LatestWorkItemTitle = $($workItem.fields.'System.Title')
        LatestWorkItemCreatedDate = $($workItem.fields.'System.CreatedDate')
        LatestWorkItemChangedDate = $($workItem.fields.'System.ChangedDate')
        LatestWorkItemAssignedTo = $($workItem.fields.'System.AssignedTo'.displayName)
        LatestWorkItemCreatedBy = $($workItem.fields.'System.CreatedBy'.displayName)
        LatestWorkItemChangedBy = $($workItem.fields.'System.ChangedBy'.displayName)
        LatestWorkItemWorkItemState = $($workItem.fields.'System.State')
        GitReposCount = $($repos.count)
        GitLatestCommitRepo = $($LastCommit.RepoName)
        GitLatestCommitDate = $($LastCommit.LastCommitDate)
        GitLatestCommitAuthor = $($LastCommit.LastCommitAuthor)
        TfvcLatestChangesetId =  $($changesets.changesetId[0])
        TfvcLatestChangesetAuthor =  $($changesets.author.displayName[0])
        TfvcLatestChangesetEmail =  $($changesets.author.uniqueName[0])
        TfvcLatestChangesetDate =  $($changesets.createdDate[0])
        TestCasesCount = $($TestCases.count)
        TestPlansCount = $($TestPlans.count)
        TestSuitesCount = $($TestSuites.count)
        TestRunsCount = $($TestRuns.count)
    }) | Out-Null

}

# getting collection name from url
$collection = $CollectionUrl.Split('/')[-1]

# exporting summary list
$exportList =  $exportList | Sort-Object -Property ProjectName
$exportList | Export-Csv .\ExportSummary-$collection.csv -NoTypeInformation

# exporting git repo list
$commitList | Export-Csv .\ExportRepos-$collection.csv -NoTypeInformation