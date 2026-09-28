$groupNames = @(
    "All Employees",
    "IT Team",
    "HR Team",
    "Finance Team",
    "Sales Team",
    "Engineering Team"
)

foreach ($groupName in $groupNames) {

    $existingGroup = Get-MgGroup -Filter "displayName eq '$groupName'"

    if ($existingGroup) {
        Write-Host "$groupName already exists."
    }
    else {
        New-MgGroup `
            -DisplayName $groupName `
            -MailEnabled:$false `
            -MailNickname ($groupName -replace " ","") `
            -SecurityEnabled:$true

        Write-Host "$groupName created."
    }
}