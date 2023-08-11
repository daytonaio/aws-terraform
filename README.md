# Terraform Daytona AWS

This Terraform code provisions AWS resources for Daytona product.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) installed
- [AWS CLI](https://aws.amazon.com/cli) installed
- An AWS subscription
- An AWS resource group
- A Route53 Zone

## AWS CLI Configuration

Once the AWS CLI is installed, you need to configure it with your AWS credentials. Open a terminal or command prompt and enter the following command:

```sh
aws configure
```

2. Once you've completed the configuration steps, your AWS CLI should be configured and ready to use. You can now run AWS CLI commands to interact with your AWS resources and services. For example, you can try running aws ec2 describe-instances to list your EC2 instances.

## Route53 Zone configuration

Before terraform script is executed a Route53 Zone that matches `base_domain` variable must exists.

Open a terminal or command prompt and use the following AWS CLI command to create a Route 53 zone:

```aws route53 create-hosted-zone --name example.com --caller-reference unique-reference```

Replace example.com with your desired domain name or subdomain. The --caller-reference should be a unique string (such as a timestamp) to identify this request. It helps prevent accidental duplication if you need to retry the command.

If successful, the command will output a JSON response with information about the created hosted zone.

## Configuration

1. Clone this repository to your local machine.
2. Navigate to the cloned repository.
3. Copy the `terraform.tfvars.example` file to `terraform.tfvars`
3. Open `terraform.tfvars` and update the variables as desired.

## Provisioning

1. Initialize the Terraform workspace:
```sh
terraform init
```

2. Create an execution plan:

```sh
terraform plan
```

3. Apply the plan to provision resources:
```sh
terraform apply
```

When prompted, review the plan and type yes to confirm.

NOTE: Please be aware that provisioning of certain resources takes a long time (between 30 minutes and 1 hour)

## De-provisioning
To de-provision the resources created, use the terraform destroy command:

```sh
terraform destroy
```

This command will prompt for confirmation before destroying resources. Type yes to confirm.