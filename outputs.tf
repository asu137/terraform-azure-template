output "publicip_vm" {
  value = azurerm_public_ip.vm_public_ip.ip_address
}
