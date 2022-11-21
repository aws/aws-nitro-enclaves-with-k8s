# aws-nitro-enclaves-with-k8s

This guide explains how to run `Nitro Enclaves` with [Amazon Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks/).

## Prerequisites

This guide assumes that you have already created your environment to manage an EKS cluster. If not, please review
[Getting started with Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html) user guide.

Additionally, **bash**, **docker** and **[jq](https://stedolan.github.io/jq/download/)** (*a command-line JSON processor*) need to be installed on your system. <br />

## Getting started

This repository contains two example enclave applications:
- [hello](https://github.com/aws/aws-nitro-enclaves-cli/tree/main/examples/x86_64/hello): A hello world application.
- [kms](https://github.com/aws/aws-nitro-enclaves-sdk-c/blob/main/docs/kmstool.md): An example application built with aws-nitro-enclaves-sdk-c that is able to connect to KMS and decrypt an encrypted KMS message.

We will build these enclave applications in the following steps and have them run in a **Kubernetes** [deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).

## Using this repository

This repository contains a tool called **nectl** that you can use to build and deploy your enclave apps. We will be using **nectl** tool along this tutorial. To add the tool to your **$PATH** variable, use:

```
source env.sh
```

To get some help for the tool, type:
```
nectl --help
```

The default settings for **nectl** are stored in **settings.json**. The content of this file is shown below. You can change the AWS region, the instance type of the cluster nodes, **Kubernetes** version, cluster name and node group name if wanted.
```
{
  "region" : "eu-central-1",
  "instance_type" : "m5.2xlarge",
  "eks_cluster_name" : "eks-ne-cluster",
  "eks_worker_node_name" : "eks-ne-nodegroup",
  "k8s_version" : "1.22"
}
```
<br />

## Getting started

1) **Configuration**: Let's start off by configuring **nectl** tool.
```
nectl configure --file settings.json
```

After running this command, the tool confirms successful configuration like below
```
[nectl] Configuration finished successfully.
```

and becomes ready for further steps.
<br />

2) **Set up an Enclave-aware EKS Cluster**:

This is a preliminary step where we define the capabilities of our EKS cluster.
```
nectl setup
```
This high-level command consists of three internal steps:
- **Create a launch template**: This helps us to create Nitro Enclaves-enabled EC2 instances.
- **Create an EKS Cluster**: Sets up a single-node EKS cluster. The launch template created previously is used in this step.
- **Enable [Nitro Enclaves K8s Device Plugin](https://github.com/aws/aws-nitro-enclaves-k8s-device-plugin)**: This plugin helps **Kubernetes** **[pods](https://kubernetes.io/docs/concepts/workloads/pods/)** to safely access Nitro Enclaves device driver.
    As part of this step, the plugin is deployed as a **[daemonset](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)** to the cluster.

<br />

3) **Build hello enclave application**:

Normally, we deploy applications to EKS clusters in containers. This is still valid, but Enclave applications need one more step. When you want to run your application in an enclave, it needs to be packaged in an **Enclave Image File (EIF)**. To get more information about building **EIFs**, please take a look at this [user guide](https://docs.aws.amazon.com/enclaves/latest/user/building-eif.html).

The tutorial utilizes a **builder** docker container which is responsible for building the enclave applications and creating executables. The build process might take some time. If you want to quickly try the examples without building an enclave application, there are prebuilt binaries available. To download them, use the helper script:
```
./scripts/fetch_prebuilt.sh
```

When the script succeeds, you will see prebuilt binaries saved under **containers/bin/** folder.

To trigger a build, use:
```
nectl build --image hello
```
*The build system builds an EIF file if it does not already exist in **containers/bin/** folder. Otherwise, existing EIF is reused.*

<br />

4) **Push hello image to a docker repository**:
In the following steps, EKS will need to pull our image from a docker repository. We will be using [Amazon Elastic Container Registry (ECR)](https://aws.amazon.com/ecr/) for this purpose.

```
nectl push --image hello
```

This command creates a repository under your private ECR registry unless there is none created before. Then, it pushes your **hello** image to the aforementioned repository.
For the subsequent uses, the command will always use the previously created repository.

<br />

5) **Run hello example in the cluster**:
To prepare our application for deployment, use
```
nectl run --image hello --prepare-only
```

This command does necessary pre-initialization (if exists) for the application before deployment and generates deployment specification. To see the contents of
the deployment specification, use
```
cat hello_deployment.yaml
```

Finally, to deploy your application to the cluster, use:
```
kubectl apply -f hello_deployment.yaml
```

All the steps above (preinitialization, deployment spec generation and application deployment) can also be done through a single command: 
```
nectl run --image hello
```
This command also does pre-initialization, deployment specification generation and finally calls **kubectl** in the background.
<br />

6) **Check the logs**:

We successfully built and have started deploying our application. To check deployment status of the hello application, use
```
kubectl get pods --selector app=hello --watch
```

After a while the command is expected to report a similar output like below after a short while:

```
NAME                               READY   STATUS              RESTARTS   AGE
hello-deployment-7bf5d9b79-qv8vm   0/1     Pending             0          2s
hello-deployment-7bf5d9b79-qv8vm   0/1     Pending             0          27s
hello-deployment-7bf5d9b79-qv8vm   0/1     ContainerCreating   0          27s
hello-deployment-7bf5d9b79-qv8vm   1/1     Running             0          30s
```

When you ensure that the application is running, press "Ctrl + C" to terminate **kubectl**. Now, use the command below to see applications logs:
```
kubectl logs <deployment name>
```
You can find the `<deployment name>` from your terminal logs. In the sample terminal output above, it was **hello-deployment-7bf5d9b79-qv8vm**. After successful execution of this command, you will see output like this below.

```
[   1] Hello from the enclave side!
[   2] Hello from the enclave side!
[   3] Hello from the enclave side!
[   4] Hello from the enclave side!
[   5] Hello from the enclave side!
```
The application keeps printing "Hello from the enclave side!" message every **5** seconds.
<br />

7) **Stopping the application**: Use
```
nectl stop --image hello
```
to stop the application. This function not only executes `kubectl -f delete hello_deployment.yaml` in the background, but also uninitalizes
resources if any were initialized after `nectl run` command.

We have already seen that the **hello** application is running. This time, we will be looking into a more sophisticated example.

## Building and running the KMS example

[KMS Tool](https://github.com/aws/aws-nitro-enclaves-sdk-c/blob/main/docs/kmstool.md) is an example application for aws-nitro-enclaves-sdk-c that is able to connect to KMS and decrypt an encrypted KMS message. For this application, the user would be required to create a role which is associated with the EC2 instance that has permissions to access the KMS service in order to create a key, encrypt a message and decrypt the message inside the enclave. In EKS, we already have a role associated with the instance but those permissions do not apply to the **Kubernetes** containers. In order to resolve this, we require a service account that has all the required permissions.

All the preliminary steps described above will be handled by **nectl** tool.

As an important note, AWS currently supports one enclave per EC2 instance. Before moving on, please ensure you stopped the **hello** application.

To run KMS example, please follow the similar steps below as you did for the **hello** application.

```
nectl build --image kms
nectl push --image kms
nectl run --image kms
kubectl get pods --selector app=kms --watch
```

## Creating your own example application

To quickly create your own application within this tutorial, you need to perform a few more steps. All application specific data is stored under **container** folder. **hello** can be
a good example to see what kind of files are required for your application. To see more information, please check this [document](./container/README.md).

## Cleaning up AWS resources
If you followed this tutorial partially or entirely, it must have created some AWS resources. To clean them up, please use
```
nectl cleanup
```

## Closing thoughts
The hands-on examples in this repository demonstrate how to run Nitro Enclaves with EKS.
