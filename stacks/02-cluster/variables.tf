variable "infra_state_path" {
  description = "Relative path to the 01-infra Terraform state."
  type        = string
  default     = "../01-infra/terraform.tfstate"
}

variable "cluster_name" {
  description = "Kubernetes cluster name."
  type        = string
  default     = "vex"
}

variable "cluster_endpoint_vip" {
  description = "Virtual IP for the control-plane endpoint. Talos manages it via VRRP on the CP nodes. Pick an unused IP in your network."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version (must be one supported by the chosen talos_version)."
  type        = string
  default     = "1.31.4"
}

variable "install_disk" {
  description = "Which disk Talos should install to. /dev/sda matches the bpg/proxmox virtio-scsi default."
  type        = string
  default     = "/dev/sda"
}

variable "cni_none_for_cilium" {
  description = "Set to true so Talos doesn't install flannel — 03-addons installs Cilium instead."
  type        = bool
  default     = true
}

variable "kube_proxy_disabled" {
  description = "Disable kube-proxy so Cilium can take over (kubeProxyReplacement)."
  type        = bool
  default     = true
}
