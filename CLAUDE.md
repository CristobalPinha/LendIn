# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

LendIn is a Django web app for managing employee loans within an organization: admin dashboard, approval workflow, installment (cuota) tracking, and a REST API. Django templates + custom CSS for the web UI, Django REST Framework for `/api/`.

## Commands

```bash
# Run the dev server (requires MySQL reachable per env vars below)
python manage.py runserver

# Run all tests
python manage.py test myapp --verbosity=2

# Run a single test class or method
python manage.py test myapp.tests.ValidarRutTest --verbosity=2
python manage.py test myapp.tests.ValidarRutTest.test_rut_valido_sin_puntos --verbosity=2

# Migrations
python manage.py migrate
python manage.py makemigrations myapp

# Docker (runs migrations automatically, app on http://127.0.0.1:8000)
docker compose up
docker compose down
```

Windows without Docker: activate the venv with `.\venvPE\Scripts\Activate.ps1` before running the above.

### Environment variables

Read via `python-dotenv` from `.env` (see `mysite/settings.py`): `SECRET_KEY`, `DB_ENGINE` (default `django.db.backends.mysql`), `DB_NAME` (default `prestamos_empleados`), `DB_USER` (default `root`), `DB_PASSWORD`, `DB_HOST` (default `localhost`; use `db` when running via docker-compose), `DB_PORT` (default `3306`). CI (`.github/workflows/test.yml`) sets these directly and points at a `lendin_test` MySQL service.

## Architecture

Single Django app (`myapp`) inside project `mysite`. Everything — models, views, forms, serializers, services, admin — lives flat in `myapp/`, not split into sub-apps.

**Data model** (`myapp/models.py`): `Comuna` → `Empleado` (RUT chileno as primary key, not an integer id) → `Prestamo` → `Cuota`, plus `TipoPrestamo` (defines `tasa_de_interes`). `Prestamo.save()` computes `monto_pagar` from `monto_prestamo` and the related `TipoPrestamo.tasa_de_interes` the first time it's saved. `Cuota.estado` is a computed property (`Pagada` / `Vencida` / `Al día`), not a stored field — it depends on `cuota_fecha_pago` and `cuota_fecha_vencimiento` vs `timezone.now()`.

**Loan lifecycle**: a `Prestamo` starts `pendiente`. `loan_approve` (myapp/views.py) transitions it to `aprobado` and calls `services.generar_cuotas()`, which bulk-creates `Cuota` rows (monthly, 30-day increments, `monto_pagar // cantidad_cuotas` per installment). `loan_reject` transitions to `rechazado`. Cuotas are only ever generated on approval, never regenerated or recalculated afterward.

**RUT validation** (`myapp/forms.py::validar_rut`): normalizes (strips dots/spaces, uppercases `k`→`K`), then verifies the check digit with the Módulo 11 algorithm. Called from `EmpleadoForm.clean_RUT_empleado`. This is the one piece of nontrivial business logic outside the loan flow — reuse it rather than re-deriving RUT validation elsewhere.

**Views** (`myapp/views.py`) mix three concerns in one file: server-rendered views (dashboard, employee/loan CRUD, approvals — all `@login_required`), DRF `ModelViewSet`s registered on a `DefaultRouter` in `mysite/urls.py` under `/api/` (the `PrestamoViewSet.cuotas` action exposes `GET /api/prestamos/{id}/cuotas/` since cuotas otherwise only nest inside the loan serializer), and export views (`export_excel`/`export_pdf`) that build `openpyxl`/`reportlab` documents from a `Prestamo`'s cuotas.

**Sidebar badge**: `myapp/context_processors.py::sidebar_context` injects the count of pending loans into every template's context (registered in `TEMPLATES.OPTIONS.context_processors` in settings.py) — this is how the sidebar "pending approvals" badge stays in sync without each view fetching it manually.

**Auth**: no self-registration; users are created via `/admin/` or `createsuperuser`. All non-auth, non-API views require login (`LOGIN_URL = '/login/'`), enforced per-view with `@login_required` rather than middleware.

**Migrations of note**: `0002_cargar_comunas_santiago.py` and `0003_cargar_tipos_prestamo.py` are data migrations that seed `Comuna` and `TipoPrestamo` — required reference data, not schema changes.

**AWS deployment**: `terraform/` provisions an EC2 instance (Ubuntu, Docker) plus an RDS MySQL instance, with the RDS security group only accepting traffic from the EC2's security group (not the public internet). `terraform/user_data.sh.tpl` bootstraps the EC2: installs Docker, `git clone`s this repo, builds the image, runs migrations, and starts the container with env vars pointing at the RDS endpoint — including `DJANGO_ALLOWED_HOSTS=*`, which `mysite/settings.py` reads (falls back to `[]` when unset, so local/Docker Compose/CI are unaffected). Full step-by-step instructions (including AWS account/IAM setup) are in `MANUAL_DESPLIEGUE_AWS.md`. `terraform/terraform.tfvars` holds secrets (DB password, Django secret key, allowed SSH IP) and is gitignored.

Adjustments discovered only by deploying against a real AWS account (not obvious from the Terraform code alone): the EC2 security group's `description` field must be pure ASCII (AWS rejects accented characters); the free-tier-eligible instance type isn't fixed across accounts — `t2.micro` was rejected on this account (`InvalidParameterCombination`) in favor of `t3.micro`, so check `aws ec2 describe-instance-types --filters "Name=free-tier-eligible,Values=true"` before assuming a type; and `ALLOWED_HOSTS` (see above) is what turns a working `docker ps` into an actually-reachable app — a `200` on `/login/` doesn't follow automatically from the container being up.
