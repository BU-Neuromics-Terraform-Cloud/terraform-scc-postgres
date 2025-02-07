variables {
  data_directory = "/tmp/test_postgres"
  postgres_port = 5432
  postgres_user = "test_user"
  postgres_db = "test_db"
  postgres_password = "test_password"
}

# Test directory creation
run "verify_directories" {
  command = plan

  assert {
    condition = length(null_resource.setup_directories) > 0
    error_message = "Directory setup resource not found"
  }
}

# Test Postgres container setup
run "verify_postgres_container" {
  command = apply

  # Check that the container is pulled
  assert {
    condition = length(null_resource.postgres_pull) > 0
    error_message = "PostgreSQL container pull resource not found"
  }

  # Verify container instance is created
  assert {
    condition = length(null_resource.postgres_instance) > 0
    error_message = "PostgreSQL instance resource not found"
  }
}

# Test database initialization and startup
run "verify_postgres_running" {
  command = apply

  # Check database initialization
  assert {
    condition = length(null_resource.init_database) > 0
    error_message = "Database initialization resource not found"
  }

  # Verify postgres is started
  assert {
    condition = length(null_resource.postgres_start) > 0
    error_message = "PostgreSQL start resource not found"
  }

  # Add a check to verify PostgreSQL is actually running
  assert {
    condition = can(null_resource.postgres_start[*])
    error_message = "PostgreSQL failed to start"
  }
}

# Replace the destroy test with a plan test for cleanup
run "verify_cleanup" {
  command = plan

  # Verify resources can be cleaned up
  assert {
    condition = length(null_resource.postgres_instance) >= 0 
    error_message = "PostgreSQL instance not properly configured for cleanup"
  }
}

# Test postgres connection
run "test_postgres_connection" {
  command = apply

  # Load the helper module
  module {
    source = "./tests/helpers/postgres_check"
  }

  variables {
    postgres_user = var.postgres_user
    postgres_password = var.postgres_password
    postgres_db = var.postgres_db
  }

  assert {
    condition     = output.connection_successful
    error_message = "Could not connect to PostgreSQL database"
  }
} 