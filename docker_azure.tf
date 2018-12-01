variable location {  }
variable root_rg_name {}
variable rg_name {}
variable vlan_name {}
variable subnet_name {}
variable address_prefix {}
variable environment {}
variable storage_acc {}
variable prefix {}
variable adminuser {}
variable key_path {  }
variable pub_key_file { }
variable priv_key_file {  }
variable storage_tier { }
variable storage_replication_type { }
variable "jumpbox" { type = "map" }
variable "bastion" { type = "map" }
variable "ucp_master" { type = "map" }
variable "ucp_worker" { type = "map" }
variable "dtr" {type = "map" }
variable "default_admin_password" {}
variable "default_windows_password" {}
variable "docker_admin_user" {}
variable "docker_admin_password" {}


####################################################################
# Resource group
####################################################################
resource "azurerm_resource_group" "dockeree" {
    name     = "${var.rg_name}"
    location = "${var.location}"
    lifecycle {
        prevent_destroy=true
    }
}

####################################################################
# Availability sets
####################################################################
resource "azurerm_availability_set" "ucp-master-availabilityset" {
  name                = "ucp-master-availabilityset"
   location            = "${azurerm_resource_group.dockeree.location}"
   resource_group_name = "${azurerm_resource_group.dockeree.name}"

  tags {
    environment = "${var.environment}"
  }
}

resource "azurerm_availability_set" "ucp-worker-availabilityset" {
  name                = "ucp-worker-availabilityset"
   location            = "${azurerm_resource_group.dockeree.location}"
   resource_group_name = "${azurerm_resource_group.dockeree.name}"

  tags {
    environment = "${var.environment}"
  }
}

resource "azurerm_availability_set" "dtr-worker-availabilityset" {
  name                = "dtr-worker-availabilityset"
   location            = "${azurerm_resource_group.dockeree.location}"
   resource_group_name = "${azurerm_resource_group.dockeree.name}"

  tags {
    environment = "${var.environment}"
  }
}

####################################################################
# NSGs
####################################################################
resource "azurerm_network_security_group" "bastion_nsg" {
   name                = "bastion-nsg"
   location            = "${azurerm_resource_group.dockeree.location}"
   resource_group_name = "${azurerm_resource_group.dockeree.name}"
   security_rule {
     name                       = "bastion-inbound"
     priority                   = 100
     direction                  = "Inbound"
     access                     = "Allow"
     protocol                   = "Tcp"
     source_port_range          = "*"
     destination_port_range     = "22"
     source_address_prefix      = "*"
     destination_address_prefix = "*"
   }
    tags {
     environment = "${var.environment}"
   }
 }

resource "azurerm_network_security_group" "jumpbox_nsg" {
   name                = "jumpbox-nsg"
   location            = "${azurerm_resource_group.dockeree.location}"
   resource_group_name = "${azurerm_resource_group.dockeree.name}"
   security_rule {
     name                       = "jumpbox-inbound"
     priority                   = 100
     direction                  = "Inbound"
     access                     = "Allow"
     protocol                   = "Tcp"
     source_port_range          = "*"
     destination_port_range     = "3389"
     source_address_prefix      = "*"
     destination_address_prefix = "*"
   }
 
   tags {
     environment = "${var.environment}"
   }
 }
  
#############################################################
# Public IPs
#############################################################
resource "azurerm_public_ip" "dockeree-jumpbox-pubip" {
    name                = "${var.environment}-jumpbox-pubip-${count.index}"
    location            = "${azurerm_resource_group.dockeree.location}"
    resource_group_name = "${azurerm_resource_group.dockeree.name}"
    public_ip_address_allocation = "static"
    tags {
        environment = "${var.environment}"
    }
}

resource "azurerm_public_ip" "dockeree-bastion-pubip" {
    name                = "${var.environment}-bastion-pubip-${count.index}"
    location            = "${azurerm_resource_group.dockeree.location}"
    resource_group_name = "${azurerm_resource_group.dockeree.name}"
    public_ip_address_allocation = "static"
    tags {
        environment = "${var.environment}"
    }
}

#############################################################
# Subnet
#############################################################
resource "azurerm_subnet" "dockeree_sub" {
  name                 = "${var.subnet_name}"
  resource_group_name  = "${var.root_rg_name}"
  virtual_network_name = "${var.vlan_name}"
  address_prefix       = "${var.address_prefix}"
}


