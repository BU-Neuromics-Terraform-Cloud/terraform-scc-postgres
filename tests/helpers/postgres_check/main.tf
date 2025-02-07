terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

variable "postgres_user" {
  type = string
}

variable "postgres_password" {
  type = string
}

variable "postgres_db" {
  type = string
}

# Test PostgreSQL connectivity
resource "null_resource" "test_connection" {
  provisioner "local-exec" {
    command = <<-EOT
      PGPASSWORD=${var.postgres_password} psql \
        -h localhost \
        -U ${var.postgres_user} \
        -d ${var.postgres_db} \
        -c "SELECT 1;" > /dev/null 2>&1
    EOT
  }
}

output "connection_successful" {
  value = length(null_resource.test_connection) > 0
} 