# EC2 Management Workflows (Standard)

This repo runs standard EC2 management tasks via GitHub Actions over SSH:
- Connectivity + IMDSv2 metadata check
- OS detection + repo refresh + OS update
- Time sync + timezone (optional)
- Install common ops tools (Ubuntu/Debian, RHEL/Alma/Rocky/CentOS, Amazon Linux)

## Required GitHub Secrets
Set these in: Repo → Settings → Secrets and variables → Actions

- EC2_HOSTS        : Comma/space separated hosts (public IP/DNS). Example: "1.2.3.4, ec2-x.compute.amazonaws.com"
- EC2_USER         : SSH user (ubuntu / ec2-user / rocky / etc.)
- EC2_SSH_KEY      : Private key contents (PEM). (Paste full key)
Optional:
- EC2_PORT         : default 22
- EC2_SSH_OPTS     : extra ssh options
- EC2_TIMEZONE     : e.g. "Asia/Dhaka" (optional)

## Optional inventory file (for local docs)
See inventory/hosts.example

## How to run
1) Push to main → Connectivity workflow runs
2) Actions → Run:
   - Bootstrap OS (updates repo + time sync)
   - Install Tools (installs ops packages)
   - Maintenance Update (full OS update)

## Notes
- Scripts are idempotent: safe to re-run.
- Tools list is maintained in scripts/remote/install_tools.sh
