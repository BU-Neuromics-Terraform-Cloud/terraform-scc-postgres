variable "postgres_password" {
  description = "Password for PostgreSQL database"
  type        = string
  sensitive   = true  # Changed to true for better security
}

variable "data_directory" {
  description = "Base directory for PostgreSQL data, logs, and temporary files"
  type        = string
}

variable "postgres_user" {
  description = "Username for PostgreSQL database"
  type        = string
}

variable "postgres_db" {
  description = "Name of the PostgreSQL database"
  type        = string
}

variable "postgres_port" {
  description = "Port number for PostgreSQL database"
  type        = number
  default     = 5432
}

variable "postgres_version" {
  description = "Version of PostgreSQL to use"
  type        = string
  default     = "latest"
} 