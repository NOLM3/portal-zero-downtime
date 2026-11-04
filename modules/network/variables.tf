variable "name" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
}

variable "vpc_cidr" {
  description = "Rango de IP de la VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Rangos de IP de las subredes publicas, una por zona"
  type        = list(string)
}
