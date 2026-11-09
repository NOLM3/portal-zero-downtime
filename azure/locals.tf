locals {
  # El mismo archivo VERSION de la carpeta principal.
  portal_version = trimspace(file("${path.root}/../VERSION"))
}
