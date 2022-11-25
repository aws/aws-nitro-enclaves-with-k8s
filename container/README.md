# How to create a new enclave application
To start preparing your application, please first create a folder (e.g. my_app) under the **container/** directory. From now on, the application will be known by **enclavectl** with this folder name.

Dockerfiles are needed to build a container image that holds your enclave application. In most cases, the build deliverables are:
- The enclave EIF image
- one or more instance-side applications or libraries.

There are cases when the instance application can be optional (like the `hello` example) or mandatory (like the `kms` example).

An image must also include the [Nitro CLI](https://github.com/aws/aws-nitro-enclaves-cli) to run EIF file(s) in the worker node.
If you are using [Amazon Linux](https://hub.docker.com/_/amazonlinux) as a base docker image, it can be included as below:

```bash
RUN amazon-linux-extras install aws-nitro-enclaves-cli && \
    yum install aws-nitro-enclaves-cli-devel -y
```

For other base docker images another alternative is building [Nitro CLI](https://github.com/aws/aws-nitro-enclaves-cli) from source.

## enclave_manifest.json
is a file that guides **builder** container to build enclave applications. A sample manifest structure can be seen below:

```bash
{
    "name": "manifest-name",
    "repository": "git-repository-address",
    "tag": "git tag or branch name",
    "eif": {
        "name": "my-enclave-application.eif",
        "docker": {
            "image_name": "my-enclave-application",
            "image_tag": "1.0",
            "target": "my-enclave-application-docker-target",
            "x86_64": {
                "file_path": "docker-file-folder",
                "file_name": "dockerfile-name",
                "build_path": ""
            },
            "aarch64": {
                "file_path": "docker-file-folder",
                "file_name": "dockerfile-name",
                "build_path": ""
            }
        }
    },
    "instance": {
        "docker": {
          ...
        },
        "exports": [
            "your-first-file-to-export-to-bin-dir",
            "your-second-file-to-export-to-bin-dir"
        ]
    }
}
```

The **builder** container uses [Nitro CLI](https://github.com/aws/aws-nitro-enclaves-cli) intrinsically. [Nitro CLI](https://github.com/aws/aws-nitro-enclaves-cli) also needs docker images to construct EIF files. As you can see, the items declared under **docker** object is the definition of the container that will be used by [Nitro CLI](https://github.com/aws/aws-nitro-enclaves-cli). The declaration of all the items under **docker** object is required. However, two fields can be empty string:

- `target`: If your application's Dockerfile does not have a target, you can leave it as an empty string
- `build_path` defines build_path of a **docker** image build. If the field is empty, the build directory becomes the top directory of the cloned repository

The `x86_64` and `aarch64` objects may reside together, but the build system only uses the one that matches your host machine`s architecture.

The `instance` object is optional, however, if your enclave application also contains instance-side deliverables (i.e. application which does I/O with the enclave) then the `instance` object is needed. However, once it is declared, same rules apply to it like the `eif` object. The `instance` object has one sub field that does not exist in the `eif` section. The `exports` field is an string array that instructs build system to extract one or multiple files from the build directory to the **container/bin** folder.

In essence, the build system clones the enclave application, builds an EIF (and an instance application) based on the declarations in **enclave_manifest.json** file and finally saves artifacts to **container/bin/** directory.

The use of the **builder** container is also optional, and it is designed to facilitate build process in this tutorial. [Nitro CLI](https://github.com/aws/aws-nitro-enclaves-cli) can be built and used directly on your system, if wanted.

## hooks.sh
is optional and holds some hook functions to perform application-specific processing. A template for this file can be seen below:

```
on_run() {
  return $SUCCESS
}

on_file_requested() {
  local $filaname=$1
  local $target_dir=$2
  return $SUCCESS
}

on_stop() {
  return $SUCCESS
}

```

The `enclavectl` tool checks the existence of this file in your application's directory. If the file does not exist in the folder, or the functions highlighted above are not defined in **hooks.sh**, `enclavectl` will not try to call any of these functions. So, their implementation can be omitted based on the use case. On the other hand, when a function is implemented, it always needs to return success so that the **enclavectl** also succeeds.

  - `on_run` is triggered right after the `enclavectl run` command. This hook function helps user to perform certain initialization before the deployment.
  - `on_file_requested` is a variadic function. The first two arguments are required: `filename` and `target_dir`. The implementer needs to identify the **$filename** and create it in the **$target_dir** directory. Whenever **enclavectl** needs to create an application-specific file, it may call this hook function with different number of arguments based on the context. For example, when it is called with `<your_projectname>_deployment.yaml` as the first argument, **$image_name** and **$repository_uri** also passed as the third and fourth arguments, respectively.
  - `on_stop` is executed after the call made to `enclavectl stop` command. Used to rollback the initialization that was performed in `on_run` function if necessary.
