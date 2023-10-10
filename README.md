# AWS-CHAIN

**Under Construction**

Using AWS lambdas to serve Next.js generated pages, dynamoDb, ...

Using Terraform to deploy AWS infra


## Prerequisits

1. 
Obtain [replicate](https://replicate.com) api key from [Replicate API](https://replicate.com/account/api-tokens)

Note the token / secret for deployment

2. Have AWS credentials set into ENV

Obtain an AWS account for [free](https://aws.amazon.com/free)

Maybe in bash terminal init (on mac terminal `~/.zshrc`)

```
export AWS_ACCESS_KEY_ID=<aws-access-key-id>
export AWS_SECRET_ACCESS_KEY=<aws-secret-access-key>
export AWS_DEFAULT_REGION=us-west-2
export AWS_REGION=us-west-2
```

3. Consider installing AWS cli (optional)

On a mac:

`brew install awscli`

Validate install and settings with:
```
>aws-chain %aws sts get-caller-identity
{
    "UserId": "1234567890",
    "Account": "1234567890",
    "Arn": "arn:aws:iam::1234567890:root"
}
```

3. Terraform + Landscape

Install and validate as usual

```
>aws-chain %brew install hashicorp/tap/terraform
...

>aws-chain %terraform version
Terraform v1.4.5
...

>aws-chain %brew install terraform_landscape
...

>aws-chain %landcape --version
Terraform Landscape 0.3.4
```

## Install

As usual
```
gh repo clone {{ repository.name }}
```

To add pre-commit linting and formatting in development

```
pip install pre-commit
pre-commit install
pre-commit autoupdate

pip install pylint
```

This installs `.git/hooks/pre-commit`.

## Pre-Commit

Be sure to inspect `.pre-commit-config` for installed git-hooks

To manually invoke from cli

'pre-commit run --all-files'

## Deployment

Install `open-ai-key` secret into AWS Secret Manager to allow calling open-ai API.

Use terraform to generate the AWS infrastructure as usual.

```
terraform init
terraform plan
terraform apply
terraform destroy
```

Invoke Makefile

```
% make dry-run
% make run
% make run -- -auto-approve
```

## Issues & todos

- Notce: prompt-results-table - hook up a timer event to check for past ttls
- Terraform runs seeding of tables - move to a separate python seeding process.
- Terraform event-triggers for lambdas - add args to setup source and other settings,
  For example cw_event schedule and dynamodb_stream filters.

## License

This library is licensed under the MIT-0 License.

See the [LICENSE](LICENSE) file.
