terraform {
  required_version = ">= 0.13.1" # see https://releases.hashicorp.com/terraform/
}

provider "google" {
  version = ">= 3.13.0" # see https://github.com/terraform-providers/terraform-provider-google/releases
}

locals {
  memory_store_name         = format("redis-%s-%s", var.name, var.name_suffix)
  memory_store_display_name = "Redis generated by Terraform ${var.name_suffix}"
  region                    = data.google_client_config.google_client.region

  # determine a primary zone if it is not provided
  primary_zone_letter = var.primary_zone == "" ? "a" : var.primary_zone
  primary_zone        = "${local.region}-${local.primary_zone_letter}"

  # determine an alternate zone if it is not provided
  all_zone_letters       = ["a", "b", "c", "d"]
  remaining_zone_letters = tolist(setsubtract(toset(local.all_zone_letters), toset([local.primary_zone_letter])))
  alternate_zone_letter  = var.alternate_zone == "" ? local.remaining_zone_letters.0 : var.alternate_zone
  alternate_zone         = "${local.region}-${local.alternate_zone_letter}"
}

data "google_client_config" "google_client" {}

resource "google_project_service" "redis_api" {
  service            = "redis.googleapis.com"
  disable_on_destroy = false
}

resource "google_redis_instance" "redis_store" {
  name                    = local.memory_store_name
  memory_size_gb          = var.memory_size_gb
  display_name            = local.memory_store_display_name
  redis_version           = var.redis_version
  tier                    = var.service_tier
  authorized_network      = var.vpc_network
  region                  = local.region
  location_id             = local.primary_zone
  alternative_location_id = var.service_tier == "STANDARD_HA" ? local.alternate_zone : null
  reserved_ip_range       = var.ip_cidr_range
  depends_on              = [google_project_service.redis_api]
  timeouts {
    create = var.redis_timeout
    update = var.redis_timeout
    delete = var.redis_timeout
  }
}
