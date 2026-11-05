# NOLME WEB STATION — Portal Zero-Downtime

Proyecto de práctica para la Evaluación Taller 2 (ET2) de Automatización de Infraestructura con IaC (IC106TICL).

## Objetivo

Desplegar en AWS un portal web con Terraform y actualizarlo a una nueva versión **sin que el servicio se interrumpa**, comprobándolo con health checks, con evidencia de continuidad y con un rollback a la versión anterior.

## Estado actual

- Red con dos subredes públicas en dos zonas de disponibilidad.
- Balanceador de carga (ALB) con health check.
- Dos servidores EC2 con el portal, uno por zona.
- Cambio de versión por reemplazo de servidores (infraestructura inmutable), con gates de salud y de drenaje.
- Estado de Terraform guardado en S3, con bloqueo.
- Evidencia de dos pruebas de continuidad: sin gates y con gates.

## Arquitectura

    Usuario
      │  http://<dirección del ALB>
      ▼
    ALB (puerto 80) ── health check a /health cada 10 s
      │
      ├──► EC2 portal-web-1 (subred 1, zona a)
      └──► EC2 portal-web-2 (subred 2, zona b)

Los usuarios siempre entran por la dirección del ALB. El ALB reparte las visitas solo entre los servidores que pasan el health check, así que se pueden reemplazar servidores por detrás sin que la dirección cambie.

## Estructura

    portal-zero-downtime/
    ├── .gitignore
    ├── .terraform.lock.hcl
    ├── README.md
    ├── backend.tf
    ├── main.tf
    ├── outputs.tf
    ├── providers.tf
    ├── variables.tf
    ├── versions.tf
    ├── evidencias/
    │   ├── continuidad-v1-v2.log
    │   └── continuidad-v2-v1.log
    └── modules/
        ├── network/
        │   ├── main.tf
        │   ├── outputs.tf
        │   ├── variables.tf
        │   └── versions.tf
        └── app/
            ├── compute.tf
            ├── main.tf
            ├── outputs.tf
            ├── user_data.sh.tpl
            ├── variables.tf
            └── versions.tf

## Qué hace cada archivo

### Módulo raíz

Es la carpeta principal, desde donde se ejecutan los comandos de Terraform.

- **`versions.tf`**: la versión de Terraform y del provider de AWS. `~> 6.0` acepta cualquier versión 6.x, pero no la 7.
- **`providers.tf`**: configura el provider de AWS, con la región y las etiquetas (`default_tags`) que se agregan a todos los recursos. El provider se configura **solo aquí**, y los módulos lo heredan.
- **`backend.tf`**: le dice a Terraform que guarde su estado en el bucket S3 `portal-zd-tfstate-943830680153`, cifrado y con bloqueo (`use_lockfile`), para que dos ejecuciones no lo modifiquen al mismo tiempo.
- **`variables.tf`**: la región y la **versión del portal** (`portal_version`). Para cambiar de versión, solo se cambia este valor.
- **`main.tf`**: llama a los módulos `network` y `app`, y conecta los IDs que entrega la red con el módulo de la aplicación.
- **`outputs.tf`**: muestra la dirección del portal (`portal_url`) y el ARN del target group.
- **`.terraform.lock.hcl`**: la versión exacta del provider descargado.
- **`.gitignore`**: lo que nunca se sube a GitHub: el estado, la carpeta `.terraform/` y los archivos `*.tfvars`.

### Módulo `network`

Crea la red: una VPC (`10.20.0.0/16`), un internet gateway, dos subredes públicas (`10.20.1.0/24` y `10.20.2.0/24`) en zonas distintas y la tabla de rutas hacia internet. Son dos subredes porque el ALB exige al menos dos zonas.

### Módulo `app`

- **`main.tf`**: el balanceador y sus piezas.
  - Security group del ALB: deja entrar el puerto 80 desde internet.
  - Security group de los servidores: deja entrar el puerto 80 **solo desde el ALB**.
  - ALB en las dos subredes.
  - Target group con el **health check**: visita `/health` cada 10 segundos. Con 2 respuestas `200` seguidas marca el servidor como sano; con 2 fallas, deja de mandarle tráfico. El **drenaje** (`deregistration_delay`) es de 30 segundos.
  - Listener: lo que llega al puerto 80 se manda al target group.
