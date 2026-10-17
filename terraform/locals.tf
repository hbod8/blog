locals {
  # Domain served as the canonical site (apex) vs. the one that 301s to it.
  # Matches the previous nginx setup on the VPS.
  primary_fqdn  = var.domain_name
  redirect_fqdn = "www.${var.domain_name}"
}
