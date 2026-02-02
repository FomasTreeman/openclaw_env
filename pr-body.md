## 🔧 Automated Security Fixes

This PR was automatically generated to fix issues detected by CI.

### ✅ Auto-Applied Fixes
- Terraform formatting (`terraform fmt`)
- Ansible lint fixes (`ansible-lint --fix`)

### 🔒 Security Issues Requiring Review

The following Checkov findings need manual fixes. **Use GitHub Copilot to help:**

1. Open any file mentioned below
2. Select the problematic code
3. Press `Ctrl+I` (or `Cmd+I`) and ask: *"Fix this Checkov security issue"*

<details><summary>View all findings (34 issues)</summary>

- **CKV_AWS_91**: null
  - File: `/cloudfront.tf:58`
  - Resource: `aws_lb.internal`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-logging-policies/bc-aws-logging-22)

- **CKV_AWS_2**: null
  - File: `/cloudfront.tf:100`
  - Resource: `aws_lb_listener.http`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/networking-29)

- **CKV_AWS_86**: null
  - File: `/cloudfront.tf:116`
  - Resource: `aws_cloudfront_distribution.main`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-logging-policies/logging-20)

- **CKV_AWS_174**: null
  - File: `/cloudfront.tf:116`
  - Resource: `aws_cloudfront_distribution.main`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/bc-aws-networking-63)

- **CKV_AWS_310**: null
  - File: `/cloudfront.tf:116`
  - Resource: `aws_cloudfront_distribution.main`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-310)

- **CKV_AWS_305**: null
  - File: `/cloudfront.tf:116`
  - Resource: `aws_cloudfront_distribution.main`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-305)

- **CKV_AWS_355**: null
  - File: `/janitor.tf:42`
  - Resource: `aws_iam_role_policy.janitor_lambda`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-iam-policies/bc-aws-355)

- **CKV_AWS_290**: null
  - File: `/janitor.tf:42`
  - Resource: `aws_iam_role_policy.janitor_lambda`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-iam-policies/bc-aws-290)

- **CKV_AWS_117**: null
  - File: `/janitor.tf:101`
  - Resource: `aws_lambda_function.docker_cleanup`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/ensure-that-aws-lambda-function-is-configured-inside-a-vpc-1)

- **CKV_AWS_116**: null
  - File: `/janitor.tf:101`
  - Resource: `aws_lambda_function.docker_cleanup`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/ensure-that-aws-lambda-function-is-configured-for-a-dead-letter-queue-dlq)

- **CKV_AWS_173**: null
  - File: `/janitor.tf:101`
  - Resource: `aws_lambda_function.docker_cleanup`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-serverless-policies/bc-aws-serverless-5)

- **CKV_AWS_272**: null
  - File: `/janitor.tf:101`
  - Resource: `aws_lambda_function.docker_cleanup`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-272)

- **CKV_AWS_117**: null
  - File: `/janitor.tf:214`
  - Resource: `aws_lambda_function.patch_check`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/ensure-that-aws-lambda-function-is-configured-inside-a-vpc-1)

- **CKV_AWS_116**: null
  - File: `/janitor.tf:214`
  - Resource: `aws_lambda_function.patch_check`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/ensure-that-aws-lambda-function-is-configured-for-a-dead-letter-queue-dlq)

- **CKV_AWS_173**: null
  - File: `/janitor.tf:214`
  - Resource: `aws_lambda_function.patch_check`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-serverless-policies/bc-aws-serverless-5)

- **CKV_AWS_272**: null
  - File: `/janitor.tf:214`
  - Resource: `aws_lambda_function.patch_check`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-272)

- **CKV_AWS_130**: null
  - File: `/main.tf:209`
  - Resource: `aws_subnet.public_a`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/ensure-vpc-subnets-do-not-assign-public-ip-by-default)

- **CKV_AWS_130**: null
  - File: `/main.tf:220`
  - Resource: `aws_subnet.public_b`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/ensure-vpc-subnets-do-not-assign-public-ip-by-default)

- **CKV_AWS_378**: null
  - File: `/cloudfront.tf:72`
  - Resource: `aws_lb_target_group.openclaw`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/bc-aws-378)

- **CKV2_AWS_31**: null
  - File: `/cloudfront.tf:189`
  - Resource: `aws_wafv2_web_acl.main`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-logging-policies/bc-aws-logging-33)

- **CKV2_AWS_47**: null
  - File: `/cloudfront.tf:116`
  - Resource: `aws_cloudfront_distribution.main`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-general-47)

- **CKV_AWS_145**: null
  - File: `/ssm.tf:171`
  - Resource: `aws_s3_bucket.compliance`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/ensure-that-s3-buckets-are-encrypted-with-kms-by-default)

- **CKV2_AWS_57**: null
  - File: `/secrets.tf:95`
  - Resource: `aws_secretsmanager_secret.api_keys`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-2-57)

- **CKV2_AWS_62**: null
  - File: `/ssm.tf:171`
  - Resource: `aws_s3_bucket.compliance`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-logging-policies/bc-aws-2-62)

- **CKV_AWS_18**: null
  - File: `/ssm.tf:171`
  - Resource: `aws_s3_bucket.compliance`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/s3-policies/s3-13-enable-logging)

- **CKV2_AWS_42**: null
  - File: `/cloudfront.tf:116`
  - Resource: `aws_cloudfront_distribution.main`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/ensure-aws-cloudfront-distribution-uses-custom-ssl-certificate)

- **CKV2_AWS_32**: null
  - File: `/cloudfront.tf:116`
  - Resource: `aws_cloudfront_distribution.main`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/bc-aws-networking-65)

- **CKV_AWS_21**: null
  - File: `/ssm.tf:171`
  - Resource: `aws_s3_bucket.compliance`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/s3-policies/s3-16-enable-versioning)

- **CKV2_AWS_12**: null
  - File: `/main.tf:56`
  - Resource: `aws_vpc.main`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/networking-4)

- **CKV2_AWS_61**: null
  - File: `/ssm.tf:171`
  - Resource: `aws_s3_bucket.compliance`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-logging-policies/bc-aws-2-61)

- **CKV_AWS_144**: null
  - File: `/ssm.tf:171`
  - Resource: `aws_s3_bucket.compliance`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/ensure-that-s3-bucket-has-cross-region-replication-enabled)

- **CKV2_AWS_3**: null
  - File: `/monitoring.tf:43`
  - Resource: `aws_guardduty_detector.main`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/ensure-guardduty-is-enabled-to-specific-orgregion)

- **CKV2_AWS_20**: null
  - File: `/cloudfront.tf:58`
  - Resource: `aws_lb.internal`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/ensure-that-alb-redirects-http-requests-into-https-ones)

- **CKV_AWS_103**: null
  - File: `/cloudfront.tf:100`
  - Resource: `aws_lb_listener.http`
  - [Fix Guide](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-general-43)


</details>


---

### 🤖 Using Copilot to Fix Remaining Issues

For each security finding above:

```
1. Open the file in GitHub.dev (press `.` on this PR)
2. Find the line mentioned in the finding
3. Select the code block
4. Open Copilot Chat (Ctrl+Shift+I)
5. Ask: "Fix this security issue: [paste the finding]"
6. Review and apply the suggestion
7. Commit the changes
```

Or comment on this PR with:
```
@github-copilot Please suggest fixes for the Checkov security issues
```

---
*Auto-generated by security workflow*
