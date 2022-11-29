# AWS Nitro Enclaves with Kubernetes

This repository contains a collection of tools that can be used to build and run [AWS Nitro Enclaves](https://docs.aws.amazon.com/enclaves/latest/user/nitro-enclave.html) applications with [Amazon Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks/).

The userguide for AWS Nitro Enclaves with Kubernetes (K8s) can be found [here](https://docs.aws.amazon.com/enclaves/latest/user/kubernetes.html).

# Overview

There are two NE (Nitro Enclaves) applications in this repository which can be built and deployed in a **Kubernetes** [deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).

- [hello](https://github.com/aws/aws-nitro-enclaves-cli/tree/main/examples/x86_64/hello): A simple application that prints periodically on the Nitro Enclave debug console
- [kmstool](https://github.com/aws/aws-nitro-enclaves-sdk-c/blob/main/docs/kmstool.md): A kms application that is able to connect to KMS from inside the Nitro Enclave and decrypt an encrypted KMS message received from the outside world

Dependencies like `docker`, `jq`, `eksctl` and `kubectl` are required for configuring, building and deploying various NE applications.

Use the `enclavectl` tool from this repository to create EKS clusters, build NE applications and do deployments.

To add the tool to your **$PATH** variable, use:

```bash
source env.sh
```

See `enclavectl help` for all the supported options.

The default settings for `enclavectl` are stored in the local `settings.json` file.

In this file the following input can be provided:
- AWS region
- Instance type
- EKS cluster name
- EKS nodegroup name
- EKS nodegroup desired capacity
- K8s version
- CPUs per node to reserve for Nitro Enclaves
- Memory per node to reserve for Nitro Enclaves

Here is an example of a configuration file:
```bash
{
  "region" : "eu-central-1",
  "instance_type" : "m5.2xlarge",
  "eks_cluster_name" : "eks-ne-cluster",
  "eks_worker_node_name" : "eks-ne-nodegroup",
  "eks_worker_node_capacity" : "1",
  "k8s_version" : "1.22",
  "node_enclave_cpu_limit": 2,
  "node_enclave_memory_limit_mib": 768
}
```

## Building and running the hello example

1) Adapt the configuration and apply it to the project:
```bash
enclavectl configure --file settings.json
```
After finishing, the tool confirms a successful configuration like below

```bash
[enclavectl] Configuration finished successfully.
```

2) Create a Nitro Enclave aware EKS cluster. This will use the `EnclaveOptions=true` parameter in the EC2 launch template that shall be used on the cluster nodegroup:

```
enclavectl setup
```
This high-level command consists of three internal steps:
- Generates a basic EC2 Launch Template for Nitro Enclaves and UserData
- Creates an EKS cluster with a managed node-group of configured capacity
- Deploys the [Nitro Enclaves K8s Device plugin](https://github.com/aws/aws-nitro-enclaves-k8s-device-plugin): This plugin enables Kubernetes [pods](https://kubernetes.io/docs/concepts/workloads/pods/) to access Nitro Enclaves device driver. As part of this step, the plugin is deployed as a [daemonset](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/) to the cluster.

3) Build the hello enclave application

Usually, applications run on EKS clusters in containers. A Nitro Enclave applications need one more step for running in an enclave - it needs to be packaged in an **Enclave Image File (EIF)**. To get more information about building **EIFs**, please take a look at this [user guide](https://docs.aws.amazon.com/enclaves/latest/user/building-eif.html).

To trigger a build, use:
```bash
enclavectl build --image hello
```

This phase makes use of a builder docker container which builds the targeted application if it is present in the `container` directory and packages it in a ready-to-deploy container.
All application deliverables, including the Nitro Enclave EIF, are put in the `container/bin/` folder.

4) Push the hello enclave application to a remote repository
For deploying, a docker repository shall be required. We will be using [Amazon Elastic Container Registry (ECR)](https://aws.amazon.com/ecr/) for this purpose.
```bash
enclavectl push --image hello
```

Unless it has already been created, this also creates a repository under your private ECR and pushes the **hello** image to it.
For the subsequent uses, the command will always use the previously created repository.

5) Deploy the hello enclave application

This command does necessary pre-initialization (if exists) for the application before deployment and generates deployment specification.
```bash
enclavectl run --image hello --prepare-only
```

To see the contents of the deployment specification, use:
```bash
cat hello_deployment.yaml
```

Finally, to start the actual deployment, use:
```bash
kubectl apply -f hello_deployment.yaml
```

The above steps can be done via a single command:
```bash
enclavectl run --image hello
```

6) Check the application logs

To check deployment status of the hello application, use
```bash
kubectl get pods --selector app=hello --watch
```

After a while the command is expected to report a similar output like below after a short while:

```bash
NAME                               READY   STATUS              RESTARTS   AGE
hello-deployment-7bf5d9b79-qv8vm   0/1     Pending             0          2s
hello-deployment-7bf5d9b79-qv8vm   0/1     Pending             0          27s
hello-deployment-7bf5d9b79-qv8vm   0/1     ContainerCreating   0          27s
hello-deployment-7bf5d9b79-qv8vm   1/1     Running             0          30s
```

When you ensure that the application is running, press "Ctrl + C" to terminate `kubectl` and check the logs:
```bash
kubectl logs hello-deployment-7bf5d9b79-qv8vm
```
You can find the `<deployment name>` from your terminal logs. After successful execution of this command, you will see output like this below.

```bash
[   1] Hello from the enclave side!
[   2] Hello from the enclave side!
[   3] Hello from the enclave side!
[   4] Hello from the enclave side!
[   5] Hello from the enclave side!
```
The application keeps printing "Hello from the enclave side!" message every 5 seconds.

7) Stop the application logs

