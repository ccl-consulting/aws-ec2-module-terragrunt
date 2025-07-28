# Contributing to AWS EC2 Module

Thank you for your interest in contributing to the AWS EC2 Terraform module for Terragrunt! This document outlines the process and guidelines for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Process](#development-process)
- [Branch Protection Rules](#branch-protection-rules)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Security Guidelines](#security-guidelines)

## Code of Conduct

This project adheres to a code of conduct that promotes a welcoming and inclusive environment. By participating, you are expected to uphold this code.

## Getting Started

### Prerequisites

- **Terraform** >= 1.0
- **Terragrunt** >= 0.35
- **Git** for version control
- **AWS CLI** configured (for testing)
- **GitHub account** with appropriate permissions

### Setting Up Development Environment

1. **Fork the repository**
   ```bash
   # Fork the repo on GitHub, then clone your fork
   git clone https://github.com/YOUR-USERNAME/aws-ec2-module-terragrunt.git
   cd aws-ec2-module-terragrunt
   ```

2. **Add upstream remote**
   ```bash
   git remote add upstream https://github.com/ccl-consulting/aws-ec2-module-terragrunt.git
   ```

3. **Install development tools**
   ```bash
   # Install terraform-docs for documentation generation
   curl -L https://github.com/terraform-docs/terraform-docs/releases/download/v0.16.0/terraform-docs-v0.16.0-linux-amd64.tar.gz -o terraform-docs.tar.gz
   tar -xzf terraform-docs.tar.gz
   sudo mv terraform-docs /usr/local/bin/
   
   # Install pre-commit hooks (optional but recommended)
   pip install pre-commit
   pre-commit install
   ```

## Development Process

### 1. Create a Feature Branch

```bash
# Sync with upstream
git fetch upstream
git checkout main
git merge upstream/main

# Create feature branch
git checkout -b feature/your-feature-name
```

### 2. Make Changes

- Follow the [coding standards](#coding-standards)
- Update documentation as needed
- Add tests for new functionality
- Ensure security best practices are followed

### 3. Test Your Changes

```bash
# Format Terraform code
terraform fmt -recursive

# Validate Terraform code
terraform init -backend=false
terraform validate

# Format Terragrunt files
find . -name "*.hcl" -exec terragrunt hclfmt {} \;

# Run security scan (if checkov is installed)
checkov -d . --framework terraform
```

### 4. Update Documentation

```bash
# Generate updated documentation
terraform-docs markdown table --output-file README.md --output-mode inject .
```

### 5. Commit and Push

```bash
git add .
git commit -m "feat: add new feature description"
git push origin feature/your-feature-name
```

## Branch Protection Rules

This repository has the following branch protection rules:

### Main Branch (`main`)

- ✅ **Require pull request reviews before merging**
  - Required approving reviews: 1
  - Require review from code owners
  - Dismiss stale reviews when new commits are pushed

- ✅ **Require status checks to pass before merging**
  - Require branches to be up to date before merging
  - Required status checks:
    - `validate` (Terraform validation)
    - `security-scan` (Security scanning)
    - `documentation` (Documentation check)
    - `test` (Configuration testing)

- ✅ **Require branches to be up to date before merging**

- ✅ **Require signed commits**

- ✅ **Include administrators** (Admins must follow the same rules)

- ✅ **Restrict pushes that create files**

- ✅ **Allow force pushes** (Disabled)

- ✅ **Allow deletions** (Disabled)

### Admin Privileges

- **Repository Admins** can:
  - Merge pull requests without review (emergency situations only)
  - Modify repository settings
  - Manage branch protection rules
  - Create and manage releases

- **Non-Admin Contributors** must:
  - Submit pull requests for all changes
  - Have changes reviewed by repository admins
  - Pass all required status checks
  - Follow the contribution guidelines

## Pull Request Process

### 1. Create Pull Request

- Use a descriptive title following [Conventional Commits](https://www.conventionalcommits.org/)
- Fill out the pull request template completely
- Link any related issues

### 2. Pull Request Template

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Security improvement

## Testing
- [ ] I have tested these changes locally
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes

## Security Checklist
- [ ] No hardcoded credentials or sensitive information
- [ ] Security group rules follow least privilege principle
- [ ] Encryption is enabled where appropriate
- [ ] Changes follow AWS security best practices

## Documentation
- [ ] I have updated the documentation accordingly
- [ ] I have updated the CHANGELOG.md file
- [ ] Examples have been updated if needed

## Checklist
- [ ] My code follows the code style of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] My changes generate no new warnings
```

### 3. Review Process

1. **Automated Checks**: All CI/CD pipeline checks must pass
2. **Code Review**: At least one admin must approve the changes
3. **Security Review**: Security-related changes require additional scrutiny
4. **Documentation Review**: Ensure documentation is updated

### 4. Merge Process

- **Squash and merge** is preferred for feature branches
- **Create a merge commit** for release branches
- Delete feature branch after merge

## Coding Standards

### Terraform Code Style

```hcl
# Use descriptive resource names
resource "aws_instance" "web_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  # Group related configurations
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = var.subnet_id
  
  # Use consistent indentation (2 spaces)
  tags = {
    Name        = var.instance_name
    Environment = var.environment
  }
}
```

### Variable Naming

```hcl
# Use snake_case for variables
variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
  
  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Instance type must be t3.micro, t3.small, or t3.medium."
  }
}
```

### Documentation Standards

- All variables must have descriptions
- All outputs must have descriptions
- Use clear, concise language
- Include examples where helpful
- Keep README.md up to date

## Testing

### Required Tests

1. **Terraform Validation**
   ```bash
   terraform init -backend=false
   terraform validate
   ```

2. **Format Check**
   ```bash
   terraform fmt -check -recursive
   ```

3. **Security Scan**
   ```bash
   checkov -d . --framework terraform
   ```

4. **Configuration Testing**
   ```bash
   # Test each example configuration
   terragrunt validate --terragrunt-non-interactive
   ```

### Test Environment Guidelines

- Use AWS free tier resources for testing
- Clean up resources after testing
- Never commit real AWS credentials
- Use placeholder values in examples

## Security Guidelines

### Code Security

- ✅ No hardcoded credentials
- ✅ No sensitive information in code
- ✅ Use AWS IAM roles instead of access keys
- ✅ Enable encryption by default
- ✅ Follow least privilege principle
- ✅ Validate all inputs

### Network Security

- ✅ Restrict security group rules
- ✅ Use specific CIDR blocks
- ✅ Avoid `0.0.0.0/0` for ingress rules
- ✅ Implement egress restrictions when needed

### Infrastructure Security

- ✅ Enable EBS encryption
- ✅ Use KMS keys for encryption
- ✅ Enable CloudWatch monitoring
- ✅ Implement backup strategies
- ✅ Use latest AMIs with security patches

## Release Process

Releases are automated through GitHub Actions:

1. **Merge to Main**: When changes are merged to `main`
2. **CI/CD Pipeline**: All tests must pass
3. **Automatic Release**: Version is incremented and release is created
4. **Changelog**: Generated from commit messages

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

## Getting Help

- **Documentation**: Check the README.md and examples
- **Issues**: Search existing issues or create a new one
- **Discussions**: Use GitHub Discussions for questions
- **Contact**: Reach out to the CCL Consulting team

## Recognition

Contributors will be recognized in:
- GitHub contributor graph
- Release notes
- Annual contributor acknowledgments

Thank you for contributing to making this module better! 🚀
