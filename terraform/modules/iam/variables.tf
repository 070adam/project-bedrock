variable "cluster_name" {
  type = string
}

variable "cluster_oidc_issuer_url" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "student_id" {
  type = string
}

variable "common_tags" {
  type = map(string)
}
