locals {
  db_username = "postgres"
  db_password = random_password.db_password.result
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "random_password" "keycloak_db_password" {
  length           = 16
  special          = true
  override_special = "!#*-_=+{}?"
}

resource "random_password" "daytona_db_password" {
  length           = 16
  special          = true
  override_special = "!#*-_=+{}?"
}

resource "aws_db_instance" "main" {
  identifier                   = "daytona"
  allocated_storage            = 10
  max_allocated_storage        = 50
  storage_encrypted            = true
  instance_class               = "db.t3.small"
  engine                       = "postgres"
  engine_version               = "13.10"
  multi_az                     = true
  publicly_accessible          = false
  performance_insights_enabled = true
  db_subnet_group_name         = module.vpc.database_subnet_group_name
  vpc_security_group_ids       = [aws_security_group.database.id]
  username                     = local.db_username
  password                     = local.db_password
  delete_automated_backups     = false
  deletion_protection          = var.rds_deletion_protection
  backup_retention_period      = 15
  backup_window                = "09:00-10:00"
  skip_final_snapshot          = true
  auto_minor_version_upgrade   = false
}

resource "kubernetes_secret" "db_password" {
  metadata {
    namespace = "default"
    name      = "postgres"
  }

  data = {
    postgres-password           = local.db_password
    postgres-password-keycloak  = random_password.keycloak_db_password.result
    postgres-password-daytona   = random_password.daytona_db_password.result
  }
}

resource "kubernetes_secret" "keycloak_db_password" {
  metadata {
    namespace = kubernetes_namespace.daytona.metadata[0].name
    name      = "postgres-keycloak"
  }

  data = {
    postgres-password = random_password.keycloak_db_password.result
  }
}

resource "kubernetes_secret" "daytona_db_password" {
  metadata {
    namespace = kubernetes_namespace.daytona.metadata[0].name
    name      = "postgres-daytona"
  }

  data = {
    postgres-password = random_password.daytona_db_password.result
  }
}

resource "kubernetes_job" "database_init" {
  metadata {
    name      = "database-init"
    namespace = "default"
  }
  spec {
    template {
      metadata {}
      spec {
        container {
          name    = "postgres"
          image   = "bitnami/postgresql:13.7.0"
          command = ["/bin/sh", "-c"]
          args = [<<EOF
psql -v ON_ERROR_STOP=1 --username "postgres" -h ${aws_db_instance.main.address} <<-EOSQL
    CREATE DATABASE keycloak;
    CREATE USER keycloak WITH ENCRYPTED PASSWORD '$KEYCLOAK_PASSWORD';
    GRANT ALL PRIVILEGES ON DATABASE keycloak TO "keycloak";
EOSQL

psql -v ON_ERROR_STOP=1 --username "postgres" -h ${aws_db_instance.main.address} <<-EOSQL
    CREATE DATABASE daytona;
    CREATE USER daytona WITH ENCRYPTED PASSWORD '$DAYTONA_PASSWORD';
    GRANT ALL PRIVILEGES ON DATABASE daytona TO "daytona";
EOSQL
EOF
          ]
          env {
            name = "PGPASSWORD"
            value_from {
              secret_key_ref {
                name = "postgres"
                key  = "postgres-password"
              }
            }
          }
          env {
            name = "KEYCLOAK_PASSWORD"
            value_from {
              secret_key_ref {
                name = "postgres"
                key  = "postgres-password-keycloak"
              }
            }
          }
          env {
            name = "DAYTONA_PASSWORD"
            value_from {
              secret_key_ref {
                name = "postgres"
                key  = "postgres-password-daytona"
              }
            }
          }
        }
        restart_policy = "Never"
      }
    }
  }
  wait_for_completion = true
  timeouts {
    create = "2m"
    update = "2m"
  }
  depends_on = [
    aws_db_instance.main
  ]
}
