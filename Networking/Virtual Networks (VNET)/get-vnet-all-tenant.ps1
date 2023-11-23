# Install and import the Az module if not already installed
if (-not (Get-Module -Name Az -ListAvailable)) {
    Install-Module -Name Az -Force -AllowClobber -Scope CurrentUser
}

# Define subscription IDs to ignore
$subscriptionsToIgnore = @("", "")

# Check if there's an existing Azure connection
if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
    # Sign in to Azure (prompting for credentials if necessary)
    Connect-AzAccount
}

# Get all subscriptions excluding those in the ignore list
$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' -and $subscriptionsToIgnore -notcontains $_.Id }

# Display virtual network information in a combined table
$table = @()
foreach ($subscription in $subscriptions) {
    # Set the current subscription context
    Set-AzContext -SubscriptionId $subscription.Id

    # Get all virtual networks in the current subscription
    $virtualNetworks = Get-AzVirtualNetwork

    foreach ($vnet in $virtualNetworks) {
        # Get DNS settings for the virtual network
        $dnsSettings = Get-AzVirtualNetwork -ResourceGroupName $vnet.ResourceGroupName -Name $vnet.Name | 
            Select-Object -ExpandProperty DhcpOptions | 
            Select-Object -ExpandProperty DnsServers

        # Determine if custom DNS servers are used
        $isCustomDns = $null -ne $dnsSettings -and $dnsSettings.Count -gt 0

        $row = [PSCustomObject]@{
            'SubscriptionName'   = $subscription.Name
            'SubscriptionId'     = $subscription.Id
            'VirtualNetworkName' = $vnet.Name
            'AddressSpace'       = $vnet.AddressSpace.AddressPrefixes -join ', '
            'DnsServers'         = $isCustomDns ? $dnsSettings -join ', ' : 'Azure Default DNS'
        }
        $table += $row
    }
}

# Display the combined table
$table | Format-Table -AutoSize

# Disconnect-AzAccount # Uncomment this line if you want to disconnect after execution
