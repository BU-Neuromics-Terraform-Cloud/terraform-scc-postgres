terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# Define local variables
locals {
  postgres_data = var.data_directory
  postgres_port = var.postgres_port
  postgres_version = var.postgres_version
  postgres_user = var.postgres_user
  postgres_db = var.postgres_db
  # Use environment variable or change this
  postgres_password = var.postgres_password
  instance_id = uuid()
  postgres_instance_name = "postgres_instance_${local.instance_id}"
}

# Pull PostgreSQL image
resource "null_resource" "postgres_pull" {
  provisioner "local-exec" {
    command = <<-EOT
    if [ ! -f postgres.sif ]; then
      singularity pull postgres.sif docker://postgres:${local.postgres_version}
    fi
    EOT
  }
}
# Create necessary directories
resource "null_resource" "setup_directories" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${local.postgres_data}/{data,logs,run,tmp}
    EOT
  }
}

# PostgreSQL container instance
resource "null_resource" "postgres_instance" {
  depends_on = [null_resource.postgres_pull]

  # Add triggers to store the instance name
  triggers = {
    instance_name = local.postgres_instance_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      singularity instance start \
        --bind ${local.postgres_data}/data:/var/lib/postgresql/data/ \
        --bind ${local.postgres_data}/logs:/var/log/postgresql/ \
        --bind ${local.postgres_data}/run:/var/run/postgresql/ \
        --bind ${local.postgres_data}/tmp:/tmp/ \
        postgres.sif ${local.postgres_instance_name}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Stop the postgres instance if it's running
      if singularity instance list | grep -q ${self.triggers.instance_name}; then
        singularity instance stop ${self.triggers.instance_name}
      fi
    EOT
  }
}

# Initialize database and create user
resource "null_resource" "init_database" {
  depends_on = [
    null_resource.setup_directories,
    null_resource.postgres_instance,
  ]

  # Add triggers to store the instance name
  triggers = {
    instance_name = local.postgres_instance_name
  }

  provisioner "local-exec" {
    command = <<-EOT

      # initialize the database using the docker entrypoint
      cat << 'SCRIPT' > ${local.postgres_data}/tmp/postgres_start.sh
      #!/bin/bash -l

      # initialize the database using the docker entrypoint
      export POSTGRES_USER=${local.postgres_user}
      export POSTGRES_PASSWORD=${local.postgres_password}
      export POSTGRES_DB=${local.postgres_db}

      # set the path to the postgres binaries
      PATH=/usr/lib/postgresql/17/bin/:$PATH

      # source the docker entrypoint
      source /usr/local/bin/docker-entrypoint.sh

      bash /usr/local/bin/docker-ensure-initdb.sh

      SCRIPT

      chmod +x ${local.postgres_data}/tmp/postgres_start.sh

      # initialize the database
      singularity exec instance://${self.triggers.instance_name} /tmp/postgres_start.sh
    EOT
  }
} 

resource "null_resource" "postgres_start" {
  depends_on = [null_resource.init_database]

  triggers = {
    instance_name = local.postgres_instance_name
  }

  provisioner "local-exec" {
    command = "singularity exec instance://${local.postgres_instance_name} pg_ctl start -D /var/lib/postgresql/data/ -l /var/log/postgresql/logfile"
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      # Stop the postgres instance if it's running
      if singularity instance list | grep -q ${self.triggers.instance_name}; then
        singularity exec instance://${self.triggers.instance_name} pg_ctl stop -D /var/lib/postgresql/data/ -m fast
      fi
    EOT
  }
} 
