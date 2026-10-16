output "site_url" {
  description = "URL of the static website"
  value       = "https://${local.primary_fqdn}"
}

output "www_redirect_url" {
  description = "URL that redirects to the primary site"
  value       = "https://${local.redirect_fqdn}"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket holding site content"
  value       = aws_s3_bucket.site.id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID. Set as cloudFrontDistributionID under `deployment` in config.yaml."
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name. Serves the site before DNS cutover, for testing."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "acm_validation_records" {
  description = "CNAMEs to add at the current DNS host so the certificate validates before nameservers move to Route 53"
  value = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}

output "route53_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = aws_route53_zone.site.zone_id
}

output "route53_name_servers" {
  description = "Name servers for the created hosted zone. Update these at your domain registrar."
  value       = aws_route53_zone.site.name_servers
}
