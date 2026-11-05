variable "name" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
}

variable "location" {
  description = "Region de Azure"
  type        = string
}

variable "portal_version" {
  description = "Version del portal que se despliega en las maquinas"
  type        = string
}

variable "instance_count" {
  description = "Cantidad de maquinas detras del balanceador"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "Tamano de las maquinas virtuales"
  type        = string
  default     = "Standard_B1s"
}

variable "vnet_cidr" {
  description = "Rango de IP de la red virtual"
  type        = string
  default     = "10.30.0.0/16"
}

variable "subnet_cidr" {
  description = "Rango de IP de la subred"
  type        = string
  default     = "10.30.1.0/24"
}
