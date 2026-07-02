#!/bin/bash
set -e

# Instalar Docker y git
apt-get update -y
apt-get install -y docker.io git
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Clonar el repo de la app
git clone ${repo_url} /home/ubuntu/LendIn
cd /home/ubuntu/LendIn

# Variables de entorno para producción, apuntando a la RDS
cat > .env <<EOF
SECRET_KEY=${secret_key}
DB_ENGINE=django.db.backends.mysql
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
DB_HOST=${db_host}
DB_PORT=3306
DJANGO_ALLOWED_HOSTS=*
EOF

# Construir la imagen y correr migraciones (crea tablas + seed de Comuna/TipoPrestamo)
docker build -t lendin-web .
docker run --rm --env-file .env lendin-web python manage.py migrate

# Levantar la app
docker run -d \
  --name lendin-web \
  --restart unless-stopped \
  --env-file .env \
  -p 8000:8000 \
  lendin-web
