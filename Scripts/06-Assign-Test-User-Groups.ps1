# Find the IT Team group
$ITGroup = Get-MgGroup -Filter "displayName eq 'IT Team'"

# Add Andrew Smith to the IT Team
New-MgGroupMemberByRef `
    -GroupId $ITGroup.Id `
    -OdataId "https://graph.microsoft.com/v1.0/directoryObjects/$($CreatedUser.Id)"
