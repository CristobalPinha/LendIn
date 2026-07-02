# Manual de despliegue de LendIn en AWS con Terraform

Este manual documenta cómo desplegar el sistema de préstamos (Django + Docker) en AWS: una instancia **EC2** (free tier) corriendo la app en Docker, y una base de datos **RDS MySQL** (free tier) accesible únicamente desde esa EC2.

## 0. Prerrequisitos (una sola vez)

### 0.1 Crear la cuenta AWS

1. Ve a https://aws.amazon.com/free y crea una cuenta (requiere tarjeta, pero el free tier no cobra dentro de los límites).
2. Inicia sesión en la consola como **root user** solo para el siguiente paso.

### 0.2 Crear un usuario IAM con acceso programático

Nunca se usan las credenciales root para Terraform. Se crea un usuario IAM aparte:

1. Entra a la consola de AWS como root (https://console.aws.amazon.com) y busca **IAM** en la barra de búsqueda superior.
2. Menú izquierdo → **Users** → botón **Create user**.
3. "User name": `terraform-lendin`. **No marques** "Provide user access to the AWS Management Console" (este usuario es solo para la API, no para entrar por navegador) → **Next**.
4. Selecciona **Attach policies directly** → busca y marca `AdministratorAccess` (aceptable para esta evaluación académica; en un entorno real se usaría una policy acotada) → **Next** → **Create user**.
5. Haz clic en el usuario recién creado → pestaña **Security credentials** → sección **Access keys** → botón **Create access key**.
6. Caso de uso: selecciona **Command Line Interface (CLI)** → marca la casilla de confirmación → **Next** → **Create access key**.
7. Guarda el `Access Key ID` y el `Secret Access Key` que se muestran (con **Download .csv file** o copiándolos a un lugar seguro). Este es el único momento en que se muestra el secret completo; si cierras la pantalla sin guardarlo, tendrás que crear una access key nueva.

### 0.3 Instalar herramientas locales

En Windows (PowerShell):

```powershell
winget install Amazon.AWSCLI
winget install Hashicorp.Terraform
```

Verifica:

```powershell
aws --version
terraform -version
```

### 0.4 Configurar credenciales de AWS CLI

```powershell
aws configure
```

Te pedirá:
- `AWS Access Key ID`: el que copiaste en 0.2
- `AWS Secret Access Key`: el que copiaste en 0.2
- `Default region name`: `us-east-1`
- `Default output format`: `json`

Terraform reutiliza automáticamente estas credenciales.

### 0.5 Obtener tu IP pública

Necesaria para restringir el acceso SSH a la EC2:

```powershell
curl ifconfig.me
```

Anota el resultado, lo usarás como `<TU_IP>/32` en el siguiente paso.

### 0.6 Verificar qué tipo de instancia EC2 es free tier en tu cuenta

Según la antigüedad de la cuenta, AWS ofrece distintos esquemas de free tier (algunas cuentas nuevas ya no incluyen `t2.micro`). Verifícalo antes de aplicar:

```powershell
aws ec2 describe-instance-types --filters "Name=free-tier-eligible,Values=true" --query "InstanceTypes[].InstanceType" --output table --region us-east-1
```

Si `t3.micro` no aparece en la lista (o aparece otro tipo), ajusta la variable `instance_type` en `terraform.tfvars`. Por defecto el proyecto usa `t3.micro`.

---

## 1. Configurar variables del proyecto

```powershell
cd terraform
copy terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` y completa:

```hcl
aws_region  = "us-east-1"
my_ip       = "<TU_IP_PUBLICA>/32"
db_password = "UnaClaveSegura123!"
secret_key  = "<pega aquí una clave nueva, distinta a la de tu .env local>"
```

Puedes generar un `secret_key` con:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(50))"
```

`terraform.tfvars` **no se sube a git** (ya está en `.gitignore`).

---

## 2. Desplegar la infraestructura

```powershell
terraform init      # descarga los providers de AWS y TLS
terraform plan       # revisa qué se va a crear, no cambia nada todavía
terraform apply      # crea la infraestructura real en tu cuenta AWS
```

`apply` te pedirá confirmar escribiendo `yes`. Tarda unos 5-8 minutos (la RDS demora en quedar `available`).

> **Nota:** el campo `description` de los Security Groups en la API de AWS solo acepta caracteres ASCII (sin tildes ni "ñ"). Los archivos de este repo ya vienen así; si editas las descripciones, evita acentos.

Al terminar, Terraform imprime:

```
ec2_public_ip = "..."
app_url       = "http://<ip>:8000"
ssh_command   = "ssh -i lendin-key.pem ubuntu@<ip>"
rds_endpoint  = "..."
```

---

## 3. Verificar el despliegue

### 3.1 Acceso por SSH (demuestra credenciales + seguridad)

```powershell
ssh -i lendin-key.pem ubuntu@<ec2_public_ip>
```

Dentro de la instancia puedes confirmar que el contenedor está corriendo:

```bash
sudo docker ps
sudo docker logs lendin-web
```

### 3.2 Acceso a la app vía navegador

Abre `http://<ec2_public_ip>:8000/login/` en tu navegador. El arranque (`user_data`) ya corrió las migraciones, así que puedes crear un superusuario para entrar:

> Django rechaza por defecto peticiones a un host que no esté en `ALLOWED_HOSTS` (error 400). `mysite/settings.py` ahora lee `ALLOWED_HOSTS` desde la variable de entorno `DJANGO_ALLOWED_HOSTS` (separada por comas), y `user_data.sh.tpl` la fija en `*` para la EC2. En local/Docker Compose/CI, al no definir esa variable, el comportamiento no cambia.

```bash
sudo docker exec -it lendin-web python manage.py createsuperuser
```

### 3.3 Confirmar que la RDS no es accesible desde tu PC

Desde tu máquina local (no desde la EC2), intenta:

```powershell
mysql -h <rds_endpoint> -u admin -p
```

Debe **fallar por timeout** (el Security Group de la RDS solo acepta conexiones desde el Security Group de la EC2, nunca desde internet). Esto es lo que demuestra el requisito de seguridad de la rúbrica. Repite el mismo comando pero ejecutándolo *dentro* de la EC2 (por SSH) y ahí sí debería conectar.

---

## 4. Apagar la infraestructura al terminar

Para no seguir consumiendo horas del free tier (o generar costos si te excedes):

```powershell
terraform destroy
```

Confirma con `yes`. Esto elimina la EC2, la RDS, los Security Groups y el key pair creados.

---

## Resumen de arquitectura

```
                    Internet
                       │
        22 (solo tu IP) │ 8000 (público)
                       ▼
              ┌──────────────────┐
              │   EC2 (Ubuntu)   │
              │  docker: Django  │
              └────────┬─────────┘
                       │ 3306 (solo desde el SG de la EC2)
                       ▼
              ┌──────────────────┐
              │   RDS MySQL 8.0  │
              │ publicly_accessible = false │
              └──────────────────┘
```
