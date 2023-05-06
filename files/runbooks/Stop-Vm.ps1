Disable-AzContextAutosave -Scope Process

try {
    "Logging in to Azure..."
    Connect-AzAccount -Identity
} catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

# Stop Virtual Machine
Stop-AzVM -ResourceGroupName "FIXME" -Name "vm" -Force

# Delete Azure Bastion
Remove-AzBastion -ResourceGroupName "FIXME" -Name "bastion" -Force
