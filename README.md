# Terraform Infrastructure Repository
This repository contains the Terraform configurations for setting up and managing our cloud infrastructure. Each environment (production, staging, development) has its own set of configurations, ensuring isolation and easy management of resources.

## Directory Structure
```
terraform-repo/
│
├── environments/
│   ├── prod/
│   ├── staging/
│   └── dev/
│
├── modules/
│   ├── compute/
│   ├── networking/
│   └── storage/
│
└── global/
    ├── backend.tf
    └── providers.tf
```
- environments/: Contains configurations specific to each environment. Each has its own state file.
- modules/: Contains reusable Terraform modules used across different environments.
- global/: Global configurations, including backend and provider setups.

## Prerequisites
- Terraform (version >= 0.14)
- Appropriate cloud provider CLI and credentials set up. For AWS, AWS CLI and configured credentials.

## Getting Started
1. Clone the Repo
```
git clone <repository-url>
```
2. Navigate to an Environment
```
cd terraform-repo/environments/prod
```
3. Make Changes
Modify the Terraform configuration files as necessary for your infrastructure needs.
4. Commit & Push
```
git add .
git commit -m "Your descriptive commit message"
git push origin <your-branch-name>
```
5. Open a Pull Request
```
gh pr create --base main --head <your-branch-name> --title "Your PR title" --body "Description of the changes."
```
6. Github Actions CI/CD
GitHub Actions will automatically run terraform init, terraform plan, and, upon merging the PR, terraform apply.

## Best Practices
- **Do Not Hardcode**: Use variables for any values that might change.
- **Document Changes**: Comment configurations and commit messages should be descriptive.
- **Use Version Constraints**: Specify version constraints for providers.
- **Never Store Sensitive Data**: Do not hard-code sensitive data in configurations.

## Contributing
1. Create a new branch for your changes.
2. Make changes and test them thoroughly.
3. Open a pull request, and request reviews from the team once all checks are complete and passed.
