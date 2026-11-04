# Portal Zero-Downtime

Proyecto de práctica para la Evaluación Taller 2 (ET2) de Automatización de Infraestructura con IaC (IC106TICL).

## Objetivo

Desplegar en AWS un portal web con Terraform y actualizarlo a una nueva versión **sin que el servicio se interrumpa**, comprobándolo con health checks y con un plan para volver a la versión anterior (rollback) si algo falla.

## Estado actual

Por ahora el proyecto tiene:

- La configuración base de Terraform y del provider de AWS.
- Un módulo de red con una VPC y dos subredes públicas en dos zonas de disponibilidad.

Todavía no se ha creado nada en AWS: el código está escrito y validado, pero no se ha ejecutado `terraform apply`.

## Estructura

    portal-zero-downtime/
    ├── .gitignore
    ├── .terraform.lock.hcl
    ├── README.md
    ├── main.tf
    ├── providers.tf
    ├── variables.tf
    ├── versions.tf
    └── modules/
        └── network/
            ├── main.tf
            ├── outputs.tf
            ├── variables.tf
            └── versions.tf

## Qué hace cada archivo

### Módulo raíz

Es la carpeta principal, desde donde se ejecutan los comandos de Terraform.

- **`versions.tf`**: indica qué versión de Terraform y del provider de AWS necesita el proyecto. `~> 6.0` acepta cualquier versión 6.x del provider, pero no la 7.
- **`providers.tf`**: configura el provider de AWS: la región y las etiquetas (`default_tags`) que se agregan automáticamente a todos los recursos. El provider se configura **solo aquí**, y los módulos lo heredan.
- **`variables.tf`**: los valores que se pueden cambiar sin tocar el resto del código. Por ahora, solo la región (`us-east-1`).
- **`main.tf`**: llama a los módulos y les entrega los valores que necesitan.
- **`.terraform.lock.hcl`**: lo crea `terraform init`. Anota la versión exacta del provider descargado, para que siempre se use la misma.
- **`.gitignore`**: lista lo que **nunca** se sube a GitHub: el estado de Terraform (`*.tfstate`), la carpeta `.terraform/` con el provider descargado y los archivos de variables con datos privados (`*.tfvars`).

### Módulo `network`

Un módulo es una carpeta con código Terraform reutilizable. Este crea la red donde va a vivir el portal.

- **`versions.tf`**: los requisitos del módulo. Usa `>= 6.0` ("como mínimo la 6.0") para que la versión exacta la decida el módulo raíz. **No tiene bloque `provider`**: lo hereda.
- **`variables.tf`**: lo que el módulo recibe desde afuera: un prefijo para los nombres, el rango de IP de la VPC y los rangos de las subredes.
- **`main.tf`**: los recursos de la red.
- **`outputs.tf`**: lo que el módulo entrega hacia afuera: el ID de la VPC y los IDs de las subredes, que van a necesitar el balanceador y los servidores.

## La red

El módulo `network` crea siete recursos:

1. **VPC** (`10.20.0.0/16`): la red privada donde vive todo.
2. **Internet gateway**: la puerta entre la VPC e internet.
3. **Dos subredes públicas** (`10.20.1.0/24` y `10.20.2.0/24`), cada una en una zona de disponibilidad distinta. Son dos porque el balanceador de carga (ALB) exige al menos dos zonas, y porque si una zona falla, la otra sigue funcionando.
4. **Tabla de rutas**: dice que todo el tráfico hacia internet (`0.0.0.0/0`) sale por el internet gateway.
5. **Dos asociaciones**: conectan cada subred con la tabla de rutas.

Dos conceptos que aparecen en el código:

- **`data "aws_availability_zones"`**: un bloque `data` no crea nada, solo **consulta** a AWS. Aquí pregunta qué zonas están disponibles en la región.
- **`count`**: crea el mismo recurso varias veces. `count.index` vale 0 en la primera copia y 1 en la segunda, y sirve para elegir el rango de IP y la zona de cada subred.

## Comandos usados

- `terraform init`: prepara la carpeta y descarga el provider. Se vuelve a ejecutar cada vez que se agrega un módulo.
- `terraform fmt -recursive`: ordena el formato del código, también dentro de `modules/`.
- `terraform validate`: revisa que el código esté bien escrito, sin conectarse a AWS.
- `terraform plan`: consulta a AWS y muestra qué se crearía, sin crear nada.

## Git

El ciclo de trabajo es: modificar archivos → `git add` (elegir qué entra en la foto) → `git commit` (tomar la foto con un mensaje) → `git push` (enviarla a GitHub).

Los mensajes de commit usan prefijos: `feat:` para algo nuevo, `fix:` para una corrección, `docs:` para documentación y `chore:` para tareas de mantenimiento.

## Próximos pasos

1. Conectar con el Learner Lab y probar `terraform plan`.
2. Agregar un balanceador de carga (ALB) con health check.
3. Agregar dos servidores EC2 con el portal, que muestren su versión.
4. Cambiar de la versión `v1` a la `v2` reemplazando servidores (infraestructura inmutable), sin que el portal deje de responder.
5. Registrar la evidencia de continuidad: consultas al portal antes, durante y después del cambio.
6. Probar un rollback a `v1`.
7. Agregar un pipeline de GitHub Actions.
