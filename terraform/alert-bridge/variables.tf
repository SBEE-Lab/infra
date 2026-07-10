variable "script_name" {
  description = "Cloudflare Worker script name."
  type        = string
  default     = "infra-alert-bridge"
}

variable "d1_database_name" {
  description = "Cloudflare D1 database name."
  type        = string
  default     = "infra-alert-bridge"
}

variable "worker_bundle_path" {
  description = "Path to the bundled Worker module built from packages/infra-alert-bridge."
  type        = string
  default     = "../../packages/infra-alert-bridge/dist/index.js"
}