To clear the previous deployment, use:
```bash
enclavectl stop --image hello
```
This function not only executes `kubectl -f delete hello_deployment.yaml` in the background, but also uninitalizes resources if any were initialized after `enclavectl run` command.

## Building and running the kmstool example

[KMS Tool](https://github.com/aws/aws-nitro-enclaves-sdk-c/blob/main/docs/kmstool.md) is an example application that uses is able to connect to KMS and decrypt an encrypted KMS message.

**NOTE**: The user would be required to create a role which is associated with the EC2 instance that has permissions to access the KMS service in order to create a key, encrypt a message and decrypt the message inside the enclave. This is the way and the recommended way Nitro Enclaves are used today by users. More information in the doc listed at the beginning of the section.

For this demo application in EKS, we already have a role associated with the instance but those permissions do not apply to the Kubernetes containers. In order to resolve this, we require a [service account](https://docs.aws.amazon.com/eks/latest/userguide/service-accounts.html) that has all the required permissions with KMS in order to issue a successful KMS Decrypt from inside the Nitro Enclave.

As an important note, AWS currently supports one enclave per EC2 instance. Before moving on, please ensure you stopped the previous `hello` deployment.

To run KMS example, please follow the similar steps below as you did for the `hello` application.

```bash
enclavectl build --image kms
enclavectl push --image kms
enclavectl run --image kms
kubectl get pods --selector app=kms --watch
```

And check the logs to see that the enclave has decrypted the message:
```bash
kubectl logs <kms-deployment-name>
```
After successful execution of this command, you will see output like this below. (User specific data has been truncated)
```bash
[kms-example] Creating a KMS key...
[kms-example] Encrypting message...
[kms-example] ******************************
[kms-example] KMS Key ARN: arn:aws:kms:[...]
[kms-example] Account ID: [...]
[kms-example] Unencrypted message: Hello, KMS\!
[kms-example] Ciphertext: AQICAHg7LT9PYQzAhL3hhzA4N15Lsok7f4DEEPGiNf8fyUM+5QHHy85xZXBek7uFPtNX+vJyAAAAZDBiBgkqhkiG9w0BBwagVTBTAgEAME4GCSqGSIb3DQEHATAeBglghkgBZQMEAS4wEQQMspJf9GEN1DqaJ55sAgEQgCGorI4UgmAAwmhfgsuXIud/PcTKwt8K8L/aPyj8Hq6KIVo=
[kms-example] ******************************
Start allocating memory...
Started enclave with enclave-cid: 18, memory: 128 MiB, cpu-ids: [1, 5]
[kms-example] Requesting from the enclave to decrypt message...
[kms-example] ------------------------
[kms-example] > Got response from the enclave!
[kms-example] Object = { "Status": "Ok" } Object = { "Status": "Ok", "Message": "HelloKMS" }
[kms-example] ------------------------
Successfully terminated enclave i-[...]-enc[...]
```

## Creating your own example application

To quickly create your own application within this tutorial, you need to perform a few more steps. All application specific data is stored under the `container` folder. The `hello` can be
a good example to see what kind of files are required for your application. To see more information, please check this [document](./container/README.md).

## Cleaning up AWS resources
If you followed this tutorial partially or entirely, it must have created some AWS resources. To clean them up, use:

```bash
enclavectl cleanup
```

## Security issue notifications

If you discover a potential security issue, we ask that you notify AWS Security via our [vulnerability reporting page](https://aws.amazon.com/security/vulnerability-reporting/).
Please do **not** create a public GitHub issue.
