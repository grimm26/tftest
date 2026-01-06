mock_provider "aws" {
  alias = "mock"
}
mock_provider "infoblox" {
  alias = "mock"
}
mock_provider "vault" {
  alias = "mock"

  # mock out values we expect to be in various vault_generic_secret lookups
  mock_data "vault_generic_secret" {
    defaults = {
      data = {
        atlantis_password = "mock"
        ansible_publickey = "mock"
      }
    }
  }
}
mock_provider "vsphere" {
  alias = "mock"

  # mock this data lookup for the template root disk size
  mock_data "vsphere_virtual_machine" {
    defaults = {
      disks = [
        {
          size             = 20
          eagerly_scrub    = false
          label            = "foo"
          thin_provisioned = false
          unit_number      = 1
        }
      ]
    }
  }
}

override_data {
  target = data.http.ansible_apt_key
  values = {
    response_body = "mocked"
    status_code   = 200
  }
}
override_data {
  target = data.http.chef_apt_key
  values = {
    response_body = "mocked"
    status_code   = 200
  }
}

override_module {
  target = module.awx
  outputs = {
    id = "kjhwerf"
  }
}

variables {
  tags = {
    service        = "test_application"
    product        = "test"
    environment    = "staging"
    email          = "api@enova.com"
    provisioned_by = "terraform"
    terraform_path = "/dev/null"
  }
}

# TODO: Need more tests for more coverage, but this is a start.
run "ansible" {
  providers = {
    aws.this      = aws.mock
    infoblox.this = infoblox.mock
    vault.this    = vault.mock
    vsphere.this  = vsphere.mock
  }

  variables {
    configuration_manager = "ansible"
    hostname              = "module-test-ansible"
    data_center           = "pri"
    disaster_recovery     = "hot-warm"
    number_of_nodes       = 1
    os_release_name       = "focal"
    service_group         = "api"
    epg_name              = "MOCK_EPG"
    ansible_node_role     = "enova_k8s_base"
    ansible_variables = {
      "ansible_role_type" : "worker"
    }
    service_fqdn = "module-test-ansible.enova.com"
    service_name = "module-test-ansible"
  }
}

run "ansible_no_email" {
  # runs with expected failures need to only run plan or this will still fail the test
  command = plan

  providers = {
    aws.this      = aws.mock
    infoblox.this = infoblox.mock
    vault.this    = vault.mock
    vsphere.this  = vsphere.mock
  }

  variables {
    configuration_manager = "ansible"
    hostname              = "module-test-ansible"
    data_center           = "pri"
    disaster_recovery     = "hot-warm"
    number_of_nodes       = 1
    os_release_name       = "focal"
    service_group         = "api"
    epg_name              = "MOCK_EPG"
    ansible_node_role     = "enova_k8s_base"
    ansible_variables = {
      "ansible_role_type" : "worker"
    }
    service_fqdn = "module-test-ansible.enova.com"
    service_name = "module-test-ansible"
    tags = {
      service        = "test_application"
      product        = "test"
      environment    = "staging"
      provisioned_by = "terraform"
    }
  }

  expect_failures = [var.tags]
}

run "chef" {
  providers = {
    aws.this      = aws.mock
    infoblox.this = infoblox.mock
    vault.this    = vault.mock
    vsphere.this  = vsphere.mock
  }

  variables {
    hostname            = "module-test-chef"
    data_center         = "pri"
    disaster_recovery   = "hot-warm"
    number_of_nodes     = 1
    memory              = 4 * 1024
    os_release_name     = "bionic"
    service_group       = "api"
    role_cookbooks      = ["role-global-base"]
    epg_name            = "MOCK_EPG"
    chef_client_version = "14.15.6"
  }
}

run "environment_fail" {
  # runs with expected failures need to only run plan or this will stil fail the test
  command = plan

  providers = {
    aws.this      = aws.mock
    infoblox.this = infoblox.mock
    vault.this    = vault.mock
    vsphere.this  = vsphere.mock
  }

  variables {
    hostname            = "module-test-chef"
    data_center         = "pri"
    disaster_recovery   = "hot-warm"
    number_of_nodes     = 1
    memory              = 24 * 1024
    os_release_name     = "bionic"
    service_group       = "api"
    role_cookbooks      = ["role-global-base"]
    epg_name            = "MOCK_EPG"
    chef_client_version = "14.15.6"
    tags = {
      service        = "test_application"
      product        = "test"
      environment    = "nooooooooooooooooo"
      email          = "api@enova.com"
      provisioned_by = "terraform"
      terraform_path = "foo"
    }
  }

  expect_failures = [var.tags]
}

run "memory_fail" {
  # runs with expected failures need to only run plan or this will stil fail the test
  command = plan

  providers = {
    aws.this      = aws.mock
    infoblox.this = infoblox.mock
    vault.this    = vault.mock
    vsphere.this  = vsphere.mock
  }

  variables {
    hostname            = "module-test-chef"
    data_center         = "pri"
    disaster_recovery   = "hot-warm"
    number_of_nodes     = 1
    memory              = 4 * 1028
    os_release_name     = "bionic"
    service_group       = "api"
    role_cookbooks      = ["role-global-base"]
    epg_name            = "MOCK_EPG"
    chef_client_version = "14.15.6"
  }

  expect_failures = [var.memory]
}

