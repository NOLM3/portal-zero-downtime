locals {
  # La version del portal se lee del archivo VERSION, compartido con azure/.
  portal_version = trimspace(file("${path.root}/VERSION"))
}
