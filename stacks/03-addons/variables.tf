variable "cluster_state_path" {
  description = "Relative path to the 02-cluster Terraform state."
  type        = string
  default     = "../02-cluster/terraform.tfstate"
}

variable "cilium_version" {
  description = "Cilium chart version."
  type        = string
  default     = "1.16.5"
}

variable "metallb_version" {
  description = "MetalLB chart version."
  type        = string
  default     = "0.14.9"
}

variable "longhorn_version" {
  description = "Longhorn chart version."
  type        = string
  default     = "1.7.2"
}

variable "metallb_address_pool" {
  description = "L2 IP range for MetalLB to hand out to LoadBalancer services. Must be unused on your LAN, same subnet as the nodes."
  type        = list(string)
}

variable "longhorn_replica_count" {
  description = "Default replica count for Longhorn volumes (2 is the safe minimum on a 2-worker cluster)."
  type        = number
  default     = 2
}