#############################################################
# UCP Load balancer
#############################################################
resource "azurerm_lb" "ucp-lb" {
    name                = "ucp-lb"
    location            = "${azurerm_resource_group.dockeree.location}"
    resource_group_name = "${azurerm_resource_group.dockeree.name}"

    frontend_ip_configuration {
      name                          = "ucp-lb-privip"
      private_ip_address_allocation = "Dynamic"
      subnet_id                     = "${azurerm_subnet.dockeree_sub.id}"
    }
}

## associate nics with this
resource "azurerm_lb_backend_address_pool" "ucp-lb-backend" {
  name                = "ucp-lb-backend"
  resource_group_name = "${azurerm_resource_group.dockeree.name}"
  loadbalancer_id     = "${azurerm_lb.ucp-lb.id}"
}

resource "azurerm_lb_probe" "ucp-lb-test1" {
  resource_group_name = "${azurerm_resource_group.dockeree.name}"
  loadbalancer_id     = "${azurerm_lb.ucp-lb.id}"
  name                = "https-running-probe"
  protocol            = "Tcp"
  port                = 443
  # request_path        = "/_ping"
}

resource "azurerm_lb_rule" "ucp-lb-rule1" {
  resource_group_name = "${azurerm_resource_group.dockeree.name}"
  loadbalancer_id     = "${azurerm_lb.ucp-lb.id}"
  name                           = "ucp-lb-rule1"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "ucp-lb-privip"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.ucp-lb-backend.id}"
  probe_id                       = "${azurerm_lb_probe.ucp-lb-test1.id}"
  idle_timeout_in_minutes        = 1000
  load_distribution              = "Default"
}

#############################################################
# DTR Load balancer
#############################################################
resource "azurerm_lb" "dtr-lb" {
    name                = "dtr-lb"
    location            = "${azurerm_resource_group.dockeree.location}"
    resource_group_name = "${azurerm_resource_group.dockeree.name}"

    frontend_ip_configuration {
      name                          = "dtr-lb-privip"
      private_ip_address_allocation = "Dynamic"
      subnet_id                     = "${azurerm_subnet.dockeree_sub.id}"
    }
}

## associate nics with this
resource "azurerm_lb_backend_address_pool" "dtr-lb-backend" {
  name                = "dtr-lb-backend"
  resource_group_name = "${azurerm_resource_group.dockeree.name}"
  loadbalancer_id     = "${azurerm_lb.dtr-lb.id}"
}

resource "azurerm_lb_rule" "dtr-lb-rule1" {
  resource_group_name = "${azurerm_resource_group.dockeree.name}"
  loadbalancer_id     = "${azurerm_lb.dtr-lb.id}"
  name                           = "dtr-lb-rule1"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "dtr-lb-privip"
}

resource "azurerm_lb_probe" "dtr-lb-test1" {
  resource_group_name = "${azurerm_resource_group.dockeree.name}"
  loadbalancer_id     = "${azurerm_lb.dtr-lb.id}"
  name                = "https-running-probe"
  protocol            = "Tcp"
  port                = 443
  # request_path        = "/_ping"
}

#############################################################
# Private IPs & interfaces
#############################################################

resource "azurerm_network_interface" "ipaddr-jumpbox-nic" {
  name                = "${var.environment}-jumpbox-ip"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.dockeree.name}"
  network_security_group_id = "${azurerm_network_security_group.jumpbox_nsg.id}"

  ip_configuration {
    name                          = "${var.environment}-jumpbox-privip-cfg"
    subnet_id                     = "${azurerm_subnet.dockeree_sub.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.dockeree-jumpbox-pubip.id}"
  }
}

resource "azurerm_network_interface" "ipaddr-bastion-nic" {
  name                = "${var.environment}-bastion-ip"
  location            = "${var.location}"
  resource_group_name = "${var.rg_name}"
  network_security_group_id = "${azurerm_network_security_group.bastion_nsg.id}"

  ip_configuration {
    name                          = "${var.environment}-bastion-privip-cfg"
    subnet_id                     = "${azurerm_subnet.dockeree_sub.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.dockeree-bastion-pubip.id}"
  }
}

