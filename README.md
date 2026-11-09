# NOLME WEB STATION — Portal Zero-Downtime multi-cloud

Proyecto de práctica para la Evaluación Taller 2 (ET2) de Automatización de Infraestructura con IaC (IC106TICL).

## Objetivo

Desplegar un portal web en **AWS y Azure** desde un solo proyecto Terraform, y actualizarlo a una nueva versión **sin que el servicio se interrumpa**, comprobándolo con health checks, gates, evidencia de continuidad y rollback.

## Estado actual

- **AWS:** red con dos subredes en dos zonas, balanceador (ALB) con health check y dos servidores EC2.
- **Azure:** red virtual, Load Balancer con health probe y una máquina virtual.
- Cambio de versión por reemplazo de servidores (infraestructura inmutable), con gates de entrada y de salida en las dos nubes.
- Un solo estado de Terraform, guardado en S3 con bloqueo, para los recursos de las dos nubes.
- Evidencia de tres pruebas de continuidad.

## Arquitectura

    Terraform (un solo proyecto, un solo estado en S3)
      │
      ├── provider aws ───► AWS (us-east-1)
      │                      ALB :80 ── health check /health
      │                        ├──► EC2 portal-web-1 (zona a)
      │                        └──► EC2 portal-web-2 (zona b)
      │
      └── provider azurerm ► Azure (northcentralus)
                             Load Balancer :80 ── health probe /health
                               └──► VM portal-web-1

Las dos nubes despliegan **la misma versión** del portal, controlada por una sola variable (`portal_version`), y cada una se verifica por separado a través de su propio balanceador.

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
    │   ├── continuidad-v2-v1.log
    │   ├── continuidad-aws-v1-v2.log
    │   └── continuidad-azure-v1-v2.log
    └── modules/
        ├── network/      Red de AWS
        ├── app/          ALB y servidores de AWS
        └── app_azure/    Red, Load Balancer y máquina de Azure

## Módulo raíz

- **`versions.tf`**: las versiones de Terraform y de los tres providers: `aws` (`~> 6.0`), `azurerm` (`~> 4.0`) y `tls` (`~> 4.0`), que genera la llave SSH que Azure exige para cada máquina Linux.
- **`providers.tf`**: configura el provider de AWS (región y etiquetas por defecto) y el de Azure. Los providers se configuran **solo aquí**; los módulos los heredan.
- **`backend.tf`**: guarda el estado en el bucket S3 `portal-zd-tfstate-943830680153`, cifrado y con bloqueo (`use_lockfile`).
- **`variables.tf`**: la región de AWS, la región de Azure y la **versión del portal**.
- **`main.tf`**: llama a los tres módulos y les pasa la misma versión.
- **`outputs.tf`**: las direcciones del portal en AWS (`portal_url`) y en Azure (`azure_portal_url`), y el ARN del target group.

## AWS

### Módulo `network`

VPC `10.20.0.0/16`, internet gateway, dos subredes públicas (`10.20.1.0/24` y `10.20.2.0/24`) en zonas distintas y tabla de rutas hacia internet. Son dos subredes porque el ALB exige al menos dos zonas.

### Módulo `app`

- **Security groups:** el del ALB deja entrar el puerto 80 desde internet; el de los servidores, **solo desde el ALB**.
- **ALB** en las dos subredes, con un **target group** cuyo health check visita `/health` cada 10 segundos (2 respuestas `200` para marcar sano, 2 fallas para marcar caído) y un **drenaje** de 30 segundos.
- **Dos EC2** `t3.micro` con Amazon Linux 2023, una por zona.

### Gates en AWS

Se implementan con `provisioner "local-exec"`, que ejecuta un comando de AWS CLI y no deja avanzar a Terraform hasta que se cumpla:

- **Entrada:** `aws elbv2 wait target-in-service`. Terraform no saca a un servidor viejo hasta que el nuevo esté `healthy` en el ALB.
- **Salida:** `aws elbv2 wait target-deregistered`. Terraform no apaga un servidor viejo hasta que el ALB termine de sacarlo y de drenar sus visitas. El servidor lleva en la etiqueta `TargetGroupArn` el target group del que tiene que salir, porque un provisioner de destrucción solo puede usar datos del propio recurso.

