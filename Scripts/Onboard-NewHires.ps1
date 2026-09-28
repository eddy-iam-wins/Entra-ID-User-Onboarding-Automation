# ============================================
# Entra ID Automated User Onboarding
# ============================================



Write-Host "Entra ID User Onboarding Automation"
Write-Host "===================================="


# ============================================
# Import required Microsoft Graph modules
# ============================================
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups



# ============================================
# Initialize Onboarding Results
# ============================================

$OnboardingResults = @()



# ============================================
# Discover Default Entra ID Domain
# ============================================

$DefaultDomain = (
    Get-MgDomain |
    Where-Object { $_.IsDefault -eq $true }
).Id

if ([string]::IsNullOrWhiteSpace($DefaultDomain)) {
    throw "Unable to determine the default Entra ID domain."
}

Write-Host "Default Entra ID domain: $DefaultDomain"





# ============================================
# Import HR New-Hire Data
# ============================================

$CsvPath = Join-Path `
    ([Environment]::GetFolderPath("Desktop")) `
    "Entra-ID-User-Onboarding\Sample-Data\NewHires.csv"

$NewHires = Import-Csv $CsvPath

Write-Host ""
Write-Host "Imported $($NewHires.Count) new-hire records."

# ============================================
# Validate Required Fields
# ============================================

$RequiredColumns = @(
    "FirstName",
    "LastName",
    "Department",
    "JobTitle",
    "StartDate"
)

$ValidationErrors = @()

