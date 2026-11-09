variable "region" {
  description = "Region de AWS donde se despliega el portal"
  type        = string
  default     = "us-east-1"
}

variable "enable_azure" {
  description = "Despliega tambien el portal en Azure. Solo desde un equipo con az login"
  type        = bool
  default     = false
}

variable "azure_location" {
  description = "Region de Azure donde se despliega el portal"
  type        = string
  default     = "northcentralus"
}

variable "portal_version" {
  description = "Version del portal que se despliega"
  type        = string
  default     = "v2"
}
