# How to create your own application?
To start preparing your application, please first create a folder (e.g. my_app) under the **container/** directory. From now on, the your application will be known by **nectl** with this folder name.
To successfully integrate your project, the existence of the files mentioned below in your application folder is essential.

## Dockerfile
is needed to build a container image that holds your enclave application. Generally, an enclave applications exist as pairs. An EIF image and instance application. There are cases that the instance application can be optional (like hello example) based on requirements, though. A typical image must also include the [Nitro CLI](https://github.com/aws/aws-nitro-enclaves-cli) to run EIF file in the worker node. If you are using [Amazon Linux](https://hub.docker.com/_/amazonlinux) as a parent image, the tool can be added to your image like below:

```
RUN amazon-linux-extras install aws-nitro-enclaves-cli && \
    yum install aws-nitro-enclaves-cli-devel jq -y
```

Otherwise, you might consider building [Nitro CLI](https://github.com/aws/aws-nitro-enclaves-cli) from its sources.
<br />

## enclave_manifest.json
is a file that guides **builder** container to build enclave applications. A sample manifest skeleton can be seen below.

```
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
The fields in the example above are self-explanatory. However, the `eif` object is worth an explanation, though. The **builder** container uses [Nitro CLI](https://github.com/aws/aws-nitro-enclaves-cli) intrinsically. [Nitro CLI](https://github.com/aws/aws-nitro-enclaves-cli) also needs docker images to construct EIF files. As you can see, the items declared under **docker** object is the definition of the container that will be used by [Nitro CLI](https://github.com/aws/aws-nitro-enclaves-cli). The declaration of all the items under **docker** object is required. However, two fields can be empty string:

- `target`: If your application's Dockerfile does not have a target, you can leave it as an empty string.
- `build_path` defines build_path of a **docker** image build. If the field is empty, the build directoy becomes the top directory of the cloned repository.

`x86_64` and `aarch64` objects may reside together, but the build system only uses the one that matches your host machine`s architecture.

If your enclave application is formed as a pair, you also need to build an instance application along with an EIF. The `instance` object is helpful when you want to build your instance application in the **builder** container. Its declaration is optional. However, once it is declared, same rules apply to it like the `eif` object. The `instance` object has one sub field that does not exist in the `eif`. The `export` field is an string array that instructs build system to extract one or multiple files from the build directory to the **container/bin** folder.

In essence, the build system clones the enclave application, builds an EIF (and an instance application) based on the declarations in **enclave_manifest.json** file and finally saves artifacts to **container/bin/** directory.

The use of the **builder** container is also optional, and it is designed to faciliate build process in this tutorial. [Nitro CLI](https://github.com/aws/aws-nitro-enclaves-cli) can be built and used directly on your system, if wanted.
<br />

## hooks.sh
is optional and holds some hook functions to perform application-specific processing. A template for this file can be seen below:

```
on_run() {
  return $SUCCESS
}

on_file_requested() {
  local $filaname=$1
  return $SUCCESS
}

on_stop() {
  return $SUCCESS
}

```

**nectl** tool checks the existence of this file in your application's directory after certain events take place. If the file does not exist in the folder, or the functions highlighted above are not defined in **hooks.sh**, **nectl** will not try to call any of these functions. So, their implementation can be omitted based on the use case. On the other hand, when a function is implemented, it
always needs to return success so that the **nectl** also succeeds.

  - `on_run` is triggered right after the `nectl run` command. This hook function helps user to perform certain initializations before the deployment.
  - `on_file_requested` has one argument: `filepath`. Whenever **nectl** needs an application-specific file, it calls this hook function with the **$filepath**. The implementer needs to identify the base filename and create it in the **$filepath** path.
  - `on_stop` is executed after the call made to `nectl stop` command. Used to rollback the initialization that was performed in `on_run` function if necessary.
<br />
