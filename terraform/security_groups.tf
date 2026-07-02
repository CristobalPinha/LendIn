# Security Group de la EC2: SSH restringido a tu IP, la app abierta al público
resource "aws_security_group" "ec2_sg" {
  name_prefix = "${var.project_name}-ec2-"
  description = "SSH restringido + acceso HTTP a la app Django"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH solo desde mi IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "App Django (runserver)"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# Security Group de la RDS: SOLO acepta conexiones desde el SG de la EC2,
# nunca desde internet directamente. Esto es lo que demuestra el requisito
# de "acceso seguro" de la rúbrica.
resource "aws_security_group" "rds_sg" {
  name_prefix = "${var.project_name}-rds-"
  description = "MySQL accesible unicamente desde la EC2 de la app"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "MySQL solo desde la EC2"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups  = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}
