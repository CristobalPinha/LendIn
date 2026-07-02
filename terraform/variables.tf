variable "aws_region" {
  description = "Región de AWS donde se despliega todo (EC2 y RDS)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo usado para nombrar los recursos (SG, key pair, EC2, RDS)"
  type        = string
  default     = "lendin"
}

variable "instance_type" {
  description = "Tipo de instancia EC2 elegible para el free tier de esta cuenta"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "Clase de instancia RDS. db.t3.micro es elegible para el free tier de 12 meses"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Nombre de la base de datos, debe coincidir con DB_NAME que espera Django"
  type        = string
  default     = "prestamos_empleados"
}

variable "db_username" {
  description = "Usuario maestro de la RDS (RDS no permite 'root' como master username)"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Password del usuario maestro de la RDS. Defínelo en terraform.tfvars, nunca lo subas a git"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Valor de SECRET_KEY de Django para producción. Defínelo en terraform.tfvars"
  type        = string
  sensitive   = true
}

variable "my_ip" {
  description = "Tu IP pública en formato CIDR (ej. 190.12.34.56/32), para restringir el acceso SSH a la EC2"
  type        = string
}

variable "github_repo_url" {
  description = "URL del repo que la EC2 clonará al arrancar"
  type        = string
  default     = "https://github.com/CristobalPinha/LendIn.git"
}
