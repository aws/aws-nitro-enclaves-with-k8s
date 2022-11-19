# aws-nitro-enclaves-with-k8s

This guide explains how to run `Nitro Enclaves` with [Amazon Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks/).

## Prerequisites

This guide assumes that you have already created your environment to manage an EKS cluster. If not, please review
[Getting started with Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html) user guide.

Additionally, **bash**, **docker** and **[jq](https://stedolan.github.io/jq/download/)** (*a command-line JSON processor*) need to be installed on your system. <br />

## Getting started

This repository contains two example enclave applications:
- [hello](https://github.com/aws/aws-nitro-enclaves-cli/tree/main/examples/x86_64/hello): A simple hello world application.
- [kms](https://github.com/aws/aws-nitro-enclaves-sdk-c/blob/main/docs/kmstool.md): A small example application built with aws-nitro-enclaves-sdk-c that is able to connect to KMS and decrypt an encrypted KMS message.

We will build these enclave applications in the following steps and have them run in a **Kubernetes** [pod](https://kubernetes.io/docs/concepts/workloads/pods/).

## Using this repository

This repository contains a tool called **nectl** that you can use to build and deploy your enclave apps. We will be using **nectl** tool along this tutorial. To add the tool to your **$PATH** variable, use:

```
source env.sh
```

To get some help for the tool, type:
```
nectl --help
```

The default settings for **nectl** are stored in **settings.json**. The content of this file is shown below. You can change the AWS region, the instance type of the cluster nodes, Kubernetes version, cluster name and node group name if wanted.
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
- **Enable [Nitro Enclaves K8s Device Plugin](https://github.com/aws/aws-nitro-enclaves-k8s-device-plugin)**: This plugin helps **Kubernetes** pods to safely access Nitro Enclaves device driver.
    As part of this step, the plugin is deployed as a **[daemonset](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)** to the cluster.

<br />

3) **Build hello enclave application**:

Normally, we deploy applications to EKS clusters in containers. This is still valid, but Enclave applications need one more step. When you want to run your application in an enclave, it needs to be packaged in an **Enclave Image File (EIF)**. To get more information about building **EIFs**, please take a look at this [user guide](https://docs.aws.amazon.com/enclaves/latest/user/building-eif.html).

The tutorial utilizes a **builder** docker container which is responsible for building the enclave applications and creating an EIF file. The build process might take some time. So, if you want to quickly try the examples without waiting, there are prebuilt binaries available. To download them, use the helper script:
```
./scripts/fetch_prebuilt.sh
```

When the script succeeds, you will see prebuilt binaries saved under **containers/bin/** folder.

To trigger a build, use:
```
nectl build --image hello
```
As an important note, the build system builds an EIF file if it does not already exist in **containers/bin/** folder. Otherwise, existing EIF is reused.

<br />

4) **Push hello image to a docker repository**:
In the following steps, EKS will need to pull our image from a docker repository. We will be using [Amazon Elastic Container Registry (ECR)](https://aws.amazon.com/ecr/) for this purpose.

```
nectl push --image hello
```

This command creates a repository under your private ECR registry unless there is none created before. Then, it pushes your **hello** image to the aforementioned repository.
For the subsequent uses, the command will always use the previously created repository.

<br />

5) **Run hello example as a pod in the cluster**: Use
```
nectl run --image hello
```

to deploy and run your application in the EKS cluster. As an outcome of this script's execution, **hello_pod.yaml** file will also be generated in the working directory so that you can review what kind of **podspec** was generated to run the application.

<br />

6) **Check the logs**:
To get logs of the hello enclave application, use:
```
nectl describe --image hello
```
After successful execution of this command, you will see output like this below. The application keeps printing "Hello from the enclave side!" message every **5** seconds.

```
[   1] Hello from the enclave side!
[   2] Hello from the enclave side!
[   3] Hello from the enclave side!
[   4] Hello from the enclave side!
[   5] Hello from the enclave side!
```

This command not only shows you the application logs but also give some helpful information about the current status of the **Kubernetes** pod.

7) **Stopping the application**: Use
```
nectl stop --image hello
```
to stop the application. After running this command, you will see the message below returned from the cluster.
```
pod "hello" deleted
```

We have already seen that the **hello** application is running. This time, we will be looking into a more sophisticated example.

## Building and running the KMS example

[KMS Tool](https://github.com/aws/aws-nitro-enclaves-sdk-c/blob/main/docs/kmstool.md) is a small example application for aws-nitro-enclaves-sdk-c that is able to connect to KMS and decrypt an encrypted KMS message. For this application, the user would be required to create a role which is associated with the EC2 instance that has permissions to access the KMS service in order to create a key, encrypt a message and decrypt the message inside the enclave. In EKS, we already have a role associated with the instance but those permissions do not apply to the **Kubernetes** containers. In order to resolve this, we require a service account that has all the required permissions.

All the preliminary steps described above will be handled by **nectl** tool.

As an important note, AWS currently supports one enclave per EC2 instance. Before moving on, please ensure you stopped the **hello** application.

To run KMS example, please follow the similar steps below as you did for the **hello** application.

```
nectl build    --image kms
nectl push     --image kms
nectl run      --image kms
nectl describe --image kms
```

## Creating your own example application

To quickly create your own application within this tutorial, you need to perform a few more steps. All application specific data is stored under **container** folder. **hello** can be
a good example to see what kind of files are required for your application.

To start preparing your application, please create a folder (e.g. my_app) under the **container/** folder. Then, go to the folder and create the files listed below:

 - **Dockerfile** is needed to build container that holds your application.
 - **enclave_manifest.json**: is optional and contains configuration to build your EIF image. This file instructs builder container to run and create an EIF of your application. If you do not prefer to use this automated solution, the use of [Nitro CLI](https://github.com/aws/aws-nitro-enclaves-cli) is also a viable option to build EIF images. For more information about the [Nitro CLI](https://github.com/aws/aws-nitro-enclaves-cli) tool, please take a look at this [document](https://docs.aws.amazon.com/enclaves/latest/user/building-eif.html).
 - **hooks.sh** is optional and holds some hook functions to perform application-specific processing.


## Cleaning up AWS resources
If you followed this tutorial partially or entirely, it must have created some AWS resources. To clean them up, please use
```
nectl cleanup
```

## Closing thoughts
The hands-on examples in this repository demonstrate how to run Nitro Enclaves with EKS.
