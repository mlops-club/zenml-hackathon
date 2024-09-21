#!/bin/bash +e

export AWS_PROFILE=zenml
export AWS_DEFAULT_REGION=us-west-2
export AWS_REGION=us-west-2

S3_ARTIFACTS_BUCKET_URI="s3://mlops-club-zeml-hackathon-bucket"

# zenml integration install aws -y

# From the docs:
# "This method may constitute a security risk, because it can give users access 
# to the same cloud resources and services that the ZenML Server itself is configured to access.
export ZENML_ENABLE_IMPLICIT_AUTH_METHODS=true

# create a service connector that uses your SSO profile (locally) or the EC2 instance role (on AWS)
zenml service-connector register "s3-bucket-connector" \
    --type aws \
    --description "r/w access to S3 buckets for local credentials" \
    --resource-type s3-bucket \
    --auth-method implicit \
    --region=$AWS_REGION

# Successfully registered service connector `s3_store` with access to the following resources:
# ┏━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃ RESOURCE TYPE │ RESOURCE NAMES                                   ┃
# ┠───────────────┼──────────────────────────────────────────────────┨
# ┃ 📦 s3-bucket  │ s3://cdk-hnb659fds-assets-491085404175-us-west-2 ┃
# ┃               │ s3://mlops-club-zeml-hackathon-bucket            ┃
# ┗━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

# create a service connector that uses your SSO profile (locally) or the EC2 instance role (on AWS)
zenml service-connector register "ecr-connector" \
    --type aws \
    --description "r/w access to ECR repos for local credentials" \
    --resource-type docker-registry \
    --auth-method implicit \
    --region=$AWS_REGION

# Successfully registered service connector `ecr` with access to the following resources:
# ┏━━━━━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃   RESOURCE TYPE    │ RESOURCE NAMES                               ┃
# ┠────────────────────┼──────────────────────────────────────────────┨
# ┃ 🐳 docker-registry │ 905418322705.dkr.ecr.us-west-2.amazonaws.com ┃
# ┗━━━━━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

zenml artifact-store register "s3-store" \
    --flavor s3 \
    --path="$S3_ARTIFACTS_BUCKET_URI" \
    --connector s3-bucket-connector

# Successfully connected artifact store `s3-store` to the following resources:
# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃        CONNECTOR ID        │ CONNECTOR NAME      │ CONNECTOR TYPE │ RESOURCE TYPE │ RESOURCE NAMES             ┃
# ┠────────────────────────────┼─────────────────────┼────────────────┼───────────────┼────────────────────────────┨
# ┃ de4a06d4-c132-4be6-92d8-61 │ s3-bucket-connector │ 🔶 aws         │ 📦 s3-bucket  │ s3://mlops-club-zeml-hacka ┃
# ┃         bbee06f52f         │                     │                │               │ thon-bucket                ┃
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

