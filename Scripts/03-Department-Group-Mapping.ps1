# Department-to-Entra group mapping
$DepartmentGroups = @{
    "IT"          = "IT Team"
    "HR"          = "HR Team"
    "Finance"     = "Finance Team"
    "Sales"       = "Sales Team"
    "Engineering" = "Engineering Team"
}

# Test department-to-group mapping against HR data
foreach ($Hire in $NewHires) {
    $Department = $Hire.Department
    $GroupName = $DepartmentGroups[$Department]

    Write-Host "$($Hire.FirstName) $($Hire.LastName) -> $GroupName"
}