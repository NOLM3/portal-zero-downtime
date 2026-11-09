module "network" {
  source = "./modules/network"

  name                = "portal"
  vpc_cidr            = "10.20.0.0/16"
  public_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]
}

module "app" {
  source = "./modules/app"

  name           = "portal"
  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.public_subnet_ids
  portal_version = local.portal_version
}
