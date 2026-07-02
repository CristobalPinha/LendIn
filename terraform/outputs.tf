output "ec2_public_ip" {
  description = "IP pública de la instancia EC2"
  value       = aws_instance.web.public_ip
}

output "app_url" {
  description = "URL para abrir la app en el navegador"
  value       = "http://${aws_instance.web.public_ip}:8000"
}

output "ssh_command" {
  description = "Comando para conectarte por SSH a la instancia"
  value       = "ssh -i ${var.project_name}-key.pem ubuntu@${aws_instance.web.public_ip}"
}

output "rds_endpoint" {
  description = "Endpoint de la base de datos RDS (solo accesible desde la EC2)"
  value       = aws_db_instance.lendin.address
}
