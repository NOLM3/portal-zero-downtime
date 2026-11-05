variable "region" {
  description = "Region de AWS donde se despliega el portal"
  type        = string
  default     = "us-east-1"
}

variable "azure_location" {
  description = "Region de Azure donde se despliega el portal"
  type        = string
  default     = "northcentralus"
}

variable "portal_version" {
  description = "Version del portal que se despliega"
  type        = string
  default     = "v1"
}
