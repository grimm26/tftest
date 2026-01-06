# Required variables
variable "hostname" {
  description = "What is the name, not the fully qualified name, e.g. foo not foo.urcompany.com"
  type        = string
  validation {
    condition     = !strcontains(var.hostname, "_") && !strcontains(var.hostname, ".")
    error_message = "hostname << ${var.hostname} >> cannot contain an underscore or dot."
  }
}

variable "node_base_index" {
  description = "What number do we start counting from when creating the iterated node names? (default = 1)"
  type        = number
  default     = 1
}

variable "number_of_nodes" {
  description = "How many vm's should we create?"
  type        = number
}

variable "os_release_name" {
  description = "What OS name to install. (bionic, focal, etc)"
  type        = string
  validation {
    condition     = var.configuration_manager != "ansible" || contains(["noble", "focal"], var.os_release_name)
    error_message = "When configuration_manager is set to ansible, os_release_name must be either 'noble' or 'focal'."
  }
}

variable "service_fqdn" {
  description = "What is the fully qualified name for the service (application.urcompany.com, pact-broker.urcompany.com)? Staging should include staging in the name (application.staging.urcompany.com, pact-broker.staging.urcompany.com)"
  type        = string
  default     = null
}

variable "service_name" {
  description = "What is the application being ran on this vm?"
  type        = string
  default     = null
}

variable "cidr_range" {
  description = "What CIDR range (subnet/VLAN) to put the node(s) into.  If you aren't sure what to put here, ask. e.g. 10.18.101.0/24. Conflicts with epg_name."
  type        = string
  default     = null
}

variable "epg_name" {
  description = "Full EPG name of the network to use. Conflicts with cidr_range."
  type        = string
  default     = null
}

variable "epg_map" {
  description = "Optionally specify the EPG map to use. By default this is determined based on envionrment and data_center."
  type        = string
  default     = null
  validation {
    condition = var.epg_map == null || try(contains([
      "pri-staging",
      "pri-production",
      "sec-staging",
      "sec-production",
      "pri-corp",
      "sec-corp",
    ], var.epg_map), false)
    error_message = "epg_map must be null or one of: pri-staging, pri-production, sec-staging, sec-production, pri-corp, sec-corp."
  }
}

variable "network_interface_name" {
  description = "Overwrite name of the network interface (e.g., 'ens33', 'eth0', 'en*') to attach the IP address to."
  type        = string
  default     = null
}

variable "data_center" {
  description = "Which data center to create node in: pri, sec?"
  type        = string
  validation {
    condition     = contains(["pri", "sec"], var.data_center)
    error_message = "The data_center should be one of: pri, sec."
  }
}

variable "service_group" {
  description = "Name of the service group that users are pulled from"
  type        = string
}

variable "tags" {
  description = "Map of tags containing at least product, environment, terraform_path, and service. email is also required if you are using ansible as your configuration manager."
  type        = map(string)

  validation {
    condition     = length(setintersection(keys(var.tags), ["product", "environment", "service", "terraform_path"])) == 4
    error_message = "The tags variable MUST contain at least product, environment, terraform_path, and service."
  }

  validation {
    condition     = contains(["production", "staging"], lookup(var.tags, "environment", "staging"))
    error_message = "The environment should be one of: staging, production."
  }

  validation {
    condition = var.configuration_manager != "ansible" || (
      contains(keys(var.tags), "email")
    )
    error_message = "The tags variable MUST contain email if your configuration_manager is ansible."
  }
}

# Optional variables
variable "role_cookbooks" {
  description = "List of cookbooks to add to the run_list for the node(s)"
  type        = list(string)
  default     = []
}

variable "additional_tags" {
  description = "Additional chef tags to be added to node at creation time"
  type        = string
  default     = ""
}

variable "num_cpus" {
  description = "Number of CPUs to allocate to the VM"
  type        = number
  default     = 2
}

variable "cpu_hot_add_enabled" {
  description = "Allow CPUs to be added to this virtual machine while it is running. CHANGING THIS WILL CAUSE A REBOOT."
  type        = bool
  default     = true
}

variable "memory" {
  description = "MB (megabytes) of RAM to allocate to the VM"
  type        = number
  default     = 4096
  validation {
    condition     = var.memory >= 4096
    error_message = "Memory setting must be greater than 4096. Note that this is MB (megabytes)."
  }
  validation {
    condition     = var.memory % 1024 == 0
    error_message = "memory must be a multiple of 1024."
  }
}

variable "memory_hot_add_enabled" {
  description = "Allow memory to be added to this virtual machine while it is running. CHANGING THIS WILL CAUSE A REBOOT."
  type        = bool
  default     = true
}

variable "folder" {
  description = "The path to the folder to put this virtual machine in, relative to the data center that the resource pool is in."
  type        = string
  default     = null
}

