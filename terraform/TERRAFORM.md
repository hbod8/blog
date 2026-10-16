# Static site on S3 + CloudFront + Route 53

Creates a private S3 bucket for content, a CloudFront distribution in front
of it (via Origin Access Control), an ACM certificate for SSL, a second
CloudFront distribution that 301s `www.` to the apex, and a new Route 53
hosted zone. The zone also carries the Fastmail mail records that previously
lived at Hover.

There are no IAM users or roles here. Terraform and `hugo deploy` both run
from your own machine with your own AWS credentials.

All Terraform config lives in this `terraform/` directory; run all commands
below from here.

## Migrating from the VPS

The goal is to have CloudFront serving the site with a valid certificate
*before* DNS moves, so the cutover is just a nameserver change.

1. **Lower TTLs at Hover** a day ahead, if they're long, so the cutover
   propagates quickly.

2. **Request the certificate and add its validation records at Hover.** The
   new Route 53 zone isn't authoritative yet, so ACM can't see the validation
   records Terraform puts there.

   ```
   terraform init
   terraform apply -target=aws_acm_certificate.site
   terraform output acm_validation_records
   ```

   Add each CNAME from that output at Hover. You can delete them after the
   nameserver switch, since the Route 53 zone has the same records.

3. **Apply everything else.** The `aws_acm_certificate_validation` step
   waits until ACM sees the Hover records, which usually takes a few minutes.

   ```
   terraform apply
   ```

4. **Set the distribution ID** in `../config.yaml` under
   `deployment.targets[0].cloudFrontDistributionID`:

   ```
   terraform output -raw cloudfront_distribution_id
   ```

5. **Upload the site** (see [Deploying](#deploying)). The first upload is
   the full ~6 GB `public/`.

6. **Test before cutover** at `https://<cloudfront_domain_name>/`. That
   hostname serves the same content without needing DNS.

7. **Switch nameservers at Hover** to the four values in
   `terraform output route53_name_servers`. The domain stays registered at
   Hover; only DNS moves. Afterwards, check that mail still flows and
   `dig MX harrysaliba.com` returns the Fastmail hosts.

8. Once the old records' TTL has passed and traffic has drained, **shut down
   the VPS**.

## Deploying

The archive photos live on the external drive behind the `assets` symlink,
so builds happen locally with the drive mounted:

```
hugo --minify --cleanDestinationDir && hugo deploy
```

`--cleanDestinationDir` matters: `hugo deploy` mirrors `public/` exactly,
so stale files left over from old builds would otherwise be uploaded too.
`hugo deploy` syncs to the bucket and invalidates CloudFront using the
`deployment` block in `config.yaml`. It needs a Hugo binary built with the
`withdeploy` tag. The Homebrew build has it; the stock GitHub release
binaries do not.

Add `--dryRun` to `hugo deploy` to see what would change without uploading
anything.

GitHub Actions (`.github/workflows/build.yml`) only runs a build check on PRs
and pushes to `main`, without the photos. It never touches AWS.

## Notes

- The S3 bucket is fully private; CloudFront reaches it via Origin Access
  Control (OAC), not a public bucket policy or website endpoint.
- The bucket is versioned, so a bad deploy can be rolled back. Noncurrent
  versions expire after 30 days to keep storage from growing.
- The ACM certificate is requested in `us-east-1` regardless of `aws_region`,
  since CloudFront requires that.
- Missing pages (S3 returns 403 for these through OAC) are served as
  `/404.html` with a 404 status.
- If you add DNS records (e.g. a new mail or verification TXT), add them in
  `route53.tf`. Route 53, not Hover, is authoritative after cutover.
