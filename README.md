# LOG8415E Final Assignment

## Overview

Some Overview

### Assignment Components

-   **AWS Infrastructure**: 3 EC2 instance (t2.micro)

## Quick Start

### Step 1: Configure AWS Credentials

```bash
aws configure
```

Enter your AWS credentials when prompted:

-   AWS Access Key ID
-   AWS Secret Access Key
-   Default region: `us-east-1`
-   Default output format: `json`

```bash
aws configure set aws_session_token <your token here>
```

### Step 2: Terraform

Change directory to terraform folder and terraform apply to up the infra

```bash
cd terraform
terraform apply
```

### Step 2: Benchmarks

Change directory to benchmarks folder and run the python script \
The IP is the public ip address of the gatekeeper instance

```bash
cd benchmark
python -m venv .venv
.venv/Scripts/activate
python main.py <IP>
```