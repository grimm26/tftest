data "aws_s3_object" "validation_pem" {
  provider = aws.this
  bucket   = "urcompany-chef.${data.aws_region.r.region}"
  key      = "${var.chef_server}/urcompany-validator.pem"
}

data "aws_region" "r" {
  provider = aws.this
}

data "http" "chef_apt_key" {
  url = "http://apt.urcompany.com/keys/packages-chef-io-public.key.txt"
  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Status code invalid fetching chef apt key"
    }
  }
}

data "http" "ansible_apt_key" {
  url = "http://apt.urcompany.com/keys/ansible-gpg.key"
  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Status code invalid fetching ansible apt key"
    }
  }
}

# vsphere lookups
data "vsphere_datacenter" "d" {
  provider = vsphere.this
  name     = local.environments[local.dc_env]["vcenter_data_center"]
}

data "vsphere_network" "n" {
  provider      = vsphere.this
  name          = local.aci_network_name
  datacenter_id = data.vsphere_datacenter.d.id
}

data "vsphere_datastore_cluster" "c" {
  for_each      = local.datastore == null ? toset(local.node_names) : []
  provider      = vsphere.this
  name          = local.datastore_cluster[each.value]
  datacenter_id = data.vsphere_datacenter.d.id
}

data "vsphere_datastore" "d" {
  for_each      = toset(compact([local.datastore]))
  provider      = vsphere.this
  name          = local.datastore
  datacenter_id = data.vsphere_datacenter.d.id
}

data "vsphere_virtual_machine" "template" {
  provider      = vsphere.this
  name          = local.template_name
  datacenter_id = data.vsphere_datacenter.d.id
}

data "vsphere_compute_cluster" "c" {
  for_each      = toset(local.node_names)
  provider      = vsphere.this
  name          = random_shuffle.cluster_pool[each.value].result[0]
  datacenter_id = data.vsphere_datacenter.d.id
}

data "vsphere_custom_attribute" "vm_custom_attribute" {
  provider = vsphere.this
  for_each = toset(local.vm_custom_attributes)
  name     = each.value
}

data "vsphere_tag_category" "category_tag" {
  provider = vsphere.this
  for_each = toset(flatten([for category, tags in local.vm_tags : [
    for tag in tags : "${category}::${tag}"
  ]]))
  name = split("::", each.value)[0]
}

data "vsphere_tag" "category_tag" {
  provider = vsphere.this
  for_each = toset(flatten([for category, tags in local.vm_tags : [
    for tag in tags : "${category}::${tag}"
  ]]))
  name        = split("::", each.value)[1]
  category_id = data.vsphere_tag_category.category_tag[each.value].id
}

data "vault_generic_secret" "awx" {
  provider = vault.this
  path     = "platform/api/apps/${local.environment}/awx"
}
