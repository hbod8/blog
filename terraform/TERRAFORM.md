# Infrastructure

S3 + CloudFront + Route 53 for harrysaliba.com. The bucket is private and
CloudFront reads it via Origin Access Control. `www` redirects to the apex.
The Route 53 zone also holds the Fastmail mail records, so DNS changes go in
`route53.tf`.

Run from this directory with your own AWS credentials:

```
eval "$(aws configure export-credentials --format env)"  # aws login sessions aren't read by the provider
terraform plan
terraform apply
```

State is local (`terraform.tfstate`, gitignored).

## Deploying

The archive photos live on the drive behind the `assets` symlink, so deploy
from this machine with it mounted:

```
hugo --minify --cleanDestinationDir && hugo deploy
```

`--cleanDestinationDir` keeps stale files in `public/` from being uploaded.
`hugo deploy` needs a `withdeploy` Hugo build (Homebrew's has it) and uses the
`deployment` block in `config.yaml`.