resource "azurerm_network_interface" "ipaddr-ucp-master-nic" {
  count               = "${var.ucp_master["nodes"]}"
  name                = "${var.environment}-ucp-master-ip-${count.index}"
  location            = "${var.location}"
  resource_group_name = "${var.rg_name}"

  ip_configuration {
    name                          = "${var.environment}-ucp-master-privip-cfg-${count.index}"
    subnet_id                     = "${azurerm_subnet.dockeree_sub.id}"
    private_ip_address_allocation = "dynamic"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.ucp-lb-backend.id}"]
  }
}

resource "azurerm_network_interface" "ipaddr-ucp-worker-nic" {
  count               = "${var.ucp_worker["nodes"]}"
  name                = "${var.environment}-ucp-worker-privip-${count.index}"
  location            = "${var.location}"
  resource_group_name = "${var.rg_name}"

  ip_configuration {
    name                          = "${var.environment}-ucp-worker-privip-cfg-${count.index}"
    subnet_id                     = "${azurerm_subnet.dockeree_sub.id}"
    private_ip_address_allocation = "dynamic"    
  }
}

resource "azurerm_network_interface" "ipaddr-dtr-nic" {
  count               = "${var.dtr["nodes"]}"
  name                = "${var.environment}-dtr-privip-${count.index}"
  location            = "${var.location}"
  resource_group_name = "${var.rg_name}"

  ip_configuration {
    name                          = "${var.environment}-dtr-privip-cfg-${count.index}"
    subnet_id                     = "${azurerm_subnet.dockeree_sub.id}"
    private_ip_address_allocation = "dynamic"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.dtr-lb-backend.id}"]
  }
}

#############################################################
# Storage accounts & containers
#############################################################
resource "azurerm_storage_account" "dockeree" {
  name                = "${var.storage_acc}"
  resource_group_name = "${var.rg_name}"
  location            = "${var.location}"
  account_tier        = "${var.storage_tier}"
  account_replication_type = "${var.storage_replication_type}"
  depends_on = ["azurerm_resource_group.dockeree"]
  tags {
    environment = "${var.environment}"
  }
}

resource "azurerm_storage_container" "jumpbox" {
  name                  = "${var.environment}-jumpbox-sc"
  resource_group_name   = "${var.rg_name}"
  storage_account_name  = "${azurerm_storage_account.dockeree.name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "bastion" {
  name                  = "${var.environment}-bastion-sc"
  resource_group_name   = "${var.rg_name}"
  storage_account_name  = "${azurerm_storage_account.dockeree.name}"
  container_access_type = "private"
}


resource "azurerm_storage_container" "ucp_master" {
  count                 = "${var.ucp_master["nodes"]}"
  name                  = "${var.environment}-ucp-master-sc${count.index}"
  resource_group_name   = "${var.rg_name}"
  storage_account_name  = "${azurerm_storage_account.dockeree.name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "ucp_worker" {
  count                 = "${var.ucp_worker["nodes"]}"
  name                  = "${var.environment}-ucp-worker-sc${count.index}"
  resource_group_name   = "${var.rg_name}"
  storage_account_name  = "${azurerm_storage_account.dockeree.name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "dtr" {
  count                 = "${var.dtr["nodes"]}"
  name                  = "${var.environment}-dtr-sc${count.index}"
  resource_group_name   = "${var.rg_name}"
  storage_account_name  = "${azurerm_storage_account.dockeree.name}"
  container_access_type = "private"
}

#############################################################
# jumpbox host
#############################################################
resource "azurerm_virtual_machine" "jumpbox" {
  name                  = "${var.environment}-jumpbox-vm"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.dockeree.name}"
  network_interface_ids = [ "${azurerm_network_interface.ipaddr-jumpbox-nic.id}" ]
  vm_size               = "${var.jumpbox["vmsize"]}"

  storage_image_reference {
    publisher = "${var.jumpbox["publisher"]}"
    offer     = "${var.jumpbox["offer"]}"
    sku       = "${var.jumpbox["sku"]}"
    version   = "latest"
  }

  storage_os_disk {
    name          = "${var.environment}-jumpbox-vm"
    vhd_uri       = "${azurerm_storage_account.dockeree.primary_blob_endpoint}${azurerm_storage_container.jumpbox.name}/osdisk1.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "${var.prefix}-jb"
    admin_username = "${var.adminuser}"
    admin_password = "${var.default_windows_password}"
  }
  
  os_profile_windows_config {}

  tags {
    environment = "${var.environment}"
    nodetype    = "jumpbox"
  }
}

