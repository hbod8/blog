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
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.site.domain_name
}

output "route53_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = aws_route53_zone.site.zone_id
}

output "route53_name_servers" {
  description = "Name servers for the created hosted zone. Update these at your domain registrar."
  value       = aws_route53_zone.site.name_servers
}
