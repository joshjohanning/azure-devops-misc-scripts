###############################################################################################
# Removes users in AzDO who no longer appear in Azure Active Directory
# Pre-reqs: 
#   - Run `az login` before hand to authenticate to proper subscription
#   - If running in AzDO pipeline, use the 'Azure CLI' task to authenticate instead
#
# Output:
#   - user-cleanup-list.csv of users who were removed (or if using -whatIf, users to remove)
###############################################################################################

[CmdletBinding()]
param (
    [string]$OrganizationName,
    [string]$PersonalAccessToken,
    [boolean]$whatif = $true # by default will not remove users unless: "-whatif $true"
)

echo $($PersonalAccessToken) | az devops login
az devops configure --defaults organization=https://dev.azure.com/$($OrganizationName) 

$userList = az devops user list | ConvertFrom-Json

$userCollection = @()

foreach($user in $userList.Items) {
    $aadUser = az ad user show --id $user.user.originId | ConvertFrom-Json
    if($aadUser -eq $null) {
        write-host "$($user.user.mailAddress) is not found in AAD"
        $userCollection += new-object psobject -property @{mailAddress=$user.user.mailAddress;displayName=$user.user.displayName;azdoID=$user.id;aadID="";aadStatus="n/a"}

        if($whatif -eq $false) {
            write-host "Deleting user from AzDO: $($user.user.mailAddress)" -ForegroundColor DarkYellow
            az devops user remove --user $user.id -y
        }
    }
    if($aadUser.accountEnabled -eq $false) {
        write-host "$($user.user.mailAddress) is disabled in AAD"
        $userCollection += new-object psobject -property @{mailAddress=$user.user.mailAddress;displayName=$user.user.displayName;azdoID=$user.id;aadID=$user.user.originId;aadStatus="disabled"}

        if($whatif -eq $false) {
            write-host "Deleting user from AzDO: $($user.user.mailAddress)" -ForegroundColor DarkYellow
            az devops user remove --user $user.id -y
        }
    }
}

$userCollection | Select-Object -Property mailAddress, displayName, azdoID, aadID, aadStatus | Export-CSV -Path .\user-cleanup-list.csv -NoTypeInformation