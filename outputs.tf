output "vm_uuids" {
  value = { for v in vsphere_virtual_machine.vm : v.name => v.uuid }
}

output "vm_ip_addresses" {
  value = { for v in vsphere_virtual_machine.vm : v.name => v.default_ip_address }
}

output "all_vm_ip_addresses" {
  value = [for v in vsphere_virtual_machine.vm : v.default_ip_address]
}

output "vm_fqdns" {
  value = [for v in vsphere_virtual_machine.vm : v.name]
}

output "vm_names" {
  value = [for h in infoblox_ip_allocation.ib : h.fqdn]
}

output "epg" {
  value = local.aci_network_name
}
output "epg_map" {
  value = local.this_epg_map
}

output "network_interface_name" {
  value       = local.ethernet_interface
  description = "The network interface name used for the VM"
}
