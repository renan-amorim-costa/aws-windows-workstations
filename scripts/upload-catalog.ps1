<#
.SYNOPSIS
  Uploads the local installers folder to the catalog bucket.

.DESCRIPTION
  The folder mirrors the bucket layout, and file names must match
  local.app_catalog in workstations/locals.tf:

    installers/apps/<app>/<version>/<file>
    installers/apps/7zip/24.08/7zip-x64.msi
    installers/apps/dbeaver/26.2.0/dbeaver-x64.exe

  Run after "terraform apply" in catalog/.

.EXAMPLE
  ./scripts/upload-catalog.ps1 -AwsProfile my-profile
#>
param(
  [string]$Bucket = (terraform -chdir="$PSScriptRoot/../catalog" output -raw bucket),
  [string]$Source = (Join-Path $PSScriptRoot "../installers"),
  [string]$AwsProfile
)

$ErrorActionPreference = "Stop"
$profileArgs = if ($AwsProfile) { @("--profile", $AwsProfile) } else { @() }

aws s3 sync $Source "s3://$Bucket" --exclude "*" --include "apps/*" @profileArgs
aws s3 ls "s3://$Bucket/apps/" --recursive --human-readable @profileArgs
