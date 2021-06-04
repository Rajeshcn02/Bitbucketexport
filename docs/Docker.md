# Using Docker with bbs-exporter

This guide will help build and run bbs-exporter from Docker.

## Setup

- If Docker isn't on your machine, install it by following the [Docker documentation](https://docs.docker.com/install/).
- Clone bbs-exporter from GitHub and `cd` to the repository's root:

  ```shell
  git clone https://github.com/github/bbs-exporter.git
  cd bbs-exporter
  ```

## Build the bbs-exporter image and start a container

- Build the bbs-exporter Docker image:

  ```shell
  docker build --tag bbs-exporter .
  ```

- After the image is built, start a container in the background from the bbs-exporter image:

  ```shell
  docker run --rm --detach --interactive --name bbs-exporter bbs-exporter
  ```

- Then, start a shell in the Docker container via:

  ```shell
  docker exec --interactive --tty bbs-exporter sh
  ```

## Using the bbs-exporter Docker container

Any number of shells can be called from the `docker exec` command above, and the data will remain intact even after exiting the shells.  When ready, the container and all its data will be cleaned up [when the container is stopped](#stop-the-docker-container).

From here, the [Usage section of README.md](README.md#usage) can be followed to use bbs-exporter from inside the container.

To copy an archive from the container to the Docker host, run this command **outside of the container**:

```shell
docker cp bbs-exporter:/path/to/archive.tar.gz .
```

## Stop the Docker container

When you are done using bbs-exporter from the container, run this command to stop the container:

```shell
docker stop bbs-exporter
```

**Note:** When the container is stopped, all changes made inside the container will be lost.
