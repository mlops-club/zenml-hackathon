#!/bin/bash +e

# NOTE: some of the `--param` in this script have `=` signs. The commands
# failed without them for those particular parameters!! Don't ask me why.

# THESE CREDENTIALS ARE NOT REQUIRED! 
# 1. We log in to ZenML using an admin user.
# 2. ZenML has access to certain AWS permissions via implicit auth (mounted aws creds/profile or instance role)
# 3. because we're a ZenML admin, ZenML will attempt to fulfill any requests we make to it using the AWS creds that it has

# export AWS_PROFILE=zenml
# export AWS_DEFAULT_REGION=us-west-2
# export AWS_REGION=us-west-2

S3_ARTIFACTS_BUCKET_URI="s3://mlops-club-zeml-hackathon-bucket"
ECR_REPO_URI="491085404175.dkr.ecr.us-west-2.amazonaws.com/zenml-hackathon-repo"
# /zenml-hackathon-repo
# zenml integration install aws -y

# From the docs:
# "This method may constitute a security risk, because it can give users access 
# to the same cloud resources and services that the ZenML Server itself is configured to access.
export ZENML_ENABLE_IMPLICIT_AUTH_METHODS="true"

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

zenml container-registry register "ecr-docker-image-store" \
    --flavor aws \
    --connector ecr-connector \
    --uri="$ECR_REGISTRY_URI"

# Successfully connected container registry `ecr-docker-image-store` to the following resources:
# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃         CONNECTOR ID         │ CONNECTOR NAME │ CONNECTOR TYPE │ RESOURCE TYPE      │ RESOURCE NAMES              ┃
# ┠──────────────────────────────┼────────────────┼────────────────┼────────────────────┼─────────────────────────────┨
# ┃ abfd4c26-fecb-46a4-810c-a87b │ ecr-connector  │ 🔶 aws         │ 🐳 docker-registry │ 491085404175.dkr.ecr.us-wes ┃
# ┃           52574662           │                │                │                    │ t-2.amazonaws.com           ┃
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

zenml stack register "local-s3-ecr" \
    --artifact-store s3-store \
    --container_registry ecr-docker-image-store \
    --image_builder default \
    --orchestrator default

# Stack 'local-s3-ecr' successfully registered!
#               Stack Configuration              
# ┏━━━━━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃ COMPONENT_TYPE     │ COMPONENT_NAME         ┃
# ┠────────────────────┼────────────────────────┨
# ┃ CONTAINER_REGISTRY │ ecr-docker-image-store ┃
# ┠────────────────────┼────────────────────────┨
# ┃ ORCHESTRATOR       │ default                ┃
# ┠────────────────────┼────────────────────────┨
# ┃ ARTIFACT_STORE     │ s3-store               ┃
# ┗━━━━━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━━━━━━━━━┛
#              'local-s3-ecr' stack              
# No labels are set for this stack.
# Stack 'local-s3-ecr' with id '10aee893-a692-415a-9f89-ecd99aee236b' is owned by user default.
# To delete the objects created by this command run, please run in a sequence:
# 
# zenml stack delete -y local-s3-ecr                                                                                   
# Dashboard URL: http://0.0.0.0:8080/stacks

zenml stack set "local-s3-ecr"