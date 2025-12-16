# HeroDevs Windows 2022 runner image

This fork builds a single Windows Server 2022 GitHub Actions runner image on AWS. It reuses the upstream images published by [runs-on/runner-images-for-aws](https://github.com/runs-on/runner-images-for-aws) and layers two changes on top via Packer:

- Installs Docker Desktop with Chocolatey so GitHub Actions can run `docker build` and related tooling out of the box.
- Enables the Hyper-V Windows feature (and Containers) so virtualization workloads continue to run correctly.

Images are published with the `herodevs` AMI prefix and use the upstream `runs-on-v2.2-windows22-full-x64-*` images as the source AMI.

## Building locally

1. Install Packer and Ruby (Bundler will install dependencies from the included `Gemfile`).
2. Configure AWS credentials and set a subnet that auto-assigns public IPs:

```bash
export AWS_DEFAULT_REGION=us-east-1
export SUBNET_ID=subnet-xxxxxxxx
export AMI_PREFIX=herodevs
bundle install
bundle exec bin/build --image-id windows22-docker-hyperv-x64
```

The `bin/build` helper copies the Packer template from `patches/windows/templates/windows22-docker-hyperv-x64.pkr.hcl` into the upstream release layout before invoking `packer build`.

## Automation

`.github/workflows/windows-runner.yml` builds the image on pull requests, pushes to `main`, and on a weekly schedule. The scheduled run also calls `bin/utils/cleanup-amis` to remove old AMIs that share the `herodevs` prefix.

A lightweight Go build/test job is included and runs when Go sources are present so downstream changes can add Go-based helpers without breaking the pipeline.
