# Read configuration from JSON file & import
$configPath = "Infrastructure as Code (IaC)/Security Groups/JSON/create-security-groups.config.json"
$jsonContent = Get-Content -Raw -Path $configPath
$jsonConfig = ConvertFrom-Json $jsonContent

# Access configuration variables
$tenantId = $jsonConfig.tenantId
$subscriptionId = $jsonConfig.subscriptionId
$csvFilePath = $jsonConfig.csvFilePath
$jsonDataPaths = $jsonConfig.jsonDataPaths  # Array of paths to JSON files containing subscription data

# Ensure Az module is installed
if (-not (Get-Module -ListAvailable -Name Az)) {
    Write-Host "Installing Az module..."
    Install-Module -Name Az -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
    Write-Host "Az module installed successfully."
} else {
    Write-Host "Az module is already installed."
}

# Import required modules
foreach ($module in @('az.accounts', 'az.resources')) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        Import-Module $module
        Write-Host "$module module imported."
    }
}

# Display groups to be created and ask for confirmation
Write-Host "The following groups will be created and roles will be assigned:"

# Initialize an empty array to store data from all JSON files
$combinedData = @()

# Loop through each JSON data file and concatenate data into the array
foreach ($jsonDataPath in $jsonDataPaths) {
    Write-Host "Reading data from $jsonDataPath"
    $jsonData = Get-Content -Raw -Path $jsonDataPath | ConvertFrom-Json

    foreach ($item in $jsonData) {
        # Check if RolesToAssign property is an array
        if ($item.RolesToAssign -is [array]) {
            # Add each role separately
            foreach ($role in $item.RolesToAssign) {
                # Add only if CreateGroup is set to true
                if ($item.CreateGroup -eq $true) {
                    $combinedData += [PSCustomObject]@{
                        RoleRBAC         = $role
                        CustomName       = $item.CustomName
                        AssignRoleIAM    = $item.AssignRoleIAM
                        AssignRoleAD     = $item.AssignRoleAD
                        CreateGroup      = $item.CreateGroup
                        MultipleRole     = $item.MultipleRole
                    }
                }
            }
        } else {
            # Add only if CreateGroup is set to true
            if ($item.CreateGroup -eq $true) {
                $combinedData += [PSCustomObject]@{
                    RoleRBAC         = $item.RoleRBAC
                    CustomName       = $item.CustomName
                    AssignRoleIAM    = $item.AssignRoleIAM
                    AssignRoleAD     = $item.AssignRoleAD
                    CreateGroup      = $item.CreateGroup
                    MultipleRole     = $item.MultipleRole
                }
            }
        }
    }
}

# Sort the combined data based on the RoleRBAC property
$combinedData = $combinedData | Sort-Object RoleRBAC

# Display the combined data with CreateGroup set to true, sorted alphabetically, and each RolesToAssign entry on its own line in the RoleRBAC column
$combinedData | Format-Table -AutoSize

$confirmation = Read-Host "Do you want to continue? (Y/N)"        

Write-Host ""