## Azure

### Módulo `app_azure`

- **Resource group** `rg-portal`, que agrupa todos los recursos de Azure del proyecto.
- **Red virtual** `10.30.0.0/16` con una subred `10.30.1.0/24`.
- **NSG** que deja entrar el puerto 80 desde internet.
- **Load Balancer Standard** con IP pública, backend pool, **health probe** HTTP a `/health` cada 5 segundos y regla TCP en el puerto 80.
- **Una máquina virtual** `Standard_B2ats_v2` con Ubuntu 24.04, que usa **el mismo script** del portal que AWS.

### Equivalencias con AWS

- VPC → Virtual Network. Security group → NSG. EC2 → máquina virtual. AMI → imagen. `user_data` → `custom_data`.
- ALB → Load Balancer. **No son iguales:** el ALB trabaja con HTTP (capa 7) y el Load Balancer de Azure con TCP (capa 4). Por eso:
  - el NSG no puede limitar el tráfico a "solo desde el balanceador", porque las conexiones llegan con la IP del usuario;
  - cuando no hay ninguna máquina sana, el ALB responde `503`, mientras que el Load Balancer de Azure no responde nada;
  - el Load Balancer de Azure **no tiene drenaje** como el ALB.
- El **resource group** no tiene un equivalente directo en AWS.

### Decisiones y límites de la cuenta de estudiante

- **Región:** la suscripción solo permite `mexicocentral`, `chilecentral`, `eastus2`, `centralus` y `northcentralus` (policy *Allowed resource deployment regions*).
- **Tamaño de máquina:** en `eastus2` toda la familia B está bloqueada para la suscripción (`NotAvailableForSubscription`), y `chilecentral` no ofrece `Standard_B1s`. Se eligió `northcentralus` con `Standard_B2ats_v2` (AMD, 2 procesadores, 1 GB).
- **Una sola máquina:** cada `Standard_B2ats_v2` usa 2 procesadores. Con dos máquinas, el reemplazo con `create_before_destroy` necesitaría 8 procesadores por un momento, más que la cuota de la suscripción. Con una máquina, el reemplazo usa 4.
- **Servicios registrados:** fue necesario registrar `Microsoft.Compute` y `Microsoft.Network` en la suscripción antes de crear máquinas y redes.
- **Nombres con la versión:** las máquinas y tarjetas de red llevan la versión en el nombre (`vm-portal-1-v1`), porque `create_before_destroy` crea la nueva antes de borrar la vieja y Azure no permite dos recursos con el mismo nombre.

### Gates en Azure

El Load Balancer de Azure no tiene un comando equivalente a `aws elbv2 wait`, así que los gates se resolvieron de otra forma:

- **Entrada (prueba funcional):** después de crear la máquina nueva, Terraform consulta `/version` **a través del balanceador** cada 5 segundos hasta recibir la versión nueva. Como el balanceador solo manda visitas a máquinas que pasan el health probe, esa respuesta prueba que la máquina está sana y atendiendo. Para que funcione, la máquina se crea **después** de quedar inscrita en el backend pool (`depends_on`).
- **Salida:** antes de borrar la máquina vieja, Terraform ejecuta dentro de ella `rm -f /opt/portal/health` con `az vm run-command`, para que el health probe falle y el balanceador la saque, y espera 30 segundos.

## Pruebas de continuidad

Durante cada cambio, un monitor consultó `/version` a través del balanceador una vez por segundo y registró la hora, el código HTTP y la versión que respondió.

**Prueba 1: AWS, v1 → v2, solo con `create_before_destroy`** (`continuidad-v1-v2.log`)
- 197 respuestas `v1` y 59 `v2`.
- **1 falla:** `502 Bad Gateway` a las 14:02:20. Terraform apagó un servidor viejo inmediatamente después de sacarlo del ALB, mientras el ALB todavía le mandaba una visita.

