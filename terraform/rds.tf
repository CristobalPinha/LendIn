# Grupo de subnets donde puede vivir la RDS (usa las subnets default de la VPC)
resource "aws_db_subnet_group" "lendin" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "lendin" {
  identifier     = "${var.project_name}-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.lendin.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # No exponemos la RDS con IP pública: solo se llega a ella desde dentro de
  # la VPC, y dentro de la VPC solo el SG de la EC2 tiene permiso (ver security_groups.tf)
  publicly_accessible = false

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-db"
  }
}
