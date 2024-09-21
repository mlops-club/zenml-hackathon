


## ZenML OSS vs Metaflow OSS

| Feature | ZenML OSS | Metaflow OSS |
| --- | - | - |
| Preview Artifacts in the UI | ❌ | ❌ |
| Arbitrary visualizations in UI |  | ✅ (metaflow cards) |
| Trigger DAGs from the UI | ❌ | ❌ (seems like not based on [this](https://github.com/Netflix/metaflow-ui/blob/master/README.mds)) |
| Deploy Models from the UI | ❌ | ❌ |
| Build and push docker images | ✅ | ❌ (possibly with netflix extensions) |
| Easy switch from local to cloud | ✅ | ✅ |
| Run only certain steps on cloud, others locally | ❌ | ✅ |
| Run DAGs on Airflow | ✅ | ✅ |
| Run DAGs on Step Functions + AWS Batch | ❌ | ✅ |
| No limit to number of collaborators | ??? | ✅ |