foreach ($Hire in $NewHires) {

    foreach ($Column in $RequiredColumns) {

        if ([string]::IsNullOrWhiteSpace($Hire.$Column)) {

            $ValidationErrors += `
                "$($Hire.FirstName) $($Hire.LastName): Missing $Column"
        }
    }
}

if ($ValidationErrors.Count -gt 0) {

    Write-Host ""
    Write-Host "CSV validation failed:" -ForegroundColor Red

    $ValidationErrors | ForEach-Object {
        Write-Host $_ -ForegroundColor Red
    }

    throw "Onboarding stopped because the HR CSV contains validation errors."
}

Write-Host "CSV validation passed."








# ============================================
# Department-to-Group Mapping
# ============================================

$DepartmentGroups = @{
    "IT"          = "IT Team"
    "HR"          = "HR Team"
    "Finance"     = "Finance Team"
    "Sales"       = "Sales Team"
    "Engineering" = "Engineering Team"
}

Write-Host ""
Write-Host "Department-to-Group Mapping:"
Write-Host "-----------------------------"

foreach ($Hire in $NewHires) {

    $Department = $Hire.Department
    $GroupName = $DepartmentGroups[$Department]

    if ([string]::IsNullOrWhiteSpace($GroupName)) {
        Write-Host "No group mapping found for department: $Department" -ForegroundColor Yellow
    }
    else {
        Write-Host "$($Hire.FirstName) $($Hire.LastName) -> $GroupName"
    }
}





# ============================================
# User Provisioning
# ============================================

foreach ($Hire in $NewHires) {

    $FirstName = $Hire.FirstName.Trim()
    $LastName = $Hire.LastName.Trim()
    $DisplayName = "$FirstName $LastName"
    $Department = $Hire.Department.Trim()
    $JobTitle = $Hire.JobTitle.Trim()
    $City = $Hire.Location.Trim()

    $UserPrincipalName = "$($FirstName.ToLower()).$($LastName.ToLower())@$DefaultDomain"

    # Check whether the user already exists
    $ExistingUser = Get-MgUser `
        -Filter "userPrincipalName eq '$UserPrincipalName'"

if ($ExistingUser) {

    Write-Host ""
    Write-Host "Skipping existing user: $UserPrincipalName" -ForegroundColor Yellow

    $ExistingGroups = Get-MgUserMemberOf -UserId $ExistingUser.Id |
        ForEach-Object {
            Get-MgGroup -GroupId $_.Id -Property DisplayName
        } |
        Select-Object -ExpandProperty DisplayName

    $ExistingGroupList = $ExistingGroups -join ", "

    $OnboardingResults += [PSCustomObject]@{
        DisplayName       = $DisplayName
        UserPrincipalName = $UserPrincipalName
        Department        = $Department
        JobTitle          = $JobTitle
        Groups            = $ExistingGroupList
        Status            = "Already Exists"
    }

    continue
}

 # Generate a temporary password in memory
$Uppercase = "ABCDEFGHJKLMNPQRSTUVWXYZ"
$Lowercase = "abcdefghijkmnopqrstuvwxyz"
$Numbers = "23456789"

$TemporaryPassword = (
    ($Uppercase | ForEach-Object { $_[(Get-Random -Maximum $_.Length)] }) +
    ($Lowercase | ForEach-Object { $_[(Get-Random -Maximum $_.Length)] }) +
    ($Numbers | ForEach-Object { $_[(Get-Random -Maximum $_.Length)] }) +
    (-join ((48..57) + (65..90) + (97..122) |
        Get-Random -Count 9 |
        ForEach-Object {[char]$_}))
)

$TemporaryPassword = -join (
    $TemporaryPassword.ToCharArray() |
    Sort-Object { Get-Random }
    )

    # Create password profile
    $PasswordProfile = @{
        Password = $TemporaryPassword
        ForceChangePasswordNextSignIn = $true
    }



# ============================================
# Create Entra ID User
# ============================================

try {

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
        -PasswordProfile $PasswordProfile `
        -ErrorAction Stop

    Write-Host ""
    Write-Host "Created user: $DisplayName" -ForegroundColor Green
}
catch {

    Write-Host ""
    Write-Host "Failed to create user: $DisplayName" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    $OnboardingResults += [PSCustomObject]@{
        DisplayName       = $DisplayName
        UserPrincipalName = $UserPrincipalName
        Department        = $Department
        JobTitle          = $JobTitle
        Groups            = ""
        Status            = "Failed"
    }

    continue
}

    




# ============================================
# Track Group Assignments
# ============================================

$AssignedGroups = @()
$OnboardingStatus = "Created"


# ============================================
# Assign All Employees Group
# ============================================

$AllEmployeesGroup = Get-MgGroup `
    -Filter "displayName eq 'All Employees'"

if (-not $AllEmployeesGroup) {

    Write-Host "All Employees group was not found." -ForegroundColor Red
}
else {

    try {

        New-MgGroupMemberByRef `
            -GroupId $AllEmployeesGroup.Id `
            -OdataId "https://graph.microsoft.com/v1.0/directoryObjects/$($CreatedUser.Id)" `
            -ErrorAction Stop

        $AssignedGroups += "All Employees"

        Write-Host "Added $DisplayName to All Employees." -ForegroundColor Green
    }
    catch {

        Write-Host "Failed to add $DisplayName to All Employees." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        $OnboardingStatus = "Created - Group Assignment Partial Failure"
    }
}


# ============================================
# Assign Department Group
# ============================================

$GroupName = $DepartmentGroups[$Department]

if ([string]::IsNullOrWhiteSpace($GroupName)) {

    Write-Host "No group mapping found for department: $Department" -ForegroundColor Yellow
}
else {

    $DepartmentGroup = Get-MgGroup `
        -Filter "displayName eq '$GroupName'"

    if (-not $DepartmentGroup) {

        Write-Host "Department group not found: $GroupName" -ForegroundColor Red
    }
    else {

        try {

            New-MgGroupMemberByRef `
                -GroupId $DepartmentGroup.Id `
                -OdataId "https://graph.microsoft.com/v1.0/directoryObjects/$($CreatedUser.Id)" `
                -ErrorAction Stop

            $AssignedGroups += $GroupName

            Write-Host "Added $DisplayName to $GroupName." -ForegroundColor Green
        }
        catch {

            Write-Host "Failed to add $DisplayName to $GroupName." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red

            $OnboardingStatus = "Created - Group Assignment Partial Failure"
        }
    }
}
 

 # ============================================
 # Record Onboarding Result
 # ============================================

    $OnboardingResults += [PSCustomObject]@{
        DisplayName       = $DisplayName
        UserPrincipalName = $UserPrincipalName
        Department        = $Department
        JobTitle          = $JobTitle
        Groups            = ($AssignedGroups -join ", ")
        Status            = $OnboardingStatus
    }

}




# ============================================
# Export Onboarding Report
# ============================================

$ReportPath = Join-Path `
    ([Environment]::GetFolderPath("Desktop")) `
    "Entra-ID-User-Onboarding\Reports\Onboarding-Report.csv"

$OnboardingResults |
    Export-Csv `
        -Path $ReportPath `
        -NoTypeInformation

Write-Host ""
Write-Host "Onboarding report created:" -ForegroundColor Green
Write-Host $ReportPath