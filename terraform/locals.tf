locals {
  environment = terraform.workspace == "default" ? "test" : terraform.workspace
}