**Prueba 2: AWS, v2 → v1 (rollback), con gates** (`continuidad-v2-v1.log`)
- 102 respuestas `v2` y 63 `v1`.
- **0 fallas.**

**Prueba 3: AWS y Azure a la vez, v1 → v2, con gates** (`continuidad-aws-v1-v2.log` y `continuidad-azure-v1-v2.log`)
- AWS: 118 respuestas `v1` y 180 `v2`. **0 fallas.**
- Azure: 135 respuestas `v1` y 145 `v2`. **1 falla:** sin respuesta (`000`) a las 11:58:52, durante la salida de la máquina vieja. Justo antes, varias consultas tardaron más de un segundo. La causa probable es el propio gate de salida: `az vm run-command` instala y ejecuta un agente dentro de la máquina vieja, lo que la pone lenta, y el health probe todavía no la daba por caída.

**Conclusiones**

- `create_before_destroy` por sí solo no garantiza continuidad: ordena crear antes de destruir, pero no sabe nada del balanceador.
- En AWS, los gates basados en el estado del target group y en el drenaje nativo del ALB eliminaron las fallas observadas.
- En Azure, la falta de drenaje en el Load Balancer obliga a imitarlo, y la imitación usada dejó una falla. Una mejora posible es sacar la máquina del backend pool desde el balanceador (`az network nic ip-config address-pool remove`), sin ejecutar nada dentro de ella, y esperar antes de borrarla.

**Limitación:** el monitor consulta una vez por segundo, así que no puede descartar una falla entre dos consultas. Lo que se puede afirmar es lo que se observó con ese muestreo.

## Problemas encontrados

- **`Provider produced inconsistent result after apply`** en Azure: Terraform creaba un recurso y, al consultarlo justo después, Azure todavía no lo mostraba. Terraform no lo anotaba en el estado. Se resolvió importando los recursos con `terraform import` y, cuando se repitió, borrando el resource group completo (`az group delete`), sacándolo del estado (`terraform state rm module.app_azure`) y creándolo de nuevo.
- **Cambio de región en Azure:** `create_before_destroy` se contagia a las dependencias de las máquinas (tarjeta de red, subred, red y resource group). Al cambiar de región se reemplaza todo, y el resource group nuevo chocó con el viejo por tener el mismo nombre. Se resolvió destruyendo solo el módulo de Azure (`-target=module.app_azure`) y creándolo de nuevo.
- **Línea `EOF` sobrante** al final del script del portal, que la máquina intentaba ejecutar como comando. Se borró con `sed`.

## Cómo levantarlo

1. **AWS:** iniciar el Learner Lab y copiar las credenciales en `~/.aws/credentials`. Comprobar con `aws sts get-caller-identity`.
2. **Azure:** `az login` con la cuenta de estudiante. Comprobar con `az account show`.
3. Generar y aplicar el plan:

        terraform init
        terraform plan -out=/tmp/portal.tfplan
        terraform apply /tmp/portal.tfplan

4. Esperar unos minutos y probar las dos direcciones:

        curl $(terraform output -raw portal_url)/version
        curl $(terraform output -raw azure_portal_url)/version

Se usa `plan -out` y después `apply` del archivo guardado para que Terraform aplique **exactamente** el plan revisado.

## Cómo cambiar de versión

1. Cambiar `portal_version` en `variables.tf` y hacer commit.
2. `terraform plan -out=...` y `terraform apply` del plan.

Volver a una versión anterior en Git no cambia la infraestructura por sí solo: después del commit hay que ejecutar `plan` y `apply`.

## Cómo destruirlo

    terraform plan -destroy -out=/tmp/destroy.tfplan
    terraform apply /tmp/destroy.tfplan

El bucket del estado no se borra, porque se creó fuera de Terraform con AWS CLI.

## Próximo paso

Agregar un pipeline de GitHub Actions con revisiones automáticas, plan, aprobación manual y apply.
