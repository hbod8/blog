resource "aws_route53_zone" "site" {
  name = var.domain_name
}

resource "aws_route53_record" "site_ipv4" {
  zone_id = aws_route53_zone.site.zone_id
  name    = local.primary_fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "site_ipv6" {
  zone_id = aws_route53_zone.site.zone_id
  name    = local.primary_fqdn
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_redirect_ipv4" {
  zone_id = aws_route53_zone.site.zone_id
  name    = local.redirect_fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.www_redirect.domain_name
    zone_id                = aws_cloudfront_distribution.www_redirect.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_redirect_ipv6" {
  zone_id = aws_route53_zone.site.zone_id
  name    = local.redirect_fqdn
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.www_redirect.domain_name
    zone_id                = aws_cloudfront_distribution.www_redirect.hosted_zone_id
    evaluate_target_health = false
  }
}

# Mail is hosted by Fastmail; removing these breaks delivery and DKIM.

resource "aws_route53_record" "mx" {
  zone_id = aws_route53_zone.site.zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 3600
  records = [
    "10 in1-smtp.messagingengine.com.",
    "20 in2-smtp.messagingengine.com.",
  ]
}

# Route 53 allows one TXT record set per name, so SPF and the Google Search
# Console verification share it.
resource "aws_route53_record" "apex_txt" {
  zone_id = aws_route53_zone.site.zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 3600
  records = [
    "v=spf1 include:spf.messagingengine.com ?all",
    "google-site-verification=FJf5QGuJfFjg6wQdGdcSs68ImWAAsUEk2e2sOVsrqL8",
  ]
}

# Fastmail rotates DKIM keys behind these CNAMEs, so they point at
# Fastmail's hosted records rather than holding the keys themselves.
resource "aws_route53_record" "fastmail_dkim" {
  for_each = toset(["fm1", "fm2", "fm3"])

  zone_id = aws_route53_zone.site.zone_id
  name    = "${each.key}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 3600
  records = ["${each.key}.${var.domain_name}.dkim.fmhosted.com"]
}
