prefix = "atu045"
prefix2 = "d207"
#
location = "West Europe"
root_rg_name = "atu045_rg"
rg_name = "atu045_docker207"
vlan_name = "atu045-master-vnet"
subnet_name = "atu045-docker207-subnet"
address_prefix = "10.176.207.0/24"
environment = "atu045-docker"
storage_acc = "atu045d207sa"

###
# accounts
adminuser = "adrian"
default_admin_password = "Bl4hBl4h!"
default_windows_password = "Cdfasdf@2314213f!"
docker_admin_user = "admin"
docker_admin_password = "docker123%"

# os_publisher = "RedHat"
# os_offer = "RHEL"
# os_sku = "7.3"

# Ubuntu is working

key_path = "/home/adrian/.ssh/authorized_keys" 
pub_key_file =  "/mnt/c/Users/adria/OneDrive/ssh-keys/azure_rsa.pub" 
priv_key_file = "/mnt/c/Users/adria/OneDrive/ssh-keys/azure_rsa" 

storage_tier = "Standard" 
storage_replication_type = "LRS"
jumpbox = {
    vmsize       = "Standard_DS2_v2"
    publisher    = "MicrosoftWindowsServer"
    offer        = "WindowsServer"
    sku          = "2016-Datacenter"
}
bastion = {
    nodes        = "1"
    vmsize       = "Standard_DS2_v2"
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "16.04-LTS"
}
ucp_master = {
    nodes        = "3"
    vmsize       = "Standard_DS2_v2"
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "16.04-LTS"
}
ucp_worker = {
    nodes        = "3"
    vmsize       = "Standard_DS2_v2"
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "16.04-LTS"
}
dtr = {
    nodes        = "3"
    vmsize       = "Standard_DS3_v2"
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "16.04-LTS"
}

