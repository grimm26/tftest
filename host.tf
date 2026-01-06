# Find  IP(s) from the cidr_range and create host record(s).
resource "infoblox_ip_allocation" "ib" {
  for_each   = toset(local.node_names)
  provider   = infoblox.this
  fqdn       = "${each.value}.${local.environments[local.dc_env]["dns_zone"]}"
  ipv4_cidr  = local.cidr_range
  dns_view   = "inside"
  enable_dns = true
  comment    = "Created by Terraform in ${var.tags.terraform_path}, please do not modify manually."
}

# Choose a random cluster pool
resource "random_shuffle" "cluster_pool" {
  for_each     = toset(local.node_names)
  input        = local.environments[local.dc_env]["compute_clusters"]
  result_count = 1
}

resource "vsphere_virtual_machine" "vm" {
  for_each = infoblox_ip_allocation.ib
  provider = vsphere.this
  name     = each.value.fqdn
  # Random pools!
  resource_pool_id     = data.vsphere_compute_cluster.c[each.key].resource_pool_id
  datastore_cluster_id = local.datastore == null ? data.vsphere_datastore_cluster.c[each.key].id : null
  datastore_id         = local.datastore == null ? null : data.vsphere_datastore.d[local.datastore].id

  num_cpus               = var.num_cpus
  cpu_hot_add_enabled    = var.cpu_hot_add_enabled
  memory                 = var.memory
  memory_hot_add_enabled = var.memory_hot_add_enabled
  sata_controller_count  = var.sata_controller_count
  scsi_controller_count  = var.scsi_controller_count
  firmware               = data.vsphere_virtual_machine.template.firmware
  sync_time_with_host    = false
  enable_logging         = var.enable_logging
  folder                 = var.folder
  # List tags here like "<category>::<tag>"
  tags = compact([
    data.vsphere_tag.category_tag["vm.Provisioner::terraform"].id,
    data.vsphere_tag.category_tag["vm.DisasterRecovery::${var.disaster_recovery}"].id,
    data.vsphere_tag.category_tag["vm.PrimaryDataCenter::${var.data_center}"].id,
    # Only include a vm.Backup tag if backing up has been disabled
    var.backup ? null : data.vsphere_tag.category_tag["vm.Backup::do-not-backup"].id,
  ])
  custom_attributes = {
    (data.vsphere_custom_attribute.vm_custom_attribute["ansible_node_role"].id)     = var.ansible_node_role,
    (data.vsphere_custom_attribute.vm_custom_attribute["ansible_variables"].id)     = tostring(jsonencode(var.ansible_variables)),
    (data.vsphere_custom_attribute.vm_custom_attribute["app_name"].id)              = var.service_name,
    (data.vsphere_custom_attribute.vm_custom_attribute["environment"].id)           = local.environment,
    (data.vsphere_custom_attribute.vm_custom_attribute["product"].id)               = local.product,
    (data.vsphere_custom_attribute.vm_custom_attribute["service"].id)               = local.service,
    (data.vsphere_custom_attribute.vm_custom_attribute["service_group"].id)         = var.service_group,
    (data.vsphere_custom_attribute.vm_custom_attribute["site_name"].id)             = var.service_fqdn,
    (data.vsphere_custom_attribute.vm_custom_attribute["team_email"].id)            = local.team_email,
    (data.vsphere_custom_attribute.vm_custom_attribute["configuration_manager"].id) = var.configuration_manager,
  }

  guest_id = data.vsphere_virtual_machine.template.guest_id

  network_interface {
    network_id = data.vsphere_network.n.id
  }

  disk {
    keep_on_remove = false
    label          = "disk0"
    size           = local.disk_size
    unit_number    = 0
  }

  dynamic "disk" {
    for_each = [for d in var.extra_disks : {
      label            = format("disk%s", (index(var.extra_disks, d) + 1))
      size             = d.size
      unit_number      = d.unit_number
      eagerly_scrub    = d.eagerly_scrub
      thin_provisioned = d.thin_provisioned
    }]
    content {
      eagerly_scrub    = disk.value.eagerly_scrub
      keep_on_remove   = false
      unit_number      = disk.value.unit_number
      label            = disk.value.label
      size             = disk.value.size
      thin_provisioned = disk.value.thin_provisioned
    }
  }

  lifecycle {
    # Ignore things that might get changed underneath us that we don't want to enforce beyond creation.
    ignore_changes = [
      hardware_version,
      resource_pool_id,
      datastore_cluster_id,
      datastore_id,
      extra_config,
      firmware,
      network_interface,
      clone,
      folder,
      ept_rvi_mode,
      hv_mode,
      # These disk attributes have to be explicitly specified. Hopefully no one has more than 4 disks.
      disk[0].thin_provisioned,
      disk[0].eagerly_scrub,
      disk[0].label,
      disk[1].thin_provisioned,
      disk[1].eagerly_scrub,
      disk[1].label,
      disk[2].thin_provisioned,
      disk[2].eagerly_scrub,
      disk[2].label,
      disk[3].thin_provisioned,
      disk[3].eagerly_scrub,
      disk[3].label,
      disk[4].label,             # veeam proxies
      disk[5].label,             # veeam proxies
      disk[6].label,             # veeam proxies
      disk[7].label,             # veeam proxies
      disk[8].label,             # veeam proxies
      disk[9].label,             # veeam proxies
      disk[10].label,            # veeam proxies
      disk[11].label,            # veeam proxies
      disk[12].label,            # veeam proxies
      disk[13].label,            # veeam proxies
      disk[14].label,            # veeam proxies
      disk[15].label,            # veeam proxies
      custom_attributes["203"],  # backup_status sec production
      custom_attributes["204"],  # backup_status sec production
      custom_attributes["207"],  # backup_status sec staging
      custom_attributes["209"],  # backup_status pri staging
      custom_attributes["1203"], # backup_status pri production
    ]
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }

  extra_config_reboot_required = var.extra_config_reboot_required
  enable_disk_uuid             = var.enable_disk_uuid
  # This block would require the guest template have cloud-init +
  # https://github.com/vmware/cloud-init-vmware-guestinfo installed (package does not exist for ubuntu
  # could build our own or run the installer script)
  # example tf usage at https://github.com/vmware/simple-k8s-test-env/tree/master/e2e
  extra_config = {
    "guestinfo.metadata.encoding" = "gzip+base64"
    "guestinfo.userdata.encoding" = "gzip+base64"

    "guestinfo.userdata" = var.configuration_manager == "chef" ? base64gzip(
      templatefile("${path.module}/chef_cloud_init.cfg",
        {
          chef_apt_key        = data.http.chef_apt_key.response_body,
          validation_cert     = base64encode(data.aws_s3_object.validation_pem.body),
          chef_env            = local.chef_environment,
          chef_client_version = var.chef_client_version,
          chef_package_os     = var.os_release_name == "focal" ? "bionic" : var.os_release_name,
          service_group       = var.service_group,
          additional_tags     = var.additional_tags,
          fqdn                = each.value.fqdn
          role_cookbooks      = join(",", formatlist("recipe[%s]", var.role_cookbooks)),
        }
      )
      ) : base64gzip(templatefile("${path.module}/ansible_cloud_init.cfg",
        {
          service_group     = var.service_group
          ansible_publickey = data.vault_generic_secret.awx.data["ansible_publickey"]
          environment       = local.environment
          ansible_apt_key   = data.http.ansible_apt_key.response_body,
          location          = var.data_center,
          ansible_fqdn      = each.value.fqdn
          ansible_version   = var.os_release_name == "focal" ? "2.12.10-1ppa~focal" : "2.16.3-0ubuntu2"
        }
      )
    )

    "guestinfo.metadata" = base64gzip(jsonencode({
      "network" = base64gzip(templatefile("${path.module}/netplan.tmpl",
        {
          ip_address           = each.value.allocated_ipv4_addr,
          subnet_prefix_length = local.subnet_prefix_length,
          def_gateway          = cidrhost(local.cidr_range, 1),
          dns_resolver         = var.dns_resolver,
          dns_zone             = local.environments[local.dc_env]["dns_zone"],
          interface            = local.ethernet_interface
        }
      ))
      "network.encoding"              = "gzip+base64"
      "system_info.network.renderers" = ["netplan", "eni"]
      "local-hostname"                = each.value.fqdn
      "instance-id"                   = each.value.fqdn
      }
    ))
  }
}


module "awx" {
  count                 = var.configuration_manager == "ansible" && var.ansible_node_role != null ? 1 : 0
  source                = "./awx"
  authentication_string = local.authentication_string
  ansible_inventory     = local.ansible_inventory
  node_fqdns            = local.node_fqdns
  service_group         = var.service_group
  environment           = local.environment
  triggers = {
    # If the list of uuids changes, that means we did node create/delete.
    vm_uuids          = base64sha256(join("", [for x in vsphere_virtual_machine.vm : x.uuid]))
    ansible_node_role = var.ansible_node_role,
    site_name         = var.service_fqdn,
    app_name          = var.service_name,
    number_of_nodes   = var.number_of_nodes,
    ansible_variables = tostring(jsonencode(var.ansible_variables))
    product           = local.product
    environment       = local.environment
  }
  depends_on = [
    vsphere_virtual_machine.vm
  ]
}