run "custom_network_interface" {
  providers = {
    aws.this      = aws.mock
    infoblox.this = infoblox.mock
    vault.this    = vault.mock
    vsphere.this  = vsphere.mock
  }

  variables {
    hostname               = "module-test-netif"
    data_center            = "pri"
    disaster_recovery      = "hot-warm"
    number_of_nodes        = 1
    os_release_name        = "focal"
    service_group          = "api"
    epg_name               = "MOCK_EPG"
    network_interface_name = "custom0"
  }

  assert {
    condition     = output.network_interface_name == "custom0"
    error_message = "network_interface_name parameter was not used in the network interface"
  }
}

run "default_network_interface" {
  providers = {
    aws.this      = aws.mock
    infoblox.this = infoblox.mock
    vault.this    = vault.mock
    vsphere.this  = vsphere.mock
  }

  variables {
    hostname          = "module-test-default"
    data_center       = "pri"
    disaster_recovery = "hot-warm"
    number_of_nodes   = 1
    os_release_name   = "focal"
    service_group     = "api"
    epg_name          = "MOCK_EPG"
  }

  assert {
    condition     = output.network_interface_name == "ens*"
    error_message = "Default network interface for focal should be ens*"
  }
}

run "xenial_network_interface" {
  providers = {
    aws.this      = aws.mock
    infoblox.this = infoblox.mock
    vault.this    = vault.mock
    vsphere.this  = vsphere.mock
  }

  variables {
    hostname          = "module-test-xenial"
    data_center       = "pri"
    disaster_recovery = "hot-warm"
    number_of_nodes   = 1
    os_release_name   = "xenial"
    service_group     = "api"
    epg_name          = "MOCK_EPG"
  }

  assert {
    condition     = output.network_interface_name == "eth0"
    error_message = "Default network interface for xenial should be eth0"
  }
}

run "datastore_cluster_suffix_default" {
  providers = {
    aws.this      = aws.mock
    infoblox.this = infoblox.mock
    vault.this    = vault.mock
    vsphere.this  = vsphere.mock
  }

  variables {
    hostname          = "module-test-ds-default"
    data_center       = "pri"
    disaster_recovery = "hot-warm"
    number_of_nodes   = 1
    os_release_name   = "focal"
    service_group     = "api"
    epg_name          = "MOCK_EPG"
    ansible_node_role = "enova_k8s_base"
  }

  assert {
    condition     = can(regex("VMW-PRI-.*-APP", local.generic_datastore_cluster_names["module-test-ds-default01"]))
    error_message = "Datastore cluster name should contain APP suffix by default"
  }
}

run "datastore_cluster_suffix_db" {
  providers = {
    aws.this      = aws.mock
    infoblox.this = infoblox.mock
    vault.this    = vault.mock
    vsphere.this  = vsphere.mock
  }

  variables {
    hostname                 = "module-test-ds-db"
    data_center              = "pri"
    disaster_recovery        = "hot-warm"
    number_of_nodes          = 1
    os_release_name          = "focal"
    service_group            = "api"
    epg_name                 = "MOCK_EPG"
    datastore_cluster_suffix = "DB"
    ansible_node_role        = "enova_k8s_base"
  }

  assert {
    condition     = can(regex("VMW-PRI-.*-DB", local.generic_datastore_cluster_names["module-test-ds-db01"]))
    error_message = "Datastore cluster name should contain DB suffix when specified"
  }
}

run "datastore_cluster_suffix_wharf" {
  providers = {
    aws.this      = aws.mock
    infoblox.this = infoblox.mock
    vault.this    = vault.mock
    vsphere.this  = vsphere.mock
  }

  variables {
    hostname                 = "module-test-ds-wharf"
    data_center              = "pri"
    disaster_recovery        = "hot-warm"
    number_of_nodes          = 1
    os_release_name          = "focal"
    service_group            = "api"
    epg_name                 = "MOCK_EPG"
    datastore_cluster_suffix = "WHARF"
    ansible_node_role        = "enova_k8s_base"
  }

  assert {
    condition     = can(regex("VMW-PRI-.*-WHARF", local.generic_datastore_cluster_names["module-test-ds-wharf01"]))
    error_message = "Datastore cluster name should contain WHARF suffix when specified"
  }
}

run "datastore_cluster_suffix_invalid" {
  command = plan

  providers = {
    aws.this      = aws.mock
    infoblox.this = infoblox.mock
    vault.this    = vault.mock
    vsphere.this  = vsphere.mock
  }

  variables {
    hostname                 = "module-test-ds-invalid"
    data_center              = "pri"
    disaster_recovery        = "hot-warm"
    number_of_nodes          = 1
    os_release_name          = "focal"
    service_group            = "api"
    epg_name                 = "MOCK_EPG"
    datastore_cluster_suffix = "INVALID"
    ansible_node_role        = "enova_k8s_base"
  }

  expect_failures = [var.datastore_cluster_suffix]
}
