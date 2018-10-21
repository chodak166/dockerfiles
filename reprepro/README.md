# Debian APT package repository docker image

## Original image
This image is a fork of the *iomoss* reprepro image available [here](https://bitbucket.org/iomoss/docker-files). Main changes introduce multiple distribution support and some repo helpers. As the original image, this should be considered as in-house deb package server, not designed to fulfill the role of a full repository.

## Building the image (in-house)
```bash
$ git clone https://github.com/chodak166/dockerfiles
$ cd dockerfiles/reprepro
$ docker build -t reprepro .
```

## Running (stand-alone)
### Interactive mode
You can start the server as;
```bash
$ docker run \
-v ~/apt:/srv/ \
-v /dev/urandom:/dev/random \
-p 8080:80 \
-p 2222:22 \
--name apt-repo \
-it reprepro
```
Interactive entry point will ask about key-related info and optional `debian` user password. If the password is set, the packages can be uploaded via `scp` with password prompt. You can also use `ssh` login anytime to add authorized keys. 

The `authorized_keys` file (for uploading packages without password prompt) can be supplied from outside the container, by creating the file:

```bash
$CONFIG_FOLDER/home/debian/.ssh/authorized_keys
```
Assuming you have generated a ssh key-set on the machine, you can do this by running;
```bash
$ cp ~/.ssh/id_rsa.pub $CONFIG_FOLDER/home/debian/.ssh/authorized_keys
```
Generating a ssh key-set can be done by running;
```bash
$ ssh-keygen
```

*Note: If no `authorized_keys` are provided, uploading packages will still be posible if `debian` user password will be provided when running in interactive mode.*

### Non-interactive mode
For non-interactive mode and out-of-container configuration details, please see [the original image readme](https://bitbucket.org/iomoss/docker-files/src/45206e6002311e7d9aac1f1c0518b4ddedc22da5/reprepro/?at=master).

## Uploading packages
The below assumes that you are in the folder of your `.deb` package.

The example is based upon uploading `mypackage.deb` to `aptrepo.lan` with codename `bionic`, component `main` nad `amd64` architecture.

```bash
$ scp -P SSH_PORT mypackage.deb debian@$aptrepo.lan:/apt/bionic/main/amd64/
$ ssh -p SSH_PORT debian@$HOSTNAME "repo-update"
```

The `repo-update` will scan the `/apt` incoming directory and use codename, component and arch directory names to update the actual repository. Many `.deb` packages can be uploaded before running `repo-update` script. 

## Client Configuration
Once the repository is up and running, clients will need to be configured to use it.

The nginx webserver (which hosts the repository) has an index page with configuration information.

Assuming your repository local domain is `aptrepo.lan`, and the internal port `80` is exposed as port `8080`, clients in the local network may use instructions as presented below.

### Registering the GPG public key
```bash
$ wget -O - http://aptrepo.lan/public.gpg.key | apt-key add - 
```

### Registering the repository to `sources.list.d`
```bash
$ echo "deb http://aptrepo.lan/ $CODE_NAME main" > /etc/apt/sources.list.d/aptrepo.lan.list 
```

### Installing packages
At this point the repository is added, and you can run;
```bash
$ apt-get update
$ apt-get install $PACKAGE_NAME
```
To install `$PACKAGE_NAME` from your own repository to the client system.

*Note: The repository is non-functional until the first package has been added.*
