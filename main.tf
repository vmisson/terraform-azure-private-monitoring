resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_user_assigned_identity" "this" {
  location            = azurerm_resource_group.this.location
  name                = var.user_assigned_identity_name
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.log_analytics_workspace_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_workspace_retention_in_days
}

resource "azurerm_virtual_network" "this" {
  name                = var.virtual_network_name
  address_space       = ["10.0.0.0/24"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet" "this" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.0.0/25"]
}

resource "azurerm_network_interface" "linux" {
  name                = "lnx000001-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = "lnx000001"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = "Standard_B1ms"
  network_interface_ids = [
    azurerm_network_interface.linux.id,
  ]

  admin_username                  = var.username
  admin_password                  = var.password
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "lnx000001-osdisk"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  boot_diagnostics {}
  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.this.id,
    ]
  }
}

resource "azurerm_virtual_machine_extension" "linux-ama" {
  name                       = "linux-ama"
  virtual_machine_id         = azurerm_linux_virtual_machine.this.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.28"
  auto_upgrade_minor_version = "true"

}

resource "azurerm_network_interface" "windows" {
  name                = "win000001-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "this" {
  name                = "win000001"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = "Standard_F2"
  network_interface_ids = [
    azurerm_network_interface.windows.id,
  ]

  admin_username = var.username
  admin_password = var.password

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "win000001-osdisk"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  boot_diagnostics {}

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.this.id,
    ]
  }
}

resource "azurerm_virtual_machine_extension" "windows-ama" {
  name                       = "windows-ama"
  virtual_machine_id         = azurerm_windows_virtual_machine.this.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.20"
  auto_upgrade_minor_version = "true"
}

resource "azurerm_monitor_data_collection_rule" "this" {
  name                        = "lnx-win-dcr"
  resource_group_name         = azurerm_resource_group.this.name
  location                    = azurerm_resource_group.this.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.this.id
  destinations {
    log_analytics {
      name                  = "log_analytics"
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
    }
  }
  data_flow {
    streams      = ["Microsoft-Syslog", "Microsoft-Event", "Microsoft-Perf"]
    destinations = ["log_analytics"]
  }
  data_sources {
    syslog {
      name    = "example-syslog"
      streams = ["Microsoft-Syslog"]
      facility_names = [
        "*"
      ]
      log_levels = [
        "Debug",
        "Info",
        "Notice",
        "Warning",
        "Error",
        "Critical",
        "Alert",
        "Emergency",
      ]
    }
    windows_event_log {
      name = "eventLogsDataSource"
      streams = [
        "Microsoft-Event"
      ]
      x_path_queries = [
        "Application!*[System[(Level=1 or Level=2 or Level=3 or Level=4 or Level=0)]]",
        "Security!*[System[(band(Keywords,13510798882111488))]]",
        "System!*[System[(Level=1 or Level=2 or Level=3 or Level=4 or Level=0)]]",
      ]
    }
    performance_counter {
      counter_specifiers = [
        "\\Processor Information(_Total)\\% Processor Time",
        "\\Processor Information(_Total)\\% Privileged Time",
        "\\Processor Information(_Total)\\% User Time",
        "\\Processor Information(_Total)\\Processor Frequency",
        "\\System\\Processes",
        "\\Process(_Total)\\Thread Count",
        "\\Process(_Total)\\Handle Count",
        "\\System\\System Up Time",
        "\\System\\Context Switches/sec",
        "\\System\\Processor Queue Length",
        "\\Memory\\% Committed Bytes In Use",
        "\\Memory\\Available Bytes",
        "\\Memory\\Committed Bytes",
        "\\Memory\\Cache Bytes",
        "\\Memory\\Pool Paged Bytes",
        "\\Memory\\Pool Nonpaged Bytes",
        "\\Memory\\Pages/sec",
        "\\Memory\\Page Faults/sec",
        "\\Process(_Total)\\Working Set",
        "\\Process(_Total)\\Working Set - Private",
        "\\LogicalDisk(_Total)\\% Disk Time",
        "\\LogicalDisk(_Total)\\% Disk Read Time",
        "\\LogicalDisk(_Total)\\% Disk Write Time",
        "\\LogicalDisk(_Total)\\% Idle Time",
        "\\LogicalDisk(_Total)\\Disk Bytes/sec",
        "\\LogicalDisk(_Total)\\Disk Read Bytes/sec",
        "\\LogicalDisk(_Total)\\Disk Write Bytes/sec",
        "\\LogicalDisk(_Total)\\Disk Transfers/sec",
        "\\LogicalDisk(_Total)\\Disk Reads/sec",
        "\\LogicalDisk(_Total)\\Disk Writes/sec",
        "\\LogicalDisk(_Total)\\Avg. Disk sec/Transfer",
        "\\LogicalDisk(_Total)\\Avg. Disk sec/Read",
        "\\LogicalDisk(_Total)\\Avg. Disk sec/Write",
        "\\LogicalDisk(_Total)\\Avg. Disk Queue Length",
        "\\LogicalDisk(_Total)\\Avg. Disk Read Queue Length",
        "\\LogicalDisk(_Total)\\Avg. Disk Write Queue Length",
        "\\LogicalDisk(_Total)\\% Free Space",
        "\\LogicalDisk(_Total)\\Free Megabytes",
        "\\Network Interface(*)\\Bytes Total/sec",
        "\\Network Interface(*)\\Bytes Sent/sec",
        "\\Network Interface(*)\\Bytes Received/sec",
        "\\Network Interface(*)\\Packets/sec",
        "\\Network Interface(*)\\Packets Sent/sec",
        "\\Network Interface(*)\\Packets Received/sec",
        "\\Network Interface(*)\\Packets Outbound Errors",
        "\\Network Interface(*)\\Packets Received Errors",
        "Processor(*)\\% Processor Time",
        "Processor(*)\\% Idle Time",
        "Processor(*)\\% User Time",
        "Processor(*)\\% Nice Time",
        "Processor(*)\\% Privileged Time",
        "Processor(*)\\% IO Wait Time",
        "Processor(*)\\% Interrupt Time",
        "Processor(*)\\% DPC Time",
        "Memory(*)\\Available MBytes Memory",
        "Memory(*)\\% Available Memory",
        "Memory(*)\\Used Memory MBytes",
        "Memory(*)\\% Used Memory",
        "Memory(*)\\Pages/sec",
        "Memory(*)\\Page Reads/sec",
        "Memory(*)\\Page Writes/sec",
        "Memory(*)\\Available MBytes Swap",
        "Memory(*)\\% Available Swap Space",
        "Memory(*)\\Used MBytes Swap Space",
        "Memory(*)\\% Used Swap Space",
        "Process(*)\\Pct User Time",
        "Process(*)\\Pct Privileged Time",
        "Process(*)\\Used Memory",
        "Process(*)\\Virtual Shared Memory",
        "Logical Disk(*)\\% Free Inodes",
        "Logical Disk(*)\\% Used Inodes",
        "Logical Disk(*)\\Free Megabytes",
        "Logical Disk(*)\\% Free Space",
        "Logical Disk(*)\\% Used Space",
        "Logical Disk(*)\\Logical Disk Bytes/sec",
        "Logical Disk(*)\\Disk Read Bytes/sec",
        "Logical Disk(*)\\Disk Write Bytes/sec",
        "Logical Disk(*)\\Disk Transfers/sec",
        "Logical Disk(*)\\Disk Reads/sec",
        "Logical Disk(*)\\Disk Writes/sec",
        "Network(*)\\Total Bytes Transmitted",
        "Network(*)\\Total Bytes Received",
        "Network(*)\\Total Bytes",
        "Network(*)\\Total Packets Transmitted",
        "Network(*)\\Total Packets Received",
        "Network(*)\\Total Rx Errors",
        "Network(*)\\Total Tx Errors",
        "Network(*)\\Total Collisions",
        "System(*)\\Uptime",
        "System(*)\\Load1",
        "System(*)\\Load5",
        "System(*)\\Load15",
        "System(*)\\Users",
        "System(*)\\Unique Users",
        "System(*)\\CPUs",
      ]
      name                          = "example-performancecounter"
      sampling_frequency_in_seconds = 60
      streams                       = ["Microsoft-Perf"]
    }
  }


}

