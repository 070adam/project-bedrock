########################################################################
# Project Bedrock — Root Module
# Provisions: VPC → EKS → RDS → DynamoDB → IAM → Serverless
# Platform resources (Helm, K8s) are applied in a second pass after EKS.
########################################################################

# ── VPC ──────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  vpc_name             = var.vpc_name
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name         = var.cluster_name
  common_tags          = var.common_tags
}

# ── EKS ──────────────────────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  cluster_name        = var.cluster_name
  cluster_version     = var.cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_type  = var.node_instance_type
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  common_tags         = var.common_tags
}

# ── RDS (MySQL + PostgreSQL) ──────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  node_security_group_id  = module.eks.node_security_group_id
  mysql_db_name           = var.mysql_db_name
  mysql_username          = var.mysql_username
  postgres_db_name        = var.postgres_db_name
  postgres_username       = var.postgres_username
  rds_instance_class      = var.rds_instance_class
  common_tags             = var.common_tags
}

# ── DynamoDB ──────────────────────────────────────────────────────────
module "dynamodb" {
  source = "./modules/dynamodb"

  cart_table_name = var.dynamodb_cart_table
  common_tags     = var.common_tags
}

# ── IAM (developer user + IRSA roles) ────────────────────────────────
module "iam" {
  source = "./modules/iam"

  cluster_name             = module.eks.cluster_name
  cluster_oidc_issuer_url  = module.eks.cluster_oidc_issuer_url
  oidc_provider_arn        = module.eks.oidc_provider_arn
  student_id               = var.student_id
  common_tags              = var.common_tags
}

# ── Serverless (S3 + Lambda) ──────────────────────────────────────────
module "serverless" {
  source = "./modules/serverless"

  student_id             = var.student_id
  dev_user_arn           = module.iam.dev_user_arn
  lambda_execution_role  = module.iam.lambda_execution_role_arn
  common_tags            = var.common_tags
}

# ── EKS Developer Access Entry ────────────────────────────────────────
# Map bedrock-dev-view IAM user → Kubernetes view ClusterRole via Access Entries
# (modern replacement for aws-auth ConfigMap, available EKS ≥ 1.29)
resource "aws_eks_access_entry" "dev_view" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.iam.dev_user_arn
  type          = "STANDARD"

  tags = var.common_tags

  depends_on = [module.eks, module.iam]
}

resource "aws_eks_access_policy_association" "dev_view_policy" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.iam.dev_user_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type = "cluster" # cluster-wide read-only view
  }

  depends_on = [aws_eks_access_entry.dev_view]
}

# ── AWS Load Balancer Controller (Helm) ───────────────────────────────
# Requires the cluster to exist. Run after: terraform apply -target=module.eks
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.3"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam.alb_controller_role_arn
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [module.eks, module.iam]
}

# ── Kubernetes Namespace ──────────────────────────────────────────────
resource "kubernetes_namespace" "retail_app" {
  metadata {
    name = var.app_namespace

    labels = {
      name    = var.app_namespace
      project = "karatu-2025-capstone"
    }
  }

  depends_on = [module.eks]
}

# ── Kubernetes Secrets (DB credentials from Secrets Manager) ─────────
data "aws_secretsmanager_secret_version" "mysql" {
  secret_id  = module.rds.mysql_secret_arn
  depends_on = [module.rds]
}

data "aws_secretsmanager_secret_version" "postgres" {
  secret_id  = module.rds.postgres_secret_arn
  depends_on = [module.rds]
}

locals {
  mysql_creds    = jsondecode(data.aws_secretsmanager_secret_version.mysql.secret_string)
  postgres_creds = jsondecode(data.aws_secretsmanager_secret_version.postgres.secret_string)
}

resource "kubernetes_secret" "catalog_db" {
  metadata {
    name      = "catalog-db-credentials"
    namespace = kubernetes_namespace.retail_app.metadata[0].name
  }

  data = {
    DB_ENDPOINT = module.rds.mysql_endpoint
    DB_NAME     = var.mysql_db_name
    DB_USER     = var.mysql_username
    DB_PASSWORD = local.mysql_creds.password
  }

  type = "Opaque"
}

resource "kubernetes_secret" "orders_db" {
  metadata {
    name      = "orders-db-credentials"
    namespace = kubernetes_namespace.retail_app.metadata[0].name
  }

  data = {
    DB_ENDPOINT = module.rds.postgres_endpoint
    DB_NAME     = var.postgres_db_name
    DB_USER     = var.postgres_username
    DB_PASSWORD = local.postgres_creds.password
  }

  type = "Opaque"
}

resource "kubernetes_secret" "dynamodb_config" {
  metadata {
    name      = "dynamodb-config"
    namespace = kubernetes_namespace.retail_app.metadata[0].name
  }

  data = {
    CART_TABLE_NAME = var.dynamodb_cart_table
    AWS_REGION      = var.region
  }

  type = "Opaque"
}

# ── Retail Store App (Helm with managed-DB overrides) ─────────────────
resource "helm_release" "retail_store" {
  name             = "retail-store"
  repository       = "oci://public.ecr.aws/aws-containers"
  chart            = "retail-store-sample-app"
  namespace        = kubernetes_namespace.retail_app.metadata[0].name
  create_namespace = false

  # ── Catalog service → MySQL RDS ──────────────────────────────────
  set {
    name  = "catalog.db.endpoint"
    value = module.rds.mysql_endpoint
  }
  set {
    name  = "catalog.db.name"
    value = var.mysql_db_name
  }
  set {
    name  = "catalog.db.user"
    value = var.mysql_username
  }
  set_sensitive {
    name  = "catalog.db.password"
    value = local.mysql_creds.password
  }
  set {
    name  = "catalog.db.managed"
    value = "true"
  }

  # ── Orders service → PostgreSQL RDS ──────────────────────────────
  set {
    name  = "orders.db.endpoint"
    value = module.rds.postgres_endpoint
  }
  set {
    name  = "orders.db.name"
    value = var.postgres_db_name
  }
  set {
    name  = "orders.db.user"
    value = var.postgres_username
  }
  set_sensitive {
    name  = "orders.db.password"
    value = local.postgres_creds.password
  }
  set {
    name  = "orders.db.managed"
    value = "true"
  }

  # ── Cart service → DynamoDB ───────────────────────────────────────
  set {
    name  = "cart.dynamodb.tableName"
    value = var.dynamodb_cart_table
  }
  set {
    name  = "cart.dynamodb.region"
    value = var.region
  }
  set {
    name  = "cart.dynamodb.managed"
    value = "true"
  }

  # ── In-cluster: RabbitMQ + Redis (acceptable per spec) ───────────
  set {
    name  = "rabbitmq.enabled"
    value = "true"
  }
  set {
    name  = "redis.enabled"
    value = "true"
  }

  depends_on = [
    kubernetes_namespace.retail_app,
    helm_release.aws_load_balancer_controller,
    module.rds,
    module.dynamodb,
  ]
}

# ── ALB Ingress for UI service ────────────────────────────────────────
resource "kubernetes_ingress_v1" "retail_ui" {
  metadata {
    name      = "retail-ui-ingress"
    namespace = kubernetes_namespace.retail_app.metadata[0].name

    annotations = {
      "kubernetes.io/ingress.class"                        = "alb"
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path"         = "/actuator/health"
      "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/tags"                     = "Project=karatu-2025-capstone"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "ui"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.retail_store, helm_release.aws_load_balancer_controller]
}
