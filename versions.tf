terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 6.0.0"
      configuration_aliases = [aws.this]
    }
    vsphere = {
      source                = "vmware/vsphere"
      version               = "~> 2.14"
      configuration_aliases = [vsphere.this]
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    infoblox = {
      source                = "infobloxopen/infoblox"
      version               = "~> 2.5"
      configuration_aliases = [infoblox.this]
    }
    vault = {
      source                = "hashicorp/vault"
      version               = ">= 3.19.0"
      configuration_aliases = [vault.this]
    }
  }
}
