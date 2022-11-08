# aws-nitro-enclaves-with-k8s

Welcome to aws-nitro-enclaves-with-k8s! This hands-on guide briefly explains how to run `Nitro Enclaves` in 
[Amazon Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks/). The repository holds a set of helper scripts
that can help you to quickly execute the required commands and run demo applications in a **Kubernetes (K8s)** cluster.

## Getting started

This guide assumes that you have already created your environment to manage an EKS cluster. If not, please check out
[Getting started with Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html) user guide.

## Using this repository

This repository contains two demo applications:
- [hello](https://github.com/aws/aws-nitro-enclaves-cli/tree/main/examples/x86_64/hello): A simple hello world application.
- [kms](https://github.com/aws/aws-nitro-enclaves-sdk-c/blob/main/docs/kmstool.md): A small example application built with aws-nitro-enclaves-sdk-c that is able to connect to KMS and decrypt an encrypted KMS message.

The required steps to run these applications are implemented as helper scripts and the use of them will be explained in the upcoming sections.
These scripts are easy to modify and very straightforward to use. There is also **settings.json** that can help you to customize this demo.
## Setting up the EKS cluster

1) **Create a launch template**: This is a preliminary step where we define the capabilities of the workers nodes of our EKS cluster. Run **00_create_launch_template.sh** to create a launch template. Any EC2 instance created with this template will come with Nitro Enclaves support enabled. The template also contains some user data that takes care of necessary installations and **huge pages** enablement, which will be essential for an enclave.

If the script succeeds, a launch template will be created in the AWS region defined in **settings.json**. This step also creates a local file called **last_launch_template.id**. This file holds the launch template id of the last successfully created launch template. Please see the sample content of this file below:

```
lt-0d15a86ae64cf8982
```

If you somehow would like to delete the last created launch template, **01_delete_last_launch_template.sh** script is particularly useful for this purpose. It obtains the launch template id from **last_launch_template.id** and deletes the launch template from your AWS account and last_launch_template.id local file, respectively.

2) **Create an EKS cluster**: As its name states, the **02_create_eks_cluster.sh** script creates an EKS cluster. This operation will approximately take 15-20 minutes, and a cluster with one Nitro Enclaves-enabled worker node will be generated. The template file to create the cluster will be generated in the working directory as eks_cc_<RANDOM_UUID>.yaml.

3) **Enable Nitro Enclaves Device Plugin**: The [enclaves device plugin](https://github.com/aws/aws-nitro-enclaves-k8s-device-plugin) helps us to allocate hardware resources without a need 
to use privileged containers. **03_enable_device_plugin.sh** script deploys the plugin as a daemonset to our cluster and enables it on the worker node that the enclave will be working.

Congratulations! Now, we have a working EKS cluster! Let's move on to preparing to our demo binaries.

4) When you want to run your application in an enclave, it needs to packaged in an **Enclave Image File (EIF)**. To get more information about building **EIFs**, please take a look at this [user guide](https://docs.aws.amazon.com/enclaves/latest/user/building-eif.html). To run the [hello](https://github.com/aws/aws-nitro-enclaves-cli/tree/main/examples/x86_64/hello), we require an EIF file only. However, the [kms](https://github.com/aws/aws-nitro-enclaves-sdk-c/blob/main/docs/kmstool.md) demo not only requires an EIF, but also an executable that needs to run in a parent instance. To save time in this demo, we already built the necessary files for you. If you prefer to use them, use **04_fetch_demo_applications.sh** to fetch them. Building the applications from scratch is also an option. Please use **05_build_demo_applications.sh** to build dependencies. In either way you chose, the necessary files will be created under **container/bin** folder.

Now, everything is almost ready. To run nitro enclaves in a K8s environment, we need a container image. Beforehand, we also need a container repository.
For that purpose, [Amazon Elastic Container Registry (ECR)](https://aws.amazon.com/ecr/) could help!

5) **Create an ECR Repository**: By creating this repository, we will be able to tell Kubernetes where to fetch our hello image. The **06_create_hello_ecr_repository.sh** script creates a private repository in the region that is configured in **settings.json**. Additionaly, this script creates the **last_repository.uri** local file which holds the last repository URI.

6) **Create/update hello docker image and push it to the ECR repo**: By the successful completion of the previous step, we had already obtained a repository to store our container image. Now, it's time to create/update a container image and push it to our repository. **07_update_hello_image.sh** script will be using the [Dockerfile](container/hello/Dockerfile) in **container/hello** to create an image and pushes it your ECR repository.

7) **Run hello demo in K8s as a pod**: We all have been waiting for this step! With the help of **08_run_hello.sh**, we try to run our container as a Pod in the worker node we created in the previous steps. As an outcome of this script's execution, **ne_pod.yaml** podspec file will also be generated in the working directory. Pods are the smallest deployable units in Kubernetes. For more information, please check out this [documentation](https://kubernetes.io/docs/concepts/workloads/pods/).

8) **Check the logs**: It's time to see the application output! Our container started an enclave image that prints "Hello from the enclave side!"
in every five seconds. The **09_read_hello_logs.sh** script not only helps you to see enclave logs, but also shows you the details of the running Pod.

We have already seen that the hello demo is running. This time, let's see a more sophisticated example. 

9) **Create the resouces for KMS demo**: For this demo, the user would be required to create a role which is associated with the EC2 instance that has permissions to access the KMS service in order to create a key, encrypt a message and decrypt the message inside the enclave. In EKS, we already have a role associated with the instance but those permissions do not apply to the Kubernetes containers. In order to resolve this, we require a service account that has all the required permissions. Besides creating this service account, the script will do some of the previous steps (such as creating an ecr repository, build and push the docker image) in one go via **10_prepare_kms.sh**. This does not overlap with the steps done for the **hello** demo.

11) **Run the KMS demo in K8s as a pod**: To run it, use **11_run_kms.sh**. In this demo, we first create a KMS key and encrypt a message using it. Afterwards, the enclave is created and we send the encrypted message from the pod to the enclave by using the **kmstool**. If everything is successful, the enclave will reply with the decrypted message, which in our case is “Hello, KMS!”

12) **Check the logs**: **12_read_kms_logs.sh** will print out the details about the pod deployment and the execution logs.

13) To release the resources that have been used througout this demo, please use **./13_cleanup_resources.sh** script. (TODO: Incomplete)
## Closing thoughts
These quick demos demonstrate how to run Nitro Enclaves via EKS and Kubernetes-managed nodes. We hope that you find it easy to do through this guide.
