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

```
- environments/: Contains configurations specific to each environment. Each has its own state file.
- modules/: Contains reusable Terraform modules used across different environments.

## Prerequisites
- Terraform (version >= 0.14)
- Appropriate cloud provider CLI and credentials set up. For AWS, AWS CLI and configured credentials.

## Getting Started
### 1. Clone the Repo
```
git clone <repository-url>
```
### 2. Navigate to an Environment
```
cd terraform-repo/environments/<env>  # Replace <env> with dev, staging, or prod
```
### 3. Create a New Branch
```
git checkout -b feature-<feature-name> # For example: git checkout -b feature-add-s3
```
### 4. Make Changes
Modify the Terraform configuration files as necessary for your infrastructure needs.

### 5. Commit & Push Your Changes
```
git add .
git commit -m "Your descriptive commit message"
git push origin feature-<feature-name>
```
### 6. Open a Pull Request
```
gh pr create --base main --head feature-<feature-name> --title "Your PR title" --body "Description of the changes."
```
### 7. Merge Pull Request
Once your PR is approved, merge it to the main branch. Any merge into main will automatically deploy to the development environment.

### 8. Tag for Staging or Production
When you decide the main branch's state is ready for staging or production, create a tag:
```
git checkout main
git pull
git tag <env>-vX.Y.Z # For example: git tag staging-v0.1.1
git push origin <env>-vX.Y.Z
```
Note: Adjust <env> to staging or prod depending on where you want the deployment. Once this tag is pushed, the CI/CD workflow will detect this tag and initiate the deployment process to the designated environment.

### 9. Github Actions CI/CD
GitHub Actions will automatically run terraform init, terraform plan, and, upon detecting an environment-specific tag, terraform apply.

## Best Practices
- **Do Not Hardcode**: Use variables for any values that might change.
- **Document Changes**: Comment configurations and commit messages should be descriptive.
- **Use Version Constraints**: Specify version constraints for providers.
- **Never Store Sensitive Data**: Do not hard-code sensitive data in configurations.

## Contributing
1. Create a new branch for your changes.
2. Make changes and test them thoroughly.
3. Open a pull request, and request reviews from the team once all checks are complete and passed.

Note: 
Merging a PR into main automatically deploys to dev.
Tagging a commit as staging-vX.Y.Z would deploy that commit to the staging environment.
Tagging a commit as prod-vX.Y.Z would deploy that commit to the production environment.