resource "azurerm_monitor_data_collection_endpoint" "this" {
  name                          = "dce-monitoring"
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  public_network_access_enabled = false
}

resource "azurerm_monitor_data_collection_rule_association" "linux-dcr" {
  name                    = "linux-dcr"
  target_resource_id      = azurerm_linux_virtual_machine.this.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.this.id
}

resource "azurerm_monitor_data_collection_rule_association" "linux-dce" {
  target_resource_id          = azurerm_linux_virtual_machine.this.id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.this.id
}

resource "azurerm_monitor_data_collection_rule_association" "windows-dcr" {
  name                    = "windows-dcr"
  target_resource_id      = azurerm_windows_virtual_machine.this.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.this.id
}

resource "azurerm_monitor_data_collection_rule_association" "windows-dce" {
  target_resource_id          = azurerm_windows_virtual_machine.this.id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.this.id
}

resource "azurerm_monitor_private_link_scope" "this" {
  name                = "ampls-monitoring"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_monitor_private_link_scoped_service" "law" {
  name                = "law-lss-monitoring"
  resource_group_name = azurerm_resource_group.this.name
  scope_name          = azurerm_monitor_private_link_scope.this.name
  linked_resource_id  = azurerm_log_analytics_workspace.this.id
}

resource "azurerm_monitor_private_link_scoped_service" "dce" {
  name                = "dce-lss-monitoring"
  resource_group_name = azurerm_resource_group.this.name
  scope_name          = azurerm_monitor_private_link_scope.this.name
  linked_resource_id  = azurerm_monitor_data_collection_endpoint.this.id
}

resource "azurerm_private_endpoint" "this" {
  name                = "ampls-monitoring-pe"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.this.id

  private_service_connection {
    name                           = "ampls-monitoring-con"
    private_connection_resource_id = azurerm_monitor_private_link_scope.this.id
    subresource_names              = ["azuremonitor"]
    is_manual_connection           = false
  }

  lifecycle {
    ignore_changes = [
      private_dns_zone_group
    ]
  }
}

data "azurerm_private_dns_zone" "zones" {
  for_each            = toset(var.list_zones)
  name                = each.value
  resource_group_name = var.dns_resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each              = data.azurerm_private_dns_zone.zones
  name                  = "vnlink-mon-${each.key}"
  resource_group_name   = each.value.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.this.id
}

resource "azurerm_route_table" "this" {
  name                          = "rt-monitoring"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  disable_bgp_route_propagation = true

  route {
    name           = "default"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "None"
  }
}

resource "azurerm_subnet_route_table_association" "this" {
  subnet_id      = azurerm_subnet.this.id
  route_table_id = azurerm_route_table.this.id
}