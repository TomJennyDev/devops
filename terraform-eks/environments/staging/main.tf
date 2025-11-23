# ========================================
# MAIN TERRAFORM CONFIGURATION - STAGING
# ========================================
# Symlink to root module files

# Point to the root module (parent directory)
module "eks" {
  source = "../../"

  # Pass all variables from terraform.tfvars
  aws_region                           = var.aws_region
  cluster_name                         = var.cluster_name
  cluster_version                      = var.cluster_version
  vpc_cidr                            = var.vpc_cidr
  public_subnet_cidrs                 = var.public_subnet_cidrs
  private_subnet_cidrs                = var.private_subnet_cidrs
  nat_gateway_count                   = var.nat_gateway_count
  cluster_endpoint_public_access      = var.cluster_endpoint_public_access
  cluster_endpoint_private_access     = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_enabled_log_types           = var.cluster_enabled_log_types
  cluster_log_retention_days          = var.cluster_log_retention_days
  node_group_name                     = var.node_group_name
  node_group_desired_size             = var.node_group_desired_size
  node_group_min_size                 = var.node_group_min_size
  node_group_max_size                 = var.node_group_max_size
  node_group_instance_types           = var.node_group_instance_types
  node_group_capacity_type            = var.node_group_capacity_type
  node_group_disk_size                = var.node_group_disk_size
  node_group_ami_type                 = var.node_group_ami_type
  node_group_labels                   = var.node_group_labels
  node_group_taints                   = var.node_group_taints
  enable_node_ssh_access              = var.enable_node_ssh_access
  node_ssh_key_name                   = var.node_ssh_key_name
  ssh_allowed_cidr_blocks             = var.ssh_allowed_cidr_blocks
  vpc_cni_version                     = var.vpc_cni_version
  coredns_version                     = var.coredns_version
  kube_proxy_version                  = var.kube_proxy_version
  common_tags                         = var.common_tags
}
