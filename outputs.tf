# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "postgres_data_directory" {
  description = "PostgreSQL data directory location"
  value       = var.data_directory
}

output "postgres_port" {
  description = "The actual port number being used by PostgreSQL"
  value       = trimspace(data.local_file.postgres_port.content)
}

output "postgres_user" {
  description = "PostgreSQL username"
  value       = var.postgres_user
}

output "postgres_database" {
  description = "PostgreSQL database name"
  value       = var.postgres_db
}

