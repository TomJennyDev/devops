# Terraform Documentation Setup

Hướng dẫn sử dụng `terraform-docs` để tự động generate documentation cho Terraform code.

## 📋 What is terraform-docs?

`terraform-docs` là tool để tự động generate markdown documentation từ Terraform modules, bao gồm:
- Variables (inputs)
- Outputs
- Resources
- Providers
- Module dependencies

## 🚀 Installation

### Windows

**Option 1: Download binary (Recommended)**
```bash
# Download
curl -Lo terraform-docs.zip https://github.com/terraform-docs/terraform-docs/releases/download/v0.18.0/terraform-docs-v0.18.0-windows-amd64.zip

# Extract
unzip terraform-docs.zip

# Move to PATH
move terraform-docs.exe C:\Windows\System32\
```

**Option 2: Chocolatey**
```bash
choco install terraform-docs
```

**Option 3: Scoop**
```bash
scoop install terraform-docs
```

### macOS
```bash
brew install terraform-docs
```

### Linux
```bash
curl -Lo terraform-docs.tar.gz https://github.com/terraform-docs/terraform-docs/releases/download/v0.18.0/terraform-docs-v0.18.0-linux-amd64.tar.gz
tar -xzf terraform-docs.tar.gz
sudo mv terraform-docs /usr/local/bin/
```

### Verify Installation
```bash
terraform-docs --version
```

## 📝 Usage

### 1. Generate docs for root module

```bash
cd terraform-eks
terraform-docs markdown table . > README.md
```

### 2. Generate docs for specific module

```bash
cd terraform-eks/modules/vpc
terraform-docs markdown table . > README.md
```

### 3. Generate docs for all modules (use script)

```bash
# From project root
./scripts/generate-terraform-docs.sh
```

### 4. Auto-inject docs into existing README

```bash
# Add markers in README.md
<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

# Run terraform-docs (will inject between markers)
terraform-docs markdown table . --output-file README.md --output-mode inject
```

## ⚙️ Configuration File

Project đã có sẵn `.terraform-docs.yml` config files:

```yaml
# terraform-eks/.terraform-docs.yml
formatter: markdown table

content: |-
  # {{ .Header }}
  
  {{ .Requirements }}
  {{ .Providers }}
  {{ .Modules }}
  {{ .Resources }}
  {{ .Inputs }}
  {{ .Outputs }}

output:
  file: README.md
  mode: inject
  
sort:
  enabled: true
  by: name
```

## 🎯 Generate Docs for This Project

### Manual Generation

```bash
# Root module
cd terraform-eks
terraform-docs .

# Each module
cd modules/vpc && terraform-docs .
cd modules/eks && terraform-docs .
cd modules/iam && terraform-docs .

# Each environment
cd environments/dev && terraform-docs .
cd environments/staging && terraform-docs .
cd environments/prod && terraform-docs .
```

### Automated Script

```bash
# Run from project root
bash scripts/generate-terraform-docs.sh
```

This will generate README.md for:
- ✅ `terraform-eks/README.md`
- ✅ `terraform-eks/modules/*/README.md`
- ✅ `terraform-eks/environments/*/README.md`

## 📊 Output Formats

### Markdown Table (Default)
```bash
terraform-docs markdown table .
```

### Markdown Document
```bash
terraform-docs markdown document .
```

### JSON
```bash
terraform-docs json .
```

### YAML
```bash
terraform-docs yaml .
```

### AsciiDoc
```bash
terraform-docs asciidoc table .
```

## 🔄 CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/terraform-docs.yml
name: Generate Terraform Docs

on:
  pull_request:
    paths:
      - 'terraform-eks/**/*.tf'

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          ref: ${{ github.event.pull_request.head.ref }}

      - name: Render terraform docs
        uses: terraform-docs/gh-actions@v1
        with:
          working-dir: terraform-eks
          output-file: README.md
          output-method: inject
          git-push: true
```

### Pre-commit Hook

```bash
# Install pre-commit
pip install pre-commit

# Create .pre-commit-config.yaml
cat > .pre-commit-config.yaml << EOF
repos:
  - repo: https://github.com/terraform-docs/terraform-docs
    rev: v0.18.0
    hooks:
      - id: terraform-docs-go
        args: ["markdown", "table", "--output-file", "README.md", "."]
EOF

# Install hooks
pre-commit install
```

## 🎨 Customization Examples

### Custom Header/Footer

```yaml
# .terraform-docs.yml
header-from: header.md
footer-from: footer.md
```

### Hide/Show Sections

```yaml
sections:
  hide:
    - requirements
    - providers
  show:
    - inputs
    - outputs
```

### Custom Content Template

```yaml
content: |-
  # My Custom Terraform Module
  
  ## Description
  This is a custom description.
  
  ## Inputs
  {{ .Inputs }}
  
  ## Outputs
  {{ .Outputs }}
```

## 💡 Best Practices

### 1. Add descriptions to variables

```hcl
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}
```

### 2. Add descriptions to outputs

```hcl
output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = module.eks.cluster_id
}
```

### 3. Use meaningful variable names

```hcl
# ✅ Good
variable "enable_cluster_encryption" {}

# ❌ Bad
variable "encrypt" {}
```

### 4. Add examples in README

```markdown
## Examples

### Basic Usage
\`\`\`hcl
module "eks" {
  source = "./modules/eks"
  
  cluster_name = "my-cluster"
  vpc_id       = module.vpc.vpc_id
}
\`\`\`
```

### 5. Keep docs in sync

```bash
# Run before commit
./scripts/generate-terraform-docs.sh
git add terraform-eks/**/README.md
git commit -m "docs: update terraform documentation"
```

## 📚 Resources

- [Official Documentation](https://terraform-docs.io/)
- [GitHub Repository](https://github.com/terraform-docs/terraform-docs)
- [Configuration Reference](https://terraform-docs.io/user-guide/configuration/)
- [Output Formats](https://terraform-docs.io/reference/terraform-docs/)

## 🔍 Troubleshooting

### Docs not generating
```bash
# Check if .terraform-docs.yml exists
ls -la .terraform-docs.yml

# Check if terraform files exist
ls -la *.tf

# Run with verbose
terraform-docs markdown table . --config .terraform-docs.yml
```

### Permission denied
```bash
# Windows
# Run as Administrator or move to user directory

# Linux/Mac
chmod +x scripts/generate-terraform-docs.sh
```

### Git not detecting changes
```bash
# Ensure README.md is not in .gitignore
git check-ignore README.md

# Force add if needed
git add -f terraform-eks/README.md
```

---

**Last Updated:** January 3, 2026  
**terraform-docs Version:** v0.18.0
