## Usage

### Development with remote deployment

```bash
# re-deploy the EC2 instance stack
cd iac
make install
cdk deploy --app 'python app.py' --region us-west-2 --profile zenml

# auth with the deployed zenml server
zenml connect --server-url http://<ec2 ip>:8080

# create our zenml components and stack
./setup-zenml.sh
```

### Clean it up so no one can hack us

```bash
cdk destroy --app 'python app.py' --region us-west-2 --profile zenml
```

### Local development

```bash
docker-compose up
zenml connect --server-url http://localhost:8080
./setup-zenml.sh
```

## ZenML OSS vs Metaflow OSS

| Feature | ZenML OSS | Metaflow OSS |
| --- | - | - |
| List/Preview Artifacts in the UI | ❌ | ❌ |
| Arbitrary visualizations in UI | ❌ | ✅ (metaflow cards) |
| Trigger DAGs from the UI | ❌ | ❌ (seems like no based on [this](https://github.com/Netflix/metaflow-ui/blob/master/README.mds)) |
| Deploy Models from the UI | ❌ | ❌ |
| Stream logs to UI during DAG run | ❌ | ✅ |
| Can abort DAG mid run from UI | ??? | ❌ |
| Build and push docker images for you, per step | ⚠️ (not during local development, only when using remote orchestrator) | ❌ (possibly with netflix extensions) |
| Easy switch from local to cloud | ✅ | ✅ |
| Run only certain steps on cloud, others locally | ❌ | ✅ |
| Favor running steps on prem, burst to cloud | ❌ (SkyPilot supports this, but ZenML's integration does not) | ✅ (with kubernetes) |
| Run DAGs on Airflow | ✅ | ✅ |
| Run DAGs on Step Functions + AWS Batch | ❌ | ✅ |
| No limit to number of collaborators | ??? | ✅ |
| Thin client | ❌ (55 deps) | ✅ (3 deps) |
| Simple control plane architecture | ✅ (zenml-server, mysql, simple IaC) | ❌ (postgres, backend, frontend, complex IaC) |
| supports proper Python packaging structure e.g. `pyproject.toml` for the DAG project | ??? | ❌ |



> The advantage of Skypilot is that it simply provisions a VM to execute the pipeline on your cloud provider. [Reference](https://docs.zenml.io/user-guide/production-guide/cloud-orchestration#starting-with-a-basic-cloud-stack)

- Does this mean that we CAN NOT have each step be deployed onto its own VM?

> When a pipeline is run with a remote orchestrator a Dockerfile is dynamically generated at runtime.

- So we can't have Docker images built and run one after another when developing locally?
- Does this also mean that we CAN NOT have a DAG where one step has pandas 1.1.1 and another has pandas 1.1.2? How can we have this if we can't have isolated environments per step *locally*?