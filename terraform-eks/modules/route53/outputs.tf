output "zone_id" {
  description = "Route53 zone ID"
  value       = try(data.aws_route53_zone.main[0].zone_id, "")
}

output "argocd_fqdn" {
  description = "ArgoCD FQDN"
  value       = try(aws_route53_record.argocd[0].fqdn, "")
}

output "wildcard_fqdn" {
  description = "Wildcard FQDN"
  value       = try(aws_route53_record.wildcard[0].fqdn, "")
}