variable "disk_size" {
  description = "Gigabytes in size to make the root volume"
  type        = number
  default     = 0
}

variable "extra_disks" {
  description = "Add multiple disks, size and unit_number are required. Disk will be labeled diskN where N starts at 1 for extra disks and counts up from there"
  type = list(object(
    {
      size             = number
      unit_number      = number
      eagerly_scrub    = optional(bool, true)
      thin_provisioned = optional(bool, false)
    }
  ))
  default = []
}

variable "sata_controller_count" {
  description = "The number of SATA controllers that Terraform manages on this virtual machine.This directly affects the amount of disks you can add to the virtual machine and the maximum disk unit number"
  type        = number
  default     = 0
}

variable "scsi_controller_count" {
  description = "The number of SCSI controllers that Terraform manages on this virtual machine. This directly affects the amount of disks you can add to the virtual machine and the maximum disk unit number"
  type        = number
  default     = 1
}

variable "enable_logging" {
  description = "Enable logging of virtual machine events to a log file stored in the virtual machine directory"
  type        = bool
  default     = false
}

variable "chef_server" {
  description = "What chef server to bootstrap to"
  type        = string
  default     = "chef.pri.urcompany.com"
}

variable "chef_environment" {
  description = "What chef environment to bootstrap to. This should be determined automatically based on var.environment, but you can override here."
  type        = string
  default     = null
}

variable "chef_client_version" {
  description = "What chef client version to install"
  type        = string
  default     = "14.15.6"
}

variable "dns_resolver" {
  description = "IP of the DNS resolver to use. 10.10.10.10 by default"
  type        = string
  default     = "10.10.10.10"
}

variable "vcenter_data_center" {
  description = "Override the standard vCenter data center based on var.data_center + var.environment (pri-production == PRI, sec-staging == SEC-STAG, etc)."
  type        = string
  default     = null
}

variable "compute_cluster" {
  description = "Override picking the compute cluster."
  type        = string
  default     = null
}

variable "datastore_cluster" {
  description = "Override picking the datastore cluster."
  type        = string
  default     = null
}

variable "datastore_cluster_suffix" {
  description = "Suffix to use when constructing the datastore cluster name if var.datastore_cluster is not set.  Must be one of: APP, DB, WHARF."
  type        = string
  default     = "APP"
  validation {
    condition     = contains(["APP", "DB", "WHARF"], var.datastore_cluster_suffix)
    error_message = "datastore_cluster_suffix must be one of: APP, DB, WHARF."
  }
}

variable "datastore" {
  description = "Override picking the specific datastore."
  type        = string
  default     = null
}

variable "node_iteration" {
  description = "This option can be specified if you are creating a set of nodes for an OS upgrade or something that will take the place of the existing iteration.  e.g. specify \"a\" here to make nameXXa nodes instead of nameXX."
  type        = string
  default     = ""
}

variable "template_name" {
  description = "Sets the template name that this vm should be cloned from. The default is the `var.os_release_name` + '-64-tf'"
  type        = string
  default     = null
}

variable "extra_config_reboot_required" {
  description = "Force the virtual machine to be rebooted when a change to extra_config occurs."
  type        = bool
  default     = false
}

variable "enable_disk_uuid" {
  description = "Expose the UUIDs of attached virtual disks to the virtual machine, allowing access to them in the guest."
  type        = bool
  default     = false
}

variable "ansible_node_role" {
  description = "The ansible role that will be applied to the node, for example; urcompany_redis or urcompany_postgres. To apply standard urcompany standard applications use: go, unicorn, puma, gunicorn, tomcat. Springboot has been deprecated in favor of java."
  type        = string
  default     = null
  validation {
    condition     = var.ansible_node_role != "springboot"
    error_message = "Ansible role springboot is deprecated. Please use java role instead."
  }
}

variable "ansible_variables" {
  description = "A map of variables that should be passed to the node to be used by ansible"
  type        = map(string)
  default     = {}
}

variable "configuration_manager" {
  description = "Which configuration management tool will you use to configure the host after creation? (either ansible or chef)"
  type        = string
  default     = "chef"
  validation {
    condition     = var.configuration_manager == null || try(contains(["ansible", "chef"], var.configuration_manager), false)
    error_message = "The manager should be either: ansible or chef."
  }
}

variable "backup" {
  description = "Allow the virtual machine to be backed up. SETTING THIS TO FALSE WILL STOP BACKUPS OF THE VM."
  type        = bool
  default     = true
}

variable "disaster_recovery" {
  description = "What disaster recovery strategy will you implement: hot-hot, hot-warm?"
  type        = string
  validation {
    condition     = contains(["hot-hot", "hot-warm"], var.disaster_recovery)
    error_message = "The disaster_recovery should be one of: hot-hot, hot-warm."
  }
}
