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
  postgres_base_port = var.postgres_port
  postgres_version = var.postgres_version
  postgres_user = var.postgres_user
  postgres_db = var.postgres_db
  # Use environment variable or change this
  postgres_password = var.postgres_password
  instance_id = uuid()
  postgres_instance_name = "postgres_instance_${local.instance_id}"
}

# Find available port
resource "null_resource" "find_port" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      port=${local.postgres_base_port}
      
      # Check if the specified port is in use
      if netstat -tuln | grep -q ":$port "; then
        if [[ "${var.force_port}" == "true" ]]; then
          echo "Error: Port $port is already in use and force_port is set to true" >&2
          exit 1
        fi
        
        # Find next available port
        while netstat -tuln | grep -q ":$port "; do
          ((port++))
        done
      fi
      echo $port > ${local.postgres_data}/tmp/postgres_port
    EOT
  }
}

# Add a data source to read the port
data "local_file" "postgres_port" {
  depends_on = [null_resource.find_port]
  filename = "${local.postgres_data}/tmp/postgres_port"
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
  depends_on = [null_resource.postgres_pull, null_resource.find_port]

  # Add triggers to store the instance name and port
  triggers = {
    instance_name = local.postgres_instance_name
    port = trimspace(data.local_file.postgres_port.content)
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
      export POSTGRES_PORT=${null_resource.postgres_instance.triggers.port}

      # set the path to the postgres binaries
      PATH=/usr/lib/postgresql/17/bin/:$PATH

      # source the docker entrypoint
      source /usr/local/bin/docker-entrypoint.sh

      # Update postgresql.conf with the correct port
      sed -i "s/#port = 5432/port = $POSTGRES_PORT/" /var/lib/postgresql/data/postgresql.conf

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
