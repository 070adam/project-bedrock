# ── Required outputs (checked by automated grader) ───────────────────

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "assets_bucket_name" {
  description = "S3 assets bucket name (bedrock-assets-<student_id>)"
  value       = module.serverless.assets_bucket_name
}

# ── Additional useful outputs ─────────────────────────────────────────

output "alb_hostname" {
  description = "DNS name of the Application Load Balancer (may take ~2 min to resolve)"
  value       = try(kubernetes_ingress_v1.retail_ui.status[0].load_balancer[0].ingress[0].hostname, "pending — check: kubectl get ingress -n retail-app")
}

output "mysql_endpoint" {
  description = "MySQL RDS endpoint (private)"
  value       = module.rds.mysql_endpoint
  sensitive   = false
}

output "postgres_endpoint" {
  description = "PostgreSQL RDS endpoint (private)"
  value       = module.rds.postgres_endpoint
  sensitive   = false
}

output "dev_user_name" {
  description = "IAM username for the read-only developer"
  value       = module.iam.dev_user_name
}

output "dev_user_access_key_id" {
  description = "Access key ID for bedrock-dev-view (store securely)"
  value       = module.iam.dev_user_access_key_id
  sensitive   = true
}

output "dev_user_secret_access_key" {
  description = "Secret access key for bedrock-dev-view (store securely)"
  value       = module.iam.dev_user_secret_access_key
  sensitive   = true
}

output "configure_kubectl" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
