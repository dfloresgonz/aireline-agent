locals {
  name_prefix = "${var.project}-${var.env}"

  common_tags = {
    project    = var.project
    env        = var.env
    owner      = var.owner
    managed-by = "terraform"
  }
}
