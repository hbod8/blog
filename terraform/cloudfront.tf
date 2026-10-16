resource "aws_acm_certificate" "site" {
  provider                  = aws.us_east_1
  domain_name               = local.primary_fqdn
  subject_alternative_names = [local.redirect_fqdn]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# These land in the new Route 53 zone, but until the registrar's nameservers
# point at that zone ACM can't see them. During the migration the same
# records are added by hand at the current DNS host (see TERRAFORM.md and the
# acm_validation_records output) so the certificate validates before cutover.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.site.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "site" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${local.primary_fqdn}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# The S3 REST origin (required for OAC) never appends index.html to
# directory-style requests the way an S3 website endpoint would - only the
# distribution root gets that via default_root_object. This function
# replicates that behavior for every other path so pretty-URL pages
# (e.g. /archive/, /post/bulk-rolling/) resolve instead of 403ing.
resource "aws_cloudfront_function" "index_rewrite" {
  name    = "${replace(local.primary_fqdn, ".", "-")}-index-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Append index.html to directory-style requests"
  publish = true
  code    = file("${path.module}/functions/index-rewrite.js")
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [local.primary_fqdn]
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.site.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${aws_s3_bucket.site.id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.index_rewrite.arn
    }
  }

  # A missing key comes back from S3 as 403, not 404, because the OAC
  # principal has no s3:ListBucket. Serve Hugo's 404 page with a real 404
  # status for both, so broken links don't look like successful pages.
  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# www.<domain> redirects to the apex domain via a CloudFront distribution in
# front of an S3 website-redirect bucket (for HTTPS, since S3 website
# endpoints are HTTP-only). See s3.tf for the bucket itself.
resource "aws_cloudfront_distribution" "www_redirect" {
  enabled         = true
  is_ipv6_enabled = true
  aliases         = [local.redirect_fqdn]
  price_class     = "PriceClass_100"

  origin {
    domain_name = aws_s3_bucket_website_configuration.www_redirect.website_endpoint
    origin_id   = "s3-website-${aws_s3_bucket.www_redirect.id}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-website-${aws_s3_bucket.www_redirect.id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
