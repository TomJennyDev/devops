variable "domain_name" {
  description = "Domain name for Route53 zone"
  type        = string
}

variable "create_dns_records" {
  description = "Whether to create DNS records"
  type        = bool
  default     = false
}

variable "argocd_enabled" {
  description = "Whether to create ArgoCD DNS record"
  type        = bool
  default     = false
}

variable "argocd_alb_dns_name" {
  description = "ALB DNS name for ArgoCD"
  type        = string
  default     = ""
}

variable "argocd_alb_zone_id" {
  description = "ALB Zone ID for ArgoCD"
  type        = string
  default     = ""
}

variable "create_wildcard_record" {
  description = "Whether to create wildcard DNS record"
  type        = bool
  default     = false
}

variable "wildcard_alb_dns_name" {
  description = "ALB DNS name for wildcard record"
  type        = string
  default     = ""
}

variable "wildcard_alb_zone_id" {
  description = "ALB Zone ID for wildcard record"
  type        = string
  default     = ""
}
