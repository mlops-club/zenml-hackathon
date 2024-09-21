#!/bin/bash

# TODO: consider using try/catch expressions as shown in this SO answer: https://stackoverflow.com/questions/22009364/is-there-a-try-catch-command-in-bash
# to return a failure cfn-signal or success.

# This script is a templated string. All occurreces of "[dollar sign]<some var name>" will be substituted
# with other values by the CDK code.

# make the logged output of this user-data script available in the EC2 console
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# print the commands this script runs as they are executed
set -x

export WORKDIR=/zenml
mkdir -p "$$WORKDIR"
cd "$$WORKDIR"

#########################################
# --- Install CLI tool dependencies --- #
#########################################

yum update -y
yum install -y docker

# install docker-compose and make the binary executable
curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$$(uname -s)-$$(uname -m) -o /usr/bin/docker-compose
chmod +x /usr/bin/docker-compose

# initialize docker and docker-swarm daemons
service docker start
docker swarm init

# install aws cli
yum install -y python3
pip3 install awscli --upgrade --user

# # login to ECR and pull the minecraft server backup/restore image
# aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
# docker pull "$$BACKUP_SERVICE_DOCKER_IMAGE_URI"

# prepare a docker-compose.yml that runs the minecraft server and the backup service
cat << EOF > "$$WORKDIR/docker-compose.yml"
services:
  mysql:
    image: mysql:8.0
    ports:
      - 3306:3306
    environment:
      MYSQL_ROOT_PASSWORD: password
    volumes:
      - ./volumes/mysql/data/:/var/lib/mysql
      - ./volumes/mysql/backups/:/backups
      # TODO: mount the mysql state as a volume

  zenml:
    image: zenmldocker/zenml-server
    ports:
      - "8080:8080"
    environment:
      ZENML_STORE_URL: mysql://root:password@mysql/zenml
      ZENML_STORE_BACKUP_DIRECTORY: /backups
      ZENML_STORE_BACKUP_STRATEGY: dump-file
      ZENML_ENABLE_IMPLICIT_AUTH_METHODS: "true"
    volumes:
      - ./volumes/mysql/data/:/var/lib/mysql
    links:
      - mysql
    depends_on:
      - mysql
    # extra_hosts:
    #   - "host.docker.internal:host-gateway"
    restart: on-failure

EOF

##########################################
# --- Start up the with docker swarm --- #
##########################################

# create a docker stack
# docker network create minecraft-server
docker-compose up -d