#############################################################
# Bastion host
#############################################################
resource "azurerm_virtual_machine" "bastion" {
  name                  = "${var.environment}-bastion-vm"
  location              = "${var.location}"
  resource_group_name   = "${var.rg_name}"
  network_interface_ids = [ "${azurerm_network_interface.ipaddr-bastion-nic.id}" ]
  vm_size               = "${var.bastion["vmsize"]}"

  storage_image_reference {
    publisher = "${var.bastion["publisher"]}"
    offer     = "${var.bastion["offer"]}"
    sku       = "${var.bastion["sku"]}"
    version   = "latest"
  }

  storage_os_disk {
    name          = "${var.environment}-bastion-vm"
    vhd_uri       = "${azurerm_storage_account.dockeree.primary_blob_endpoint}${azurerm_storage_container.bastion.name}/osdisk1.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "${var.environment}-bastion-vm"
    admin_username = "${var.adminuser}"
    admin_password = "${var.default_admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path = "${var.key_path}"
      key_data = "${file("${var.pub_key_file}")}"
    }
  }

  tags {
    environment = "${var.environment}"
    nodetype    = "bastion"
  }
  
  connection {
    user = "${var.adminuser}"
    host = "${azurerm_public_ip.dockeree-bastion-pubip.ip_address}"
    agent = false
    private_key = "${file(var.priv_key_file)}"
    # Failed to read key ... no key found
    timeout = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/${var.adminuser}/.ssh"
    ]
  }

  provisioner "file" {
     source = "${var.priv_key_file}"
     destination = "/home/${var.adminuser}/.ssh/azure_rsa"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 700 /home/${var.adminuser}/.ssh/",
      "chmod 600 /home/${var.adminuser}/.ssh/azure_rsa"
    ]
  }

}


#############################################################
# ucp_master VMs
#############################################################
resource "azurerm_virtual_machine" "ucp_master" {
  count                 = "${var.ucp_master["nodes"]}"
  name                  = "${var.environment}-ucp-master-vm-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${var.rg_name}"
  availability_set_id   = "${azurerm_availability_set.ucp-master-availabilityset.id}"
  network_interface_ids = [ "${element(azurerm_network_interface.ipaddr-ucp-master-nic.*.id,count.index)}" ]
  vm_size               = "${var.ucp_master["vmsize"]}"

  storage_image_reference {
    publisher = "${var.ucp_master["publisher"]}"
    offer     = "${var.ucp_master["offer"]}"
    sku       = "${var.ucp_master["sku"]}"
    version   = "latest"
  }

  storage_os_disk {
    name          = "${var.environment}-ucp-master-vm-${count.index}"
    vhd_uri       = "${azurerm_storage_account.dockeree.primary_blob_endpoint}${element(azurerm_storage_container.ucp_master.*.name,count.index)}/osdisk1.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "${var.environment}-ucp-master-vm-${count.index}"
    admin_username = "${var.adminuser}"
    admin_password = "${var.default_admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path = "${var.key_path}"
      key_data = "${file("${var.pub_key_file}")}"
    }
  }

  tags {
    environment = "${var.environment}"
    nodetype    = "ucp_master"
  }
}

#############################################################
# ucp_worker VMs
#############################################################
resource "azurerm_virtual_machine" "ucp_worker" {
  count                 = "${var.ucp_worker["nodes"]}"
  name                  = "${var.environment}-ucp-worker-vm-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${var.rg_name}"
  availability_set_id   = "${azurerm_availability_set.ucp-worker-availabilityset.id}"
  network_interface_ids = [ "${element(azurerm_network_interface.ipaddr-ucp-worker-nic.*.id,count.index)}" ]
  vm_size               = "${var.ucp_worker["vmsize"]}"

  storage_image_reference {
    publisher = "${var.ucp_worker["publisher"]}"
    offer     = "${var.ucp_worker["offer"]}"
    sku       = "${var.ucp_worker["sku"]}"
    version   = "latest"
  }

  storage_os_disk {
    name          = "${var.environment}-ucp-worker-vm-${count.index}"
    vhd_uri       = "${azurerm_storage_account.dockeree.primary_blob_endpoint}${element(azurerm_storage_container.ucp_worker.*.name,count.index)}/osdisk1.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "${var.environment}-ucp-worker-vm-${count.index}"
    admin_username = "${var.adminuser}"
    admin_password = "${var.default_admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path = "${var.key_path}"
      key_data = "${file("${var.pub_key_file}")}"
    }
  }

  tags {
    environment = "${var.environment}"
    nodetype    = "ucp_worker"
  }
}

