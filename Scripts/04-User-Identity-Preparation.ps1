# Retrieve the tenant's default domain
$DefaultDomain = (Get-MgDomain |
    Where-Object {$_.IsDefault -eq $true}).Id

# Generate UPNs for the HR records
foreach ($Hire in $NewHires) {

    $FirstName = $Hire.FirstName.ToLower()
    $LastName = $Hire.LastName.ToLower()

    $UserPrincipalName = "$FirstName.$LastName@$DefaultDomain"

    Write-Host "$($Hire.FirstName) $($Hire.LastName) -> $UserPrincipalName"
}