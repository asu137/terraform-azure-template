provider "azurerm" {
  features {}
}

locals {
  resource_prefix             = var.resource_name_prefix
  resource_prefix_with_hyphen = var.resource_name_prefix != "" ? "${var.resource_name_prefix}-" : ""
}

resource "azurerm_resource_group" "resource_group" {
  name     = "${local.resource_prefix_with_hyphen}${var.resource_group_name}"
  location = var.region
}

/* 仮想ネットワーク */
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.resource_prefix_with_hyphen}vnet"
  location            = var.region
  resource_group_name = azurerm_resource_group.resource_group.name
  address_space       = ["${var.vnet_address_range_prefix}0.0/16"]
}
resource "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["${var.vnet_address_range_prefix}1.0/24"]
  service_endpoints    = [
    "Microsoft.Storage",
  ]
}
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet" # Azure側でこの名前にするよう決められているため変更不可
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["${var.vnet_address_range_prefix}1.64/27"]
  service_endpoints    = [
    "Microsoft.KeyVault",
  ]
}

/* パブリックIPアドレス */
resource "azurerm_public_ip" "vm_public_ip" {
  name                = "${local.resource_prefix_with_hyphen}vm-pip"
  location            = var.region
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
resource "azurerm_public_ip" "bastion_public_ip" {
  name                = "${local.resource_prefix_with_hyphen}bastion-pip"
  location            = var.region
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

/*　仮想マシン -vm */
resource "azurerm_network_security_group" "vm_nsg" {
  name                 = "${local.resource_prefix_with_hyphen}vm-nsg"
  location             = azurerm_resource_group.resource_group.location
  resource_group_name  = azurerm_resource_group.resource_group.name
  security_rule {
    name                       = "SSH"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "vm_nsg" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}
resource "azurerm_network_interface" "vm_nic" {
  name                = "${local.resource_prefix_with_hyphen}vm-nic"
  location            = var.region
  resource_group_name = azurerm_resource_group.resource_group.name

  ip_configuration {
    name                          = "${local.resource_prefix_with_hyphen}vm-nic-configuration"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "${var.vnet_address_range_prefix}2.4"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip.id
  }
}
resource "azurerm_virtual_machine" "vm" {
  name                          = "${local.resource_prefix_with_hyphen}vm"
  location                      = var.region
  resource_group_name           = azurerm_resource_group.resource_group.name
  network_interface_ids         = [azurerm_network_interface.vm_nic.id]
  vm_size                       = "${var.vm_size}"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${local.resource_prefix_with_hyphen}vm-os-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.resource_prefix_with_hyphen}vm"
    admin_username = var.linux_user
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = file("./files/ssh/vm.pub")
    }
  }
}

/* キー コンテナー(Bastionで利用するSSH鍵を保存) */
data "azurerm_vm_config" "current" {}
resource "azurerm_key_vault" "key_vault" {
  name                        = "${local.resource_prefix_with_hyphen}vault"
  location                    = azurerm_resource_group.resource_group.location
  resource_group_name         = azurerm_resource_group.resource_group.name
  tenant_id                   = data.azurerm_vm_config.current.tenant_id
  soft_delete_retention_days  = 90
  purge_protection_enabled    = false
  enabled_for_deployment      = true
  sku_name                    = "standard"

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = var.ip_whitelist
  }
}

/* ストレージアカウント(遮断君ログ保存用) */
resource "azurerm_storage_account" "strorage" {
  name                            = "${local.resource_prefix}st"
  location                        = azurerm_resource_group.resource_group.location
  resource_group_name             = azurerm_resource_group.resource_group.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  is_hns_enabled                  = true
  nfsv3_enabled                   = true
  access_tier                     = "Hot"
  allow_nested_items_to_be_public = false

  network_rules {
    default_action             = "Deny"
    ip_rules                   = var.ip_whitelist
    virtual_network_subnet_ids = [
      azurerm_subnet.vm_subnet.id,
    ]
  }
}
resource "azurerm_storage_container" "blob_container" {
  name                  = "blob"
  storage_account_name  = azurerm_storage_account.strorage.name
  container_access_type = "private"
}
resource "azurerm_storage_management_policy" "blob_container_policy" {
  storage_account_id = azurerm_storage_account.strorage.id

  // 指定した期間が経過したらホット→コールドへ変更
  rule {
    name    = "transition-hot-to-cold"
    enabled = true
    filters {
      prefix_match = ["blob"] // blob名
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 90
      }
    }
  }
}

