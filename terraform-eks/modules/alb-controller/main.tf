# ============================================
# AWS Load Balancer Controller
# ============================================
# This file configures AWS Load Balancer Controller for EKS
# Supports: ALB (Application Load Balancer) & NLB (Network Load Balancer)

# ============================================
# IAM Role for AWS Load Balancer Controller
# ============================================
resource "aws_iam_role" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name = "${var.cluster_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.common_tags
}

# ============================================
# IAM Policy for AWS Load Balancer Controller
# ============================================
# Policy này cấp quyền cho Load Balancer Controller để:
# 1. Tự động tạo/xóa ALB (Application Load Balancer) và NLB (Network Load Balancer)
# 2. Quản lý Target Groups, Listeners, Rules
# 3. Tạo và quản lý Security Groups
# 4. Integrate với ACM (SSL certificates), WAF, Shield
# 5. Register/deregister pod IPs vào Target Groups
#
# Controller được authenticate qua IRSA (IAM Roles for Service Accounts)
# sử dụng OIDC provider của EKS cluster
# ============================================
resource "aws_iam_policy" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name        = "${var.cluster_name}-aws-load-balancer-controller"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # =============================================
      # 1. SERVICE LINKED ROLE CREATION
      # =============================================
      # Cho phép tạo Service Linked Role cho ELB (chỉ cần 1 lần)
      # AWS tự động quản lý role này để ELB có thể truy cập các AWS services khác
      # Example: ELB cần access EC2, CloudWatch logs, etc.
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            # Chỉ cho phép tạo Service Linked Role cho ELB service
            # Không thể tạo cho services khác (security best practice)
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      # =============================================
      # 2. EC2 & ELB READ PERMISSIONS
      # =============================================
      # Read-only permissions để controller có thể:
      # - Xem thông tin VPC, subnets (để biết deploy ALB vào đâu)
      # - Xem security groups hiện có (để attach vào ALB)
      # - Xem EC2 instances (EKS nodes)
      # - Xem load balancers và target groups hiện có
      # 
      # Những permissions này KHÔNG TỐN TIỀN, chỉ đọc thông tin
      # Resource = "*" vì AWS API yêu cầu (không thể restrict to specific resources)
      {
        Effect = "Allow"
        Action = [
          # EC2 Describe Actions - Xem thông tin infrastructure
          "ec2:DescribeAccountAttributes",      # Account limits (VPCs, IPs, etc)
          "ec2:DescribeAddresses",              # Elastic IPs
          "ec2:DescribeAvailabilityZones",      # AZs available
          "ec2:DescribeInternetGateways",       # Internet Gateways
          "ec2:DescribeVpcs",                   # VPCs
          "ec2:DescribeVpcPeeringConnections",  # VPC peering
          "ec2:DescribeSubnets",                # Subnets (public/private)
          "ec2:DescribeSecurityGroups",         # Security Groups
          "ec2:DescribeInstances",              # EC2 instances (EKS nodes)
          "ec2:DescribeNetworkInterfaces",      # ENIs
          "ec2:DescribeTags",                   # Tags on resources
          "ec2:GetCoipPoolUsage",               # Outpost IP pools
          "ec2:DescribeCoipPools",              # Outpost IP pools
          
          # ELB Describe Actions - Xem thông tin load balancers
          "elasticloadbalancing:DescribeLoadBalancers",           # List ALBs/NLBs
          "elasticloadbalancing:DescribeLoadBalancerAttributes",  # ALB settings
          "elasticloadbalancing:DescribeListeners",               # Listeners (port 80, 443)
          "elasticloadbalancing:DescribeListenerAttributes",      # Listener settings
          "elasticloadbalancing:DescribeListenerCertificates",    # SSL certificates
          "elasticloadbalancing:DescribeSSLPolicies",             # SSL policies
          "elasticloadbalancing:DescribeRules",                   # Routing rules
          "elasticloadbalancing:DescribeTargetGroups",            # Target groups
          "elasticloadbalancing:DescribeTargetGroupAttributes",   # TG settings
          "elasticloadbalancing:DescribeTargetHealth",            # Pod health status
          "elasticloadbalancing:DescribeTags"                     # Tags on LBs
        ]
        Resource = "*"
      },
      # =============================================
      # 3. INTEGRATION PERMISSIONS
      # =============================================
      # Permissions để integrate với các AWS services khác:
      # - ACM: SSL/TLS certificates cho HTTPS
      # - Cognito: User authentication
      # - WAF: Web Application Firewall (bảo vệ khỏi attacks)
      # - Shield: DDoS protection
      {
        Effect = "Allow"
        Action = [
          # Cognito - User authentication cho ALB
          # Example: alb.ingress.kubernetes.io/auth-type: cognito
          "cognito-idp:DescribeUserPoolClient",
          
          # ACM - SSL/TLS Certificates
          # Example: alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
          "acm:ListCertificates",         # List available certificates
          "acm:DescribeCertificate",      # Get certificate details
          
          # IAM Server Certificates (legacy, ACM preferred)
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          
          # WAF v1 (regional, legacy)
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",      # Attach WAF to ALB
          "waf-regional:DisassociateWebACL",   # Detach WAF from ALB
          
          # WAF v2 (recommended)
          # Example: alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:wafv2:...
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",             # Attach WAFv2 to ALB
          "wafv2:DisassociateWebACL",          # Detach WAFv2 from ALB
          
          # Shield - DDoS Protection (auto-enabled on ALB)
          "shield:GetSubscriptionState",       # Check Shield subscription
          "shield:DescribeProtection",         # View protection status
          "shield:CreateProtection",           # Enable Shield Advanced
          "shield:DeleteProtection"            # Disable Shield Advanced
        ]
        Resource = "*"
      },
      # =============================================
      # 4. SECURITY GROUP INGRESS/EGRESS RULES
      # =============================================
      # Cho phép thêm/xóa rules trong security groups
      # Controller cần update SG rules khi:
      # - ALB cần allow traffic từ internet (port 80, 443)
      # - ALB cần forward traffic đến pods
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",  # Add inbound rule
          "ec2:RevokeSecurityGroupIngress"      # Remove inbound rule
        ]
        Resource = "*"
      },
      # =============================================
      # 5. SECURITY GROUP CREATION
      # =============================================
      # Cho phép tạo security groups mới cho ALB/NLB
      # Controller tự động tạo SG mỗi khi deploy Ingress
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup"
        ]
        Resource = "*"
      },
      # =============================================
      # 6. SECURITY GROUP TAGGING (AT CREATION)
      # =============================================
      # Cho phép add tags khi TẠO security group
      # Tags quan trọng để tracking:
      # - elbv2.k8s.aws/cluster = my-eks-cluster
      # - kubernetes.io/cluster/my-eks-cluster = owned
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = {
            # Chỉ cho phép tag KHI ĐANG TẠO security group
            # Không thể tag SGs đã tồn tại của người khác
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
          Null = {
            # Request PHẢI có tag elbv2.k8s.aws/cluster
            # "false" = tag MUST exist
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      # =============================================
      # 7. SECURITY GROUP TAG MANAGEMENT
      # =============================================
      # Cho phép add/remove tags trên SGs ĐÃ TỒN TẠI
      # Chỉ được sửa tags của SGs do controller tạo
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",   # Add tags
          "ec2:DeleteTags"    # Remove tags
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            # Request KHÔNG CÓ tag mới (đang sửa tag cũ)
            # "true" = tag must NOT exist in request
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "true"
            
            # Resource ĐÃ CÓ tag cluster (do controller tạo)
            # "false" = tag MUST exist on resource
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      # =============================================
      # 8. SECURITY GROUP MODIFICATION & DELETION
      # =============================================
      # Cho phép sửa rules và XÓA security groups
      # CHỈ với SGs có tag cluster (do controller tạo)
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",  # Add inbound rules
          "ec2:RevokeSecurityGroupIngress",     # Remove inbound rules
          "ec2:DeleteSecurityGroup"             # Delete SG (khi xóa Ingress)
        ]
        Resource = "*"
        Condition = {
          Null = {
            # Chỉ được sửa/xóa SGs có tag cluster
            # Không thể xóa SGs của người khác hoặc tạo manual
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      # =============================================
      # 9. LOAD BALANCER & TARGET GROUP CREATION
      # =============================================
      # Cho phép TẠO ALB/NLB và Target Groups
      # Workflow: kubectl apply ingress.yaml
      #   → Controller sees new Ingress
      #   → CreateLoadBalancer (ALB)
      #   → CreateTargetGroup (for pods)
      #   → DNS: xxx-123456.us-west-2.elb.amazonaws.com
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",  # Create ALB or NLB
          "elasticloadbalancing:CreateTargetGroup"    # Create Target Group for pods
        ]
        Resource = "*"
        Condition = {
          Null = {
            # Request PHẢI CÓ tag cluster khi tạo
            # Để tracking LB nào thuộc cluster nào
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      # =============================================
      # 10. LISTENER & RULE MANAGEMENT
      # =============================================
      # Cho phép tạo/xóa Listeners (port 80, 443) và Rules (routing)
      # Listeners: Định nghĩa ALB nghe port nào
      # Rules: Định nghĩa route traffic như thế nào
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",   # Add listener (port 80, 443)
          "elasticloadbalancing:DeleteListener",   # Remove listener
          "elasticloadbalancing:CreateRule",       # Add routing rule (path-based)
          "elasticloadbalancing:DeleteRule"        # Remove routing rule
        ]
        Resource = "*"
      },
      # =============================================
      # 11. LOAD BALANCER TAGGING
      # =============================================
      # Cho phép add/remove tags trên Load Balancers và Target Groups
      # Tags dùng để: Cost allocation, Resource tracking, Cleanup
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",     # Add tags
          "elasticloadbalancing:RemoveTags"   # Remove tags
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",     # Target Groups
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*", # NLBs
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"  # ALBs
        ]
        Condition = {
          Null = {
            # Request KHÔNG có tag mới (đang sửa tag cũ)
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "true"
            
            # Resource ĐÃ CÓ tag cluster (do controller tạo)
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      # =============================================
      # 12. LISTENER TAGGING
      # =============================================
      # Cho phép add/remove tags trên Listeners và Listener Rules
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",        # NLB listeners
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",        # ALB listeners
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",   # NLB rules
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"    # ALB rules
        ]
      },
      # =============================================
      # 13. LOAD BALANCER MODIFICATIONS & DELETION
      # =============================================
      # Cho phép sửa config và XÓA Load Balancers/Target Groups
      # CHỈ với resources có tag cluster
      {
        Effect = "Allow"
        Action = [
          # Load Balancer modifications
          "elasticloadbalancing:ModifyLoadBalancerAttributes",  # Change settings
          "elasticloadbalancing:SetIpAddressType",              # IPv4/IPv6
          "elasticloadbalancing:SetSecurityGroups",             # Change SGs
          "elasticloadbalancing:SetSubnets",                    # Change subnets
          "elasticloadbalancing:DeleteLoadBalancer",            # Delete ALB/NLB
          
          # Target Group modifications
          "elasticloadbalancing:ModifyTargetGroup",             # Change TG settings
          "elasticloadbalancing:ModifyTargetGroupAttributes",   # Deregistration delay, stickiness
          "elasticloadbalancing:DeleteTargetGroup"              # Delete TG
        ]
        Resource = "*"
        Condition = {
          Null = {
            # Chỉ được sửa/xóa resources có tag cluster
            # Không thể xóa ALB của cluster khác hoặc tạo manual
            # => SAFETY: Tránh xóa nhầm production ALB!
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      # =============================================
      # 14. TAGGING AT CREATION TIME
      # =============================================
      # Cho phép add tags KHI TẠO Load Balancer và Target Group
      # Tags tự động được add để tracking
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          StringEquals = {
            # Chỉ cho phép tag KHI ĐANG TẠO resource
            # Không thể tag resources đã tồn tại
            "elasticloadbalancing:CreateAction" = [
              "CreateTargetGroup",
              "CreateLoadBalancer"
            ]
          }
          Null = {
            # Request PHẢI CÓ tag cluster
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      # =============================================
      # 15. TARGET REGISTRATION
      # =============================================
      # Cho phép add/remove Pod IPs vào Target Groups
      # Đây là CORE FUNCTION để ALB biết forward traffic đến pod nào
      # 
      # Workflow:
      # 1. Pod starts → Controller RegisterTargets (10.0.11.5:8080)
      # 2. Pod scales up → RegisterTargets (new pod IPs)
      # 3. Pod terminates → DeregisterTargets (old pod IP)
      # 4. Pod unhealthy → DeregisterTargets
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",    # Add pod IP to Target Group
          "elasticloadbalancing:DeregisterTargets"   # Remove pod IP from Target Group
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      # =============================================
      # 16. LISTENER & CERTIFICATE MANAGEMENT
      # =============================================
      # Cho phép các operations nâng cao trên Listeners
      {
        Effect = "Allow"
        Action = [
          # WAF Integration
          "elasticloadbalancing:SetWebAcl",  # Attach WAF Web ACL to ALB
          
          # Listener modifications
          "elasticloadbalancing:ModifyListener",  # Change listener settings
          
          # SSL Certificate management
          "elasticloadbalancing:AddListenerCertificates",     # Add SSL cert
          "elasticloadbalancing:RemoveListenerCertificates",  # Remove SSL cert
          
          # Rule modifications
          "elasticloadbalancing:ModifyRule"  # Change routing rules
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  policy_arn = aws_iam_policy.aws_load_balancer_controller[0].arn
  role       = aws_iam_role.aws_load_balancer_controller[0].name
}
