# Generate temporary password during the session
$TemporaryPassword = -join (
    (48..57) + (65..90) + (97..122) |
    Get-Random -Count 12 |
    ForEach-Object {[char]$_}
)

# Prepare test employee
$TestHire = $NewHires[0]

$FirstName = $TestHire.FirstName
$LastName = $TestHire.LastName
$DisplayName = "$FirstName $LastName"
$Department = $TestHire.Department
$JobTitle = $TestHire.JobTitle
$City = $TestHire.Location

$UserPrincipalName = "$($FirstName.ToLower()).$($LastName.ToLower())@$DefaultDomain"

# Create password profile
$PasswordProfile = @{
    Password = $TemporaryPassword
    ForceChangePasswordNextSignIn = $true
}

# Create Entra user
$CreatedUser = New-MgUser `
    -AccountEnabled:$true `
    -DisplayName $DisplayName `
    -GivenName $FirstName `
    -Surname $LastName `
    -UserPrincipalName $UserPrincipalName `
    -MailNickname "$($FirstName.ToLower()).$($LastName.ToLower())" `
    -Department $Department `
    -JobTitle $JobTitle `
    -City $City `
    -UsageLocation "US" `
    -PasswordProfile $PasswordProfile

# Verify created user
$CreatedUser |
    Select-Object Id, DisplayName, UserPrincipalName, Department, JobTitle