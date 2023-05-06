Disable-AzContextAutosave -Scope Process

try {
    "Logging in to Azure..."
    Connect-AzAccount -Identity
} catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

# Start Virtual Machine
Start-AzVM -ResourceGroupName "FIXME" -Name "vm"

# create Azure Bastion
$networkProfile = Get-AzVirtualNetwork -ResourceGroupName "FIXME" -Name "vnet"
$publicip = Get-AzPublicIpAddress -ResourceGroupName "FIXME" -Name "bastion-pip"
New-AzBastion -ResourceGroupName "FIXME" -Name "bastion" -PublicIpAddress $publicip -VirtualNetwork $networkProfile
