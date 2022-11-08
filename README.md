# nitro-enclaves-on-eks

Welcome to nitro-enclaves-on-eks! This repository holds helper scripts to quickly create EKS clusters with Nitro Enclaves support.

## Getting started

This mini tutorial assumes that you've already created your environment to manage an EKS cluster. If not, please check out this
user guide: https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html.
(TBA: Automatic creation of an administrator machine/instance on the EC2 for non-linux users.)

## Using this repository

This repository contains a bunch of bash scripts to help you quickly create EKS clusters with Nitro Enclaves-enabled worker
nodes. The script are pretty easy to modify and very straightforward to use. However, if you would like to make some customizations
about how the demo works, feel free to customize **settings.json** according to your needs.

## Running a demo

This demo consists of multiple steps. Please do them in order described below.

1) **Create a launch template**: This is a preliminary step where we define the capabilities of the workers nodes of our EKS cluster.
Run **00_create_launch_template.sh** to create one. If the script succeeds, a launch template will be created in the AWS region that
defined in settings.json. This step will also create a local file called **last_launch_template.id**. This file holds the launch template id
of the last successfully created launch template. Please see the sample content of this file below:

```
lt-0d15a86ae64cf8982
```

If you somehow would like to delete the last created launch template, **01_delete_last_launch_template.sh** script is particularly
useful for this purpose. It obtains the launch template id from **last_launch_template.id** and deletes the launch template and
last_launch_template.id local file, respectively.

2) **Create an EKS cluster**: As its name states, the **02_create_eks_cluster.sh** script will create an EKS cluster. This operation
will approximately take 15-20 minutes, and a cluster with one Nitro Enclaves-enabled worker node will be generated. The template
file to create the cluster can be found in this directory: /tmp/eks_cc_<RANDOM_UUID>.yaml.
(TODO: Keep the generated template file in working directory.)

3) **Create an ECR Repository**: Congratulations! Now we have a working EKS cluster! This time we will create a repository in
Amazon Elastic Container Registry (ECR). This step is required, because one of the following steps of the demo need to tell
Kubernetes where to fetch our demo image. The **03_create_ecr_repository.sh** script creates a private repository in the region
that is configured in settings.json. Additionaly, this script creates the last_repository.uri local file which holds the last repository URI.
To remove this repository, you can use the **04_delete_last_ecr_repository.sh** script. This script will delete the ECR repository
and the last_repository.uri.

4) **Create/Update Docker image and pushing it to the ECR repo**: By the successful completion of the previous step, we had already
obtained a repository to store our container images. Now, it's time to create/update a container and push it to our container repository.
In the container directory of this project, there is a sample Dockerfile. This docker file builds our container image which also contains
the prebuilt hello.eif enclave image file. By running the **05_update_container.sh** script, first, a docker image will be built. Second,
this image will be pushed to the ECR repository that was created in the previous step.

5) **Enable Smarter Devices Manager**: The smarter devices manager helps us to allocate hardware resources without a need for
privileged containers. **06_enable_smarter_devices.sh** script install he smarter devices manager in our cluster and enables it
for the worker node that the enclave will be running on.

6) **Run your container in Kubernetes as a pod:**: We all have been waiting for this step! With the help of **07_run_pod.sh**, we try to
run our container as a Pod in the worker node we created in the previous steps. Pods are the smallest deployable units in Kubernetes.
For more information, please check out this link: https://kubernetes.io/docs/concepts/workloads/pods/

After the script runs for the first time, the output log of the script should like this below:

```
pod/hello-nitro-enclaves created
```

If we already ran this command before, the script will try to delete the existing pod first, and create a new one with the same name:
```
pod "hello-nitro-enclaves" deleted
pod/hello-nitro-enclaves created
```

The script also creates ne_pod.yaml PodSpec file in the working directory.

7) **Check the logs**: It's time to see the application output! Our container image contains an enclave image that prints "Hello from the enclave side!
" for ten times. The **08_read_ne_logs.sh** script not only helps you to see enclave logs, but also shows you the details of the running Pod.

9) **Create the resouces for KMS demo**: Usually for the KMS demo the user would be required to create a role which is associated with the EC2 instance that has permissions to the KMS service in order to create a key, encrypt a message and decrypt the message inside the enclave. In EKS we already have a role associated with the instance but those permissions do not apply to the Kubernetes containers. In order to resolve this we require a service account that has all the required permissions. Besides creating this service account, the script will do some of the previous steps so that it does not overlap with the hello world enclave: create an ecr repository, build and push the docker image.

10) **Run the KMS demo inside of a container**: Using the generated docker image we will deploy a pod in Kubernetes that will first create a KMS key and encrypt a message using it. Afterwards the enclave is created and using the kmstool we send the encrypted message from the pod to the enclave. If everything is successful the enclave will reply with the decrypted message, which in our case is “Hello, KMS!”

11) **Check logs**: Prints out the details about the pod deployment and the execution logs.

## Closing thoughts
This quick demo demonstrates on how to run Nitro Enclaves via EKS and Kubernetes-managed nodes. We hope that you find it easy to do through this guide.
If you have more questions, feel free to reach us at |some-communication-channel|.
