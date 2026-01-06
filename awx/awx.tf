terraform {
  required_version = ">= 1.0"
}

variable "triggers" {
  description = "Map of things that trigger an AWX job"
  type        = map(string)
}

variable "authentication_string" {
  description = "Base64 encoded username:password for AWX"
  type        = string
}

variable "node_fqdns" {
  description = "List of FQDNs of nodes to run the job on"
  type        = list(string)
}

variable "ansible_inventory" {
  description = "Name of the AWX inventory to run the job on"
  type        = string
}

variable "service_group" {
  description = "Name of the service group that users are pulled from"
  type        = string
}

variable "environment" {
  description = "Environment to deploy to (e.g., staging, production)"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be either 'staging' or 'production'."
  }
}

locals {
  vault_credentials_id = var.environment == "staging" ? "67" /* Vault Systems Staging */ : "9" /* Vault Systems */
  awx_json = {
    "limit" : join(", ", var.node_fqdns),
    "inventory" : var.ansible_inventory,
    "credentials" : [
      "39", # ansible_new (machine)
      "38", # Circleci API (hitting awx api)
      local.vault_credentials_id
    ]
  }
  destroy_root_password = {
    "destroy_root_password" : "true"
  }
  awx_payload = jsonencode(local.awx_json)
}
resource "terraform_data" "Launch_AWX_Job" {
  triggers_replace = var.triggers

  provisioner "local-exec" {
    command = <<EOF
      curl -X POST https://awx-production.urcompany.com/api/v2/job_templates/19/launch/ --header "Content-Type: application/json" --header "Authorization: basic ${var.authentication_string}" --data '${local.awx_payload}'
    EOF
  }
}

resource "terraform_data" "Update_Service_Group_AWX" {
  triggers_replace = var.service_group

  provisioner "local-exec" {
    command = <<EOF
      curl -X POST https://awx-production.urcompany.com/api/v2/job_templates/42/launch/ --header "Content-Type: application/json" --header "Authorization: basic ${var.authentication_string}" --data '${local.awx_payload}'
    EOF
  }
}

resource "terraform_data" "Configure_Root_Password_AWX" {
  provisioner "local-exec" {
    command = <<EOF
      curl -X POST https://awx-production.urcompany.com/api/v2/job_templates/103/launch/ --header "Content-Type: application/json" --header "Authorization: basic ${var.authentication_string}" --data '${local.awx_payload}'
    EOF
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
      curl -X POST https://awx-production.urcompany.com/api/v2/job_templates/103/launch/ --header "Content-Type: application/json" --header "Authorization: basic ${self.input.var.authentication_string}" --data '${jsonencode(merge(self.input.local.awx_json, self.input.local.destroy_root_password))}'
    EOF
  }
}

output "id" {
  description = "the terraform_data.Launch_AWX_Job.id"
  value       = terraform_data.Launch_AWX_Job.id
}
