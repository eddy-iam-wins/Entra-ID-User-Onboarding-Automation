# Import HR new-hire data
$NewHires = Import-Csv ".\Sample-Data\NewHires.csv"

# Display imported employees
$NewHires | Format-Table

# Validate required fields
$RequiredColumns = @(
    "FirstName",
    "LastName",
    "Department",
    "JobTitle",
    "StartDate"
)

foreach ($Hire in $NewHires) {
    foreach ($Column in $RequiredColumns) {
        if ([string]::IsNullOrWhiteSpace($Hire.$Column)) {
            Write-Host "Missing $Column for $($Hire.FirstName) $($Hire.LastName)"
        }
    }
}