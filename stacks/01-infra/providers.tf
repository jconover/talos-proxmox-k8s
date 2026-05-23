provider "proxmox" {
  # All four values come from the environment (see .envrc.example):
  #   PROXMOX_VE_ENDPOINT
  #   PROXMOX_VE_API_TOKEN
  #   PROXMOX_VE_INSECURE
  #   PROXMOX_VE_SSH_USERNAME / PROXMOX_VE_SSH_AGENT
  #
  # Explicit ssh{} block here so the provider knows to use the SSH agent for
  # file uploads (Talos ISO snippet).
  ssh {
    agent = true
  }
}
