locals {
  product     = var.tags["product"]
  environment = var.tags["environment"]
  service     = var.tags["service"]
  team_email  = lookup(var.tags, "email", "")

  authentication_string = var.configuration_manager == "ansible" ? sensitive(base64encode("atlantis_awx:${data.vault_generic_secret.awx.data["atlantis_password"]}")) : null

  # Map of all EPG info
  full_epg_map = {
    "sec-production" = {
      "MOCK_EPG" = "10.1.70.0/24"
    }
    "sec-staging" = {
      "MOCK_EPG" = "10.11.239.0/24"
    }
    "pri-production" = {
      "MOCK_EPG" = "10.2.239.0/24"
    }
    "pri-staging" = {
      "MOCK_EPG" = "10.22.239.0/24"
    }
  }
  # Map of all CIDR info
  full_cidr_map = {
    "sec-production" = {
      "10.1.70.0/24" = "MOCK_EPG"
    }
    "sec-staging" = {
      "10.11.239.0/24" = "MOCK_EPG"
    }
    "pri-production" = {
      "10.2.239.0/24" = "MOCK_EPG"
    }
    "pri-staging" = {
      "10.22.239.0/24" = "MOCK_EPG"
    }
  }

  dc_env  = "${var.data_center}-${local.environment}"
  epg_env = var.epg_map == null ? local.dc_env : var.epg_map

  # epg locals for the env we are working in now. Mod this when gets added to ACI
  this_epg_map  = local.full_epg_map[local.epg_env]
  this_cidr_map = local.full_cidr_map[local.epg_env]

  node_names           = [for i in range(var.node_base_index, var.number_of_nodes + var.node_base_index) : format("%s%02d%s", var.hostname, i, var.node_iteration)]
  aci_network_name     = var.cidr_range != null ? try(one(local.this_cidr_map[var.cidr_range]), local.this_cidr_map[var.cidr_range]) : var.epg_name
  cidr_range           = var.cidr_range != null ? var.cidr_range : local.this_epg_map[local.aci_network_name]
  subnet_prefix_length = split("/", local.cidr_range)[1]

  default_template_name = contains(["xenial", "bionic", "focal"], var.os_release_name) ? "${var.os_release_name}-64-tf" : "${var.os_release_name}-64"
  template_name         = var.template_name != null ? var.template_name : local.default_template_name

  node_fqdns = [for x in local.node_names : "${x}.${local.environments[local.dc_env]["dns_zone"]}"]

  aci_pri-stag_compute_clusters = [
    "Stag01",
  ]
  default_pri-stag_compute_clusters = local.aci_pri-stag_compute_clusters

  aci_sec-stag_compute_clusters = [
    "Stag01",
  ]
  default_sec-stag_compute_clusters = local.aci_sec-stag_compute_clusters

  default_prod_compute_clusters = [
    "Prod-A",
    "Prod-B",
  ]

  environments = {
    pri-staging = {
      dns_zone            = "pri.urcompany.com",
      chef_env            = "pri-staging",
      vcenter_data_center = var.vcenter_data_center == null ? "PRI-STAG" : var.vcenter_data_center,
      compute_clusters    = var.compute_cluster == null ? local.default_pri-stag_compute_clusters : [var.compute_cluster],
      ansible_inventory   = "34"
    },
    sec-staging = {
      dns_zone            = "sec.urcompany.com",
      chef_env            = "sec-staging",
      vcenter_data_center = var.vcenter_data_center == null ? "SEC-STAG" : var.vcenter_data_center,
      compute_clusters    = var.compute_cluster == null ? local.default_sec-stag_compute_clusters : [var.compute_cluster],
      ansible_inventory   = "36"
    },
    pri-production = {
      dns_zone            = "pri.urcompany.com",
      chef_env            = "pri-production",
      vcenter_data_center = var.vcenter_data_center == null ? "PRI" : var.vcenter_data_center,
      compute_clusters    = var.compute_cluster == null ? local.default_prod_compute_clusters : [var.compute_cluster],
      ansible_inventory   = "4"
    },
    sec-production = {
      dns_zone            = "sec.urcompany.com",
      chef_env            = "sec-production",
      vcenter_data_center = var.vcenter_data_center == null ? "SEC" : var.vcenter_data_center,
      compute_clusters    = var.compute_cluster == null ? local.default_prod_compute_clusters : [var.compute_cluster],
      ansible_inventory   = "35"
    },
  }

  ansible_inventory = local.environments[local.dc_env]["ansible_inventory"]

  # We can't put datastore_cluster inside of the environments local because it relies on a piece of that local to calculate itself.
  # Build a map of generic datastore cluster names to use when one is not hardcoded for an environment
  generic_datastore_cluster_names = {
    for node in local.node_names :
    node => "VMW-${upper(var.data_center)}-${random_shuffle.cluster_pool[node].result[0]}-${var.datastore_cluster_suffix}"
  }
  datastore_cluster = {
    for node in local.node_names :
    node => var.datastore_cluster == null ? local.generic_datastore_cluster_names[node] : var.datastore_cluster
  }
  datastore = var.datastore == null ? try(local.environments[local.dc_env]["default_datastore"], null) : var.datastore

  chef_environment = var.chef_environment == null ? local.environments[local.dc_env]["chef_env"] : var.chef_environment

  ethernet_interface = var.network_interface_name != null ? var.network_interface_name : (
    var.os_release_name == "xenial" ? "eth0" :
    "ens*"
  )

  disk_size = var.disk_size == 0 ? data.vsphere_virtual_machine.template.disks[0].size : var.disk_size

  # category = [tag1, tag2, ...]
  vm_tags = {
    "vm.Provisioner"       = ["terraform"]
    "vm.Backup"            = ["do-not-backup"]
    "vm.DisasterRecovery"  = ["hot-hot", "hot-warm"]
    "vm.PrimaryDataCenter" = ["sec", "pri"]
  }

  vm_custom_attributes = ["ansible_node_role", "ansible_variables", "app_name", "configuration_manager", "environment", "product", "service", "service_group", "site_name", "team_email"]
}