if ($confirmation -eq 'Y') {
    # Function to get subscription name from subscription ID
    function Get-NameFromSubscriptionId {
        param (
            [string]$SubscriptionId
        )

        try {
            $subscription = Get-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop
            return $subscription.Name
        } catch {
            Write-Host "Error: $_"
            return "Unknown Name"
        }
    }

    # Convert names and id's.
    $subscriptionName = Get-NameFromSubscriptionId -SubscriptionId $subscriptionId
    $subscriptionNameShort = $subscriptionName -replace '_[T]$'
    $environmentName = $subscriptionName -replace '.*_([^_]+)$', '$1'

    # First Part: Creating Security Groups
    # Loop through each JSON data file
# Loop through each JSON data file
foreach ($jsonDataPath in $jsonDataPaths) {
    $jsonData = Get-Content -Raw -Path $jsonDataPath | ConvertFrom-Json

    foreach ($item in $jsonData) {
        $subscription = $item.Subscription
        $roleRBAC = $item.RoleRBAC
        $assignRoleIAM = $item.AssignRoleIAM -eq "true"
        $assignRoleAD = $item.AssignRoleAD -eq "true"
        $createGroup = $item.CreateGroup -eq "true"
        $multipleRole = $item.MultipleRole -eq "true"
        $customName = $item.CustomName

        if ($createGroup) {
            if ($multipleRole) {
                # Use custom name and replace only 'roleRBAC' with the specified value
                $securityGroupName = "AZ-SS-Role-$subscriptionNameShort`_$environmentName`_$($customName -replace '[^\w\-]','-' -replace '\s','')"
            } else {
                # Use the original logic for naming the security group
                $securityGroupName = "AZ-SS-Role-$subscriptionNameShort`_$environmentName`_$($roleRBAC -replace '[^\w\-]','-' -replace '\s','')"
            }

            $existingGroup = Get-AzADGroup -DisplayName $securityGroupName -ErrorAction SilentlyContinue

            if ($existingGroup -eq $null) {
                $securityGroupParams = @{
                    DisplayName        = $securityGroupName
                    SecurityEnabled    = $true
                    MailNickname       = $false
                    Description        = "Security group $securityGroupName"
                }

                if ($assignRoleAD) {
                    $securityGroupParams.Add("IsAssignableToRole", $true)
                }

                $securityGroup = New-AzADGroup @securityGroupParams

                Write-Host ("Security group '$securityGroupName' created successfully.") -ForegroundColor Green
            } else { 
                Write-Host "Security group '$securityGroupName' already exists. Skipping creation."
            }
        } # end if ($createGroup)
        else {
            # Skip reporting when creation is disabled
            continue
        }
    }
}
    # Wait for 60 seconds
    Write-Host ""
    Write-Host "`e[1;31m`e[1mWaiting 60 seconds before assigning groups to roles...`e[0m" -ForegroundColor Red
    Write-Host ""
    Start-Sleep -Seconds 60

    # Second Part: Assigning Roles to Security Groups
    foreach ($jsonDataPath in $jsonDataPaths) {
        $jsonData = Get-Content -Raw -Path $jsonDataPath | ConvertFrom-Json

        foreach ($item in $jsonData) {
            $subscription = $item.Subscription
            $roleRBAC = $item.RoleRBAC
            $assignRoleIAM = $item.AssignRoleIAM -eq "true"
            $assignRoleAD = $item.AssignRoleAD -eq "true"
            $createGroup = $item.CreateGroup -eq "true"
            $multiplerole = $item.Multiplerole -eq "true"  # Assuming this is the flag for multiple roles

            if ($assignRoleIAM -and $createGroup -and !$multiplerole) {
                $securityGroupNameForAssignment = "AZ-SS-Role-$subscriptionNameShort`_$environmentName`_$($roleRBAC -replace '[^\w\-]','-' -replace '\s','')"

                $existingGroupForAssignment = Get-AzADGroup -DisplayName $securityGroupNameForAssignment -ErrorAction SilentlyContinue

                if ($existingGroupForAssignment -ne $null) {
                    $existingRoleAssignment = Get-AzRoleAssignment -ObjectId $existingGroupForAssignment.Id -RoleDefinitionName $roleRBAC -ErrorAction SilentlyContinue

                    if ($existingRoleAssignment -eq $null) {
                        $ObjectID = $existingGroupForAssignment.Id

                        try {
                            $roleAssignment = New-AzRoleAssignment -RoleDefinitionName $roleRBAC -ObjectId $ObjectID -Scope "/subscriptions/$subscriptionId" -ErrorAction Stop
                            Write-Host ("Security group '$securityGroupNameForAssignment' assigned to role '$roleRBAC' successfully.") -ForegroundColor Green
                        } catch {
                            if ($_.Exception.Response.StatusCode -eq 409) {
                                Write-Host "Role assignment already exists for security group '$securityGroupNameForAssignment' and role '$roleRBAC'. Skipping assignment."
                            } else {
                                Write-Host "Error assigning role: $_"
                            }
                        }
                    } else {
                        Write-Host "Role assignment already exists for security group '$securityGroupNameForAssignment' and role '$roleRBAC'. Skipping assignment."
                    }
                } else {
                    Write-Host "Security group '$securityGroupNameForAssignment' not found. Skipping role assignment."
                }
            }
        }
    }

    # Third Part: Assigning Multiple Roles to Security Groups with $multipleRole and $customName
    foreach ($jsonDataPath in $jsonDataPaths) {
        $jsonData = Get-Content -Raw -Path $jsonDataPath | ConvertFrom-Json

        foreach ($item in $jsonData) {
            $subscription = $item.Subscription
            $roleRBAC = $item.RoleRBAC
            $assignRoleIAM = $item.AssignRoleIAM -eq "true"
            $assignRoleAD = $item.AssignRoleAD -eq "true"
            $createGroup = $item.CreateGroup -eq "true"
            $multipleRole = $item.MultipleRole -eq "true"
            $customName = $item.CustomName

            if ($assignRoleIAM -and $createGroup -and $multipleRole) {
                $securityGroupNameForAssignment = "AZ-SS-Role-$subscriptionNameShort`_$environmentName`_$($customName -replace '[^\w\-]','-' -replace '\s','')"

                $existingGroupForAssignment = Get-AzADGroup -DisplayName $securityGroupNameForAssignment -ErrorAction SilentlyContinue

                if ($existingGroupForAssignment -ne $null) {
                    foreach ($roleToAssign in $item.RolesToAssign) {
                        $existingRoleAssignment = Get-AzRoleAssignment -ObjectId $existingGroupForAssignment.Id -RoleDefinitionName $roleToAssign -ErrorAction SilentlyContinue

                        if ($existingRoleAssignment -eq $null) {
                            $ObjectID = $existingGroupForAssignment.Id

                            try {
                                $roleAssignment = New-AzRoleAssignment -RoleDefinitionName $roleToAssign -ObjectId $ObjectID -Scope "/subscriptions/$subscriptionId" -ErrorAction Stop
                                Write-Host ("Security group '$securityGroupNameForAssignment' assigned to role '$roleToAssign' successfully.") -ForegroundColor Green
                            } catch {
                                if ($_.Exception.Response.StatusCode -eq 409) {
                                    Write-Host "Role assignment already exists for security group '$securityGroupNameForAssignment' and role '$roleToAssign'. Skipping assignment."
                                } else {
                                    Write-Host "Error assigning role: $_"
                                }
                            }
                        } else {
                            Write-Host "Role assignment already exists for security group '$securityGroupNameForAssignment' and role '$roleToAssign'. Skipping assignment."
                        }
                    }
                } else {
                    Write-Host "Security group '$securityGroupNameForAssignment' not found. Skipping role assignment."
                }
            }
        }
    }
} else {
    Write-Host "Script execution aborted."
}