#############################################################
# dtr VMs
#############################################################
resource "azurerm_virtual_machine" "dtr" {
  count                 = "${var.dtr["nodes"]}"
  name                  = "${var.environment}-dtr-vm-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${var.rg_name}"
  availability_set_id   = "${azurerm_availability_set.dtr-worker-availabilityset.id}"
  network_interface_ids = [ "${element(azurerm_network_interface.ipaddr-dtr-nic.*.id,count.index)}" ]
  vm_size               = "${var.dtr["vmsize"]}"

  storage_image_reference {
    publisher = "${var.dtr["publisher"]}"
    offer     = "${var.dtr["offer"]}"
    sku       = "${var.dtr["sku"]}"
    version   = "latest"
  }

  storage_os_disk {
    name          = "${var.environment}-dtr-vm-${count.index}"
    vhd_uri       = "${azurerm_storage_account.dockeree.primary_blob_endpoint}${element(azurerm_storage_container.dtr.*.name,count.index)}/osdisk1.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "${var.environment}-dtr-vm-${count.index}"
    admin_username = "${var.adminuser}"
    admin_password = "${var.default_admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path = "${var.key_path}"
      key_data = "${file("${var.pub_key_file}")}"
    }
  }

  tags {
    environment = "${var.environment}"
    nodetype    = "dtr"
  }
}

####################################################################################################
# https://blog.gruntwork.io/how-to-create-reusable-infrastructure-with-terraform-modules-25526d65f73d
####################################################################################################
module "dockeree-module" {
   source = "github.com/adeturner/dockeree-terraform-module"

   # Currently there is no "depends_on" in modules
   # so lets use some "computed" values in a dummy variable to make the delay happen
   mod_depends_on = [
    "${azurerm_virtual_machine.ucp_worker.*.id}",
    "${azurerm_virtual_machine.ucp_master.*.id}",
    "${azurerm_virtual_machine.dtr.*.id}",
    "${azurerm_virtual_machine.bastion.id}"
   ]

   cluster_size  = "${var.ucp_master["nodes"] + var.ucp_worker["nodes"] + var.dtr["nodes"]}"

   bastion_host = "${azurerm_public_ip.dockeree-bastion-pubip.ip_address}"
   boot_node = "${var.environment}-ucp-master-vm-0"
   
   ssh_user  = "${var.adminuser}"
   docker_admin_user = "${var.docker_admin_user}"
   docker_admin_password = "${var.docker_admin_password}"
   #ssh_key_file = "${file(var.priv_key_file)}"
   ssh_key_file = "${file(var.priv_key_file)}"
   ssh_agent = true
   
   generate_key = true
   # dockeree_pub_key = "${file("${var.pub_key_file}")}"
   # dockeree_priv_key = "${file("${var.priv_key_file}")}"
    
   dockeree-host-groups = {
        ucp_master = "${azurerm_network_interface.ipaddr-ucp-master-nic.*.private_ip_address}"
        ucp_worker = ["${azurerm_network_interface.ipaddr-ucp-worker-nic.*.private_ip_address}"]
        dtr  = ["${azurerm_network_interface.ipaddr-dtr-nic.*.private_ip_address}"]
   }
   
   # no LB at the moment so assign to first host
   # ucp_master_ip = "${azurerm_network_interface.ipaddr-ucp-master-nic.*.private_ip_address[0]}"
   ucp_master_ip = "${azurerm_lb.ucp-lb.private_ip_address}"
   ucp_master = "${azurerm_virtual_machine.ucp_worker.*.name[0]}"

   hooks = {
      "cluster-preconfig" = [
        "sudo apt-get update",
        "sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common",
        "touch /tmp/cluster-preconfig-complete"
      ]
      "cluster-postconfig" = [
          "touch /tmp/cluster-postconfig-complete"
      ]
      "preinstall" = [
          "touch /tmp/preinstall-complete"
      ]
      "postinstall" = [
        "echo Performing some post install backup",
        "touch /tmp/postinstall-complete"
      ]
   }    

}

output "ucp_load_balancer_ip" {
    value = "${azurerm_lb.ucp-lb.private_ip_address}"
}

output "dtr_load_balancer_ip" {
    value = "${azurerm_lb.ucp-lb.private_ip_address}"
}