/* プライベートリンク */
resource "azurerm_private_endpoint" "storage_private_endpoint" {
  name                = "${local.resource_prefix_with_hyphen}st-private-endpoint"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  subnet_id           = azurerm_subnet.vm_subnet.id

  private_service_connection {
    name                           = "${local.resource_prefix_with_hyphen}st-private-service-connection"
    private_connection_resource_id = azurerm_storage_account.strorage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}
resource "azurerm_private_dns_zone" "private_dns_zone" {
  name                = "privatelink.blob.core.windows.net"
	resource_group_name = azurerm_resource_group.resource_group.name

	depends_on = [azurerm_private_endpoint.storage_private_endpoint]
}
resource "azurerm_private_dns_zone_virtual_network_link" "associate-dnszone-vnet" {
	name                  = "associate-privatednszone-with-vnet"
  resource_group_name   = azurerm_resource_group.resource_group.name
	private_dns_zone_name = azurerm_private_dns_zone.private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}
resource "azurerm_private_dns_a_record" "example" {
  name                = "${local.resource_prefix}st"
  resource_group_name = azurerm_resource_group.resource_group.name
  zone_name           = azurerm_private_dns_zone.private_dns_zone.name
  ttl                 = 10
  records             = [azurerm_private_endpoint.storage_private_endpoint.private_service_connection[0].private_ip_address]
}

/* コンテナーレジストリ */
resource "azurerm_container_registry" "_acr" {
  name                     = "${local.resource_prefix}acr"
  location                 = azurerm_resource_group.resource_group.location
  resource_group_name      = azurerm_resource_group.resource_group.name
  admin_enabled            = true
  sku                      = "Basic"
}

/* Application Insights */
resource "azurerm_application_insights" "_insights" {
  name                = "${local.resource_prefix_with_hyphen}insights"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  application_type    = "web"
}

/* Automationアカウント */
resource "azurerm_automation_account" "automation_account" {
  name                = "${local.resource_prefix_with_hyphen}automation"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }
}

/* Automation Runbook */
data "local_file" "runbook_start_vm" {
  filename = "./files/runbooks/Start-Vm.ps1"
}
resource "azurerm_automation_runbook" "start_Vm" {
  name                    = "Start-Vm"
  location                = azurerm_resource_group.resource_group.location
  resource_group_name     = azurerm_resource_group.resource_group.name
  automation_account_name = azurerm_automation_account.automation_account.name
  log_verbose             = "false"
  log_progress            = "false"
  description             = "VMを起動した後、Bastionを作成する"
  runbook_type            = "PowerShell"

  content = data.local_file.runbook_start_vm.content
}
data "local_file" "runbook_stop_vm" {
  filename = "./files/runbooks/Stop-Vm.ps1"
}
resource "azurerm_automation_runbook" "stop_vm" {
  name                    = "Stop-Vm"
  location                = azurerm_resource_group.resource_group.location
  resource_group_name     = azurerm_resource_group.resource_group.name
  automation_account_name = azurerm_automation_account.automation_account.name
  log_verbose             = "false"
  log_progress            = "false"
  description             = "VMを停止した後、Bastionを削除する"
  runbook_type            = "PowerShell"

  content = data.local_file.runbook_stop_vm.content
}
data "local_file" "runbook_batch" {
  filename = "./files/runbooks/Batch.ps1"
}
resource "azurerm_automation_runbook" "batch" {
  name                    = "Batch"
  location                = azurerm_resource_group.resource_group.location
  resource_group_name     = azurerm_resource_group.resource_group.name
  automation_account_name = azurerm_automation_account.automation_account.name
  log_verbose             = "false"
  log_progress            = "false"
  description             = ""
  runbook_type            = "PowerShell"

  content = data.local_file.runbook_batch.content
}
resource "azurerm_automation_schedule" "batch_schedule" {
  name                    = "batch-schedule"
  resource_group_name     = azurerm_resource_group.resource_group.name
  automation_account_name = azurerm_automation_account.automation_account.name
  frequency               = "Day"
  interval                = 1
  timezone                = "Asia/Tokyo"
  start_time              = "${replace(timeadd(timestamp(), "24h"), "/T.*$/", "")}T08:00:00+09:00" // 翌日の08:00を開始時に設定
}
data "local_file" "runbook_delete_running_resource" {
  filename = "./files/runbooks/Delete-Running-Resource.ps1"
}
/* アラート通知用 アクショングループ */
resource "azurerm_monitor_action_group" "alert_action" {
  name                = "alert-action"
  resource_group_name = azurerm_resource_group.resource_group.name
  short_name          = "alert"

  /* TODO: email_receiverを追加して宛先を増やす
  email_receiver {
    name          = "HOGE"
    email_address = "hoge@example.com"
  }
  */
}

/* エラーログ アラート */
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "_error_log_alert" {
  name                = "error-log-alert"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  scopes = [
    azurerm_application_insights._insights.id
  ]

  description           = "Application Insightsにエラー出力がされました。\nエラー内容を確認してください。"
  window_duration       = "PT1H" // 集約粒度(期間)
  evaluation_frequency  = "PT1H" // 評価の頻度
  severity              = 1
  enabled               = true

  criteria {
    query                   = <<-QUERY
      traces
      | where message contains "error"
      QUERY
    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0 // 閾値

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.alert_action.id]
  }
}
