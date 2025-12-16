packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "ami_name" {
  type    = string
  default = "${env("AMI_NAME")}" 
}

variable "ami_description" {
  type    = string
  default = "${env("AMI_DESCRIPTION")}" 
}

variable "region" {
  type    = string
  default = "${env("AWS_DEFAULT_REGION")}" 
}

variable "ami_regions" {
  type = list(string)
}

variable "source_ami_owner" {
  type    = string
  default = "801119661308"
}

variable "source_ami_name" {
  type    = string
  default = "Windows_Server-2022-English-Full-Base-*"
}

variable "subnet_id" {
  type    = string
  default = "${env("SUBNET_ID")}" 
}

variable "volume_size" {
  type    = number
  default = 50
}

variable "volume_type" {
  type    = string
  default = "gp3"
}

variable "install_password" {
  type      = string
  default   = "P4ssw0rd@1234"
  sensitive = true
}

variable "install_user" {
  type    = string
  default = "installer"
}

variable "image_version" {
  type    = string
  default = "dev"
}

source "amazon-ebs" "build" {
  aws_polling {
    delay_seconds = 30
    max_attempts  = 300
  }

  communicator      = "winrm"
  winrm_insecure    = true
  winrm_use_ssl     = true
  winrm_username    = "Administrator"
  shutdown_behavior = "terminate"

  ami_name                = "${var.ami_name}"
  ami_description         = "${var.ami_description}"
  ami_virtualization_type = "hvm"
  ami_regions             = "${var.ami_regions}"
  snapshot_groups         = ["all"]
  force_deregister        = true
  force_delete_snapshot   = true
  temporary_security_group_source_public_ip = true

  region                      = "${var.region}"
  subnet_id                   = "${var.subnet_id}"
  associate_public_ip_address = true
  spot_price                  = "auto"
  spot_instance_types         = ["z1d.metal", "m5zn.metal", "m8a.metal-24xl", "m8a.metal-48xl", "x2iezn.metal"]
  spot_allocation_strategy    = "price-capacity-optimized"

  source_ami_filter {
    filters = {
      name                = "${var.source_ami_name}"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["${var.source_ami_owner}"]
    most_recent = true
  }

  user_data = <<USERDATA
<powershell>
Enable-PSRemoting -SkipNetworkProfileCheck -Force
winrm set winrm/config/service/auth '@{Basic="true"}'
Set-Service -Name WinRM -StartupType Automatic

$Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName "packer-windows"
Get-ChildItem WSMan:\Localhost\Listener | Where-Object Keys -eq "Transport=HTTP" | Remove-Item -Recurse
New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $Cert.Thumbprint -Force
New-NetFirewallRule -DisplayName "WinRM HTTPS" -Name "WinRM-HTTPS-In" -Profile Any -LocalPort 5986 -Protocol TCP

Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Set-Service -Name sshd -StartupType Manual
</powershell>
<persist>false</persist>
USERDATA

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = "${var.volume_type}"
    volume_size           = "${var.volume_size}"
    delete_on_termination = true
    encrypted             = false
  }

  run_tags = {
    Name      = "${var.ami_name}"
    ami_name  = "${var.ami_name}"
    image_os  = "windows"
    image_ver = "${var.image_version}"
  }

  tags = {
    Name        = "${var.ami_name}"
    ami_name    = "${var.ami_name}"
    image_os    = "windows"
    image_ver   = "${var.image_version}"
    built_by    = "packer"
    description = "${var.ami_description}"
  }
}

build {
  sources = [
    "source.amazon-ebs.build",
  ]

  provisioner "powershell" {
    inline = [
      "$ProgressPreference = 'SilentlyContinue'",
      "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072",
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) { Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) }",
      "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart -All",
      "Enable-WindowsOptionalFeature -Online -FeatureName Containers -NoRestart -All",
      "choco install docker-desktop --no-progress -y",
      "Set-Service com.docker.service -StartupType Automatic",
      "Set-Service vmcompute -StartupType Automatic"
    ]
  }

  provisioner "windows-restart" {
    check_registry  = true
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    inline = [
      "Write-Output 'Docker and Hyper-V enabled for GitHub Actions runner image.'"
    ]
  }
}
