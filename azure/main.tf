module "app_azure" {
  source = "../modules/app_azure"

  name           = "portal"
  location       = var.azure_location
  portal_version = local.portal_version
  vm_size        = "Standard_B2ats_v2"
  instance_count = 1
}