- **`compute.tf`**: los servidores y su inscripción en el target group, con los gates (ver más abajo).
- **`user_data.sh.tpl`**: el script de arranque de cada servidor. Crea la página del portal y la sirve con Python en el puerto 80, como servicio del sistema. Expone tres rutas:
  - `/`: la página, con la versión y el nombre del servidor.
  - `/health`: la respuesta que revisa el health check.
  - `/version`: solo la versión, para medir la continuidad.

## Cómo se cambia de versión

1. Se cambia `portal_version` en `variables.tf` y se hace commit.
2. Como el script de arranque cambia, `user_data_replace_on_change` hace que Terraform **no modifique** los servidores, sino que cree servidores nuevos y borre los viejos (infraestructura inmutable).
3. `create_before_destroy` hace que los nuevos se creen **antes** de borrar los viejos.

Volver a una versión anterior en Git no cambia la infraestructura por sí solo: después del commit hay que ejecutar `plan` y `apply`.

## Gates

`create_before_destroy` ordena crear antes de destruir, pero no sabe nada del ALB. Por eso se agregaron dos esperas con `provisioner "local-exec"`, que ejecutan un comando de AWS CLI y no dejan avanzar a Terraform hasta que se cumpla:

- **Gate de entrada** (en la inscripción del servidor nuevo): `aws elbv2 wait target-in-service`. Terraform no saca a un servidor viejo hasta que el nuevo esté `healthy` en el ALB.
- **Gate de salida** (al destruir un servidor viejo): `aws elbv2 wait target-deregistered`. Terraform no apaga el servidor hasta que el ALB termine de sacarlo y de drenar sus visitas. Como un provisioner de destrucción solo puede usar datos del propio recurso, cada servidor lleva en la etiqueta `TargetGroupArn` el target group del que tiene que salir.

## Pruebas de continuidad

Durante cada cambio, un monitor consultó `/version` a través del ALB una vez por segundo y registró la hora, el código HTTP y la versión que respondió.

**Prueba 1: v1 → v2, solo con `create_before_destroy`** (`evidencias/continuidad-v1-v2.log`)

- 197 respuestas `200 v1` y 59 respuestas `200 v2`.
- **1 falla**: un `502 Bad Gateway` a las 14:02:20.
- Causa probable: Terraform apagó un servidor viejo inmediatamente después de sacarlo del ALB, mientras el ALB todavía le mandaba una visita.

**Prueba 2: v2 → v1 (rollback), con los gates** (`evidencias/continuidad-v2-v1.log`)

- 102 respuestas `200 v2` y 63 respuestas `200 v1`.
- **0 fallas.**

**Conclusión:** `create_before_destroy` por sí solo no garantiza continuidad. Con los gates de salud y de drenaje, no se observaron interrupciones.

**Limitación:** el monitor consulta una vez por segundo, así que no puede descartar una falla entre dos consultas. Lo que se puede afirmar es que no se observaron interrupciones con muestreo de 1 segundo durante la prueba.

## Cómo levantarlo

1. Iniciar el Learner Lab y copiar las credenciales en `~/.aws/credentials`.
2. Comprobar el acceso con `aws sts get-caller-identity`.
3. Generar y aplicar el plan:

        terraform init
        terraform plan -out=/tmp/portal.tfplan
        terraform apply /tmp/portal.tfplan

4. Esperar a que los servidores estén `healthy` y abrir la dirección que muestra `terraform output -raw portal_url`.

Se usa `plan -out` y después `apply` del archivo guardado para que Terraform aplique **exactamente** el plan que se revisó.

## Cómo destruirlo

    terraform plan -destroy -out=/tmp/destroy.tfplan
    terraform apply /tmp/destroy.tfplan

El bucket del estado no se borra, porque se creó fuera de Terraform con AWS CLI.

## Git

El ciclo de trabajo es: modificar archivos → `git add` → `git commit` → `git push`. Los mensajes usan prefijos: `feat:` para algo nuevo, `fix:` para una corrección, `docs:` para documentación, `chore:` para mantenimiento y `revert:` para volver atrás.

## Próximos pasos

1. Agregar el portal en Azure con el provider `azurerm`, para que el proyecto sea multi-cloud.
2. Agregar un pipeline de GitHub Actions con revisiones, plan, aprobación manual y apply.
