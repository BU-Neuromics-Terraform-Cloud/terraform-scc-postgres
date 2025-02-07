# Terraform PostgreSQL Singularity Container Module

This Terraform module provisions a PostgreSQL database instance using Singularity containers. It provides a flexible, containerized PostgreSQL deployment with automatic port management and data persistence.

## Features

- Automated PostgreSQL deployment using Singularity containers
- Dynamic port allocation with configurable fallback behavior
- Persistent data storage with configurable data directory
- Customizable PostgreSQL configuration (version, user, database, etc.)
- Graceful cleanup on destroy

## Prerequisites

- Terraform installed
- Singularity/Apptainer container runtime installed
- Basic understanding of PostgreSQL and container concepts

## Usage

1. Configure the required variables:

```hcl
module "postgres" {
  source = "./postgres"
  data_directory = "/path/to/data"
  postgres_user = "postgres"
  postgres_db = "mydb"
  postgres_password = "mysecretpassword"
  postgres_port = 5432
  postgres_version = "15.0"
  force_port = false
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `data_directory` | Base directory for PostgreSQL data, logs, and temporary files | `string` | Required |
| `postgres_user` | Username for PostgreSQL database | `string` | Required |
| `postgres_db` | Name of the PostgreSQL database | `string` | Required |
| `postgres_password` | Password for PostgreSQL database | `string` | Required |
| `postgres_port` | Base port number for PostgreSQL database.  If the port is already in use, the module will attempt to find the next available port. | `number` | `5432` |
| `postgres_version` | Version of PostgreSQL to use | `string` | `"latest"` |
| `force_port` | If true, fail if specified port is not available | `bool` | `false` |

## Outputs

| Name | Description |
|------|-------------|
| `postgres_data_directory` | PostgreSQL data directory location |
| `postgres_port` | The actual port number being used by PostgreSQL |
| `postgres_user` | PostgreSQL username |
| `postgres_database` | PostgreSQL database name |

## License

This project is licensed under the MPL-2.0 License.
