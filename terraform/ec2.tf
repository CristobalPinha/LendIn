# Generamos un par de llaves SSH nuevo, dedicado a esta evaluación
resource "tls_private_key" "lendin" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "lendin" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.lendin.public_key_openssh
}

# Guardamos la llave privada localmente para poder hacer SSH.
# NUNCA se sube a git (ver .gitignore).
resource "local_file" "private_key" {
  content         = tls_private_key.lendin.private_key_pem
  filename        = "${path.module}/${var.project_name}-key.pem"
  file_permission = "0400"
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.lendin.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  # La EC2 espera a que la RDS exista antes de arrancar, así el user_data
  # encuentra la base de datos ya disponible al correr las migraciones.
  depends_on = [aws_db_instance.lendin]

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    repo_url    = var.github_repo_url
    secret_key  = var.secret_key
    db_name     = var.db_name
    db_user     = var.db_username
    db_password = var.db_password
    db_host     = aws_db_instance.lendin.address
  })

  tags = {
    Name = "${var.project_name}-web"
  }
}
