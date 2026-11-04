variable "name" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se crean los recursos"
  type        = string
}

variable "subnet_ids" {
  description = "IDs de las subredes publicas para el ALB y los servidores"
  type        = list(string)
}

variable "portal_version" {
  description = "Version del portal que se despliega en los servidores"
  type        = string
}

variable "instance_count" {
  description = "Cantidad de servidores detras del ALB"
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"
}
