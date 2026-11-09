terraform {
  backend "s3" {
    bucket       = "portal-zd-tfstate-943830680153"
    key          = "portal-zero-downtime/azure.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
