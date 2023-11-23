# Read configuration from external JSON file
$configFile = "Networking/Virtual Networks (VNET)/JSON/create-virtual-network.json"
$jsonConfig = Get-Content -Raw -Path $configFile | ConvertFrom-Json

foreach ($region in $jsonConfig.regions) {
    $jsonRegionConfig = foreach ($path in $region.jsonDataPaths) {
        Get-Content -Raw -Path $path | ConvertFrom-Json
    }

    if ($region.deployVNET -eq $true) {
        Write-Host "Deploying Azure Virtual Network for $($region.name) region:"
        Write-Host "  Subscription ID: $($jsonConfig.SubscriptionId)"
        Write-Host "  Virtual Network Name: $($jsonRegionConfig.VirtualNetworkName)"
        Write-Host "  Address Prefix: $($jsonRegionConfig.AddressSpace)"
        Write-Host "  Location: $($jsonRegionConfig.Location)"
        Write-Host "  Resource Group Name: $($jsonRegionConfig.ResourceGroupName)"
        Write-Host "  DNS Server: $($jsonRegionConfig.DnsServer)"
        
        Write-Host "  Subnets:"
        foreach ($subnet in $jsonRegionConfig.Subnets) {
            Write-Host "    Subnet Name: $($subnet.Name), Address Prefix: $($subnet.AddressPrefix)"
        }

        # Your existing deployment logic goes here

        Write-Host "Deployment complete for $($region.name) region."
        Write-Host ""
    }
    else {
        Write-Host "Virtual Network deployment skipped for $($region.name) region."
    }
}