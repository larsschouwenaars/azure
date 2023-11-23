# Read configuration from external JSON file
$jsonFilePath = "Networking/Virtual Networks (VNET)/JSON/create-virtual-network.json"
$jsonContent = Get-Content $jsonFilePath | ConvertFrom-Json

# Specify the subscription name and environment
$subscriptionId = $jsonContent.SubscriptionId
$subscriptionName = $jsonContent.SubscriptionName

#### THIS PART IS GETTING ALL THE INFORMATION REGARDING SUBSCRIPTION AND CONVERT THE DATA ####

# Get subscription name
$subscriptionName = (Get-AzSubscription -SubscriptionId $subscriptionId).Name

# Shorten subscription name and ignore specific words
$subscriptionNameShort = $subscriptionName -replace '_[A-Za-z]$', '' -replace ($ignoredWords -join '|'), ''

# Extract environment name
# $environmentName = ($subscriptionName -replace '.*_([A-Za-z]{1,3})$', '$1').ToLower()

# Modify subscription name based on specified rules
$subscriptionMod = $subscriptionNameShort
if ($subscriptionNameShort -match '^[A-Za-z]+_[A-Za-z]+$') {
    $subscriptionMod = ($subscriptionNameShort -split '_') | ForEach-Object { $_[0] }
    $subscriptionMod = -join $subscriptionMod
}

# Convert $subscriptionMod to lowercase
$subscriptionMod = $subscriptionMod.ToLower()

######################   END OF CONVERTING      #########################

foreach ($region in $jsonContent.regions) {
    # Construct the dynamic part of the resource group name
    $resourceGroupNameDynamicPart = "az-{0}-rsg-{1}-{2}-{3}" -f $region.name, $jsonContent.Environment, $subscriptionMod, $jsonContent.SolutionName

    # Find the next available number for the region
    $nextNumber = 1
    while (Get-AzResourceGroup -Name "$resourceGroupNameDynamicPart$nextNumber" -ErrorAction SilentlyContinue) {
        $nextNumber++
    }

    # Full resource group name
    $resourceGroupName = "{0}-{1:D2}" -f $resourceGroupNameDynamicPart, $nextNumber

    # Construct the dynamic part of the virtual network name
    $virtualNetworkNameDynamicPart = "az-{0}-vnet-{1}-{2}-{3:D2}" -f $region.name, $jsonContent.Environment, $jsonContent.SolutionName, $nextNumber

    # Find the next available number for the virtual network
    while (Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $virtualNetworkNameDynamicPart -ErrorAction SilentlyContinue) {
        $nextNumber++
        $virtualNetworkNameDynamicPart = "az-{0}-vnet-{1}-{2}-{3:D2}" -f $region.name, $jsonContent.Environment, $jsonContent.SolutionName, $nextNumber
    }

    # Full virtual network name
    $virtualNetworkName = $virtualNetworkNameDynamicPart

    Write-Host "Dynamic Resource Group Name for $($region.name) region: $resourceGroupName"
    Write-Host "Dynamic Virtual Network Name for $($region.name) region: $virtualNetworkName"
}