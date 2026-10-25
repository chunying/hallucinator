# hallucinator
A Sandboxed Runtime for Hallucinated Reference Detector

This repository packages [gianlucasb/hallucinator](https://github.com/gianlucasb/hallucinator),
a tool that checks the references in a paper for citations that do not exist,
into a Docker image. Thin wrapper scripts run the tool inside a disposable
container. The container can only see the directory holding the file you are
checking and a Docker volume named `hallucinator` that stores the offline
bibliographic databases.

## Requirements

- Docker with the Buildx plugin (included in Docker Desktop and recent Docker Engine releases)
- Python 3 (for the `hallucinator` and `update-db` wrapper scripts)

On Windows, see [Windows](#windows).

## Repository layout

| Path                   | Description                                                        |
|------------------------|--------------------------------------------------------------------|
| `build.sh`             | Builds the `chunyingh/hallucinator` Docker image, or pushes a multi-arch build to Docker Hub |
| `hallucinator`         | Runs `hallucinator-tui` on a file inside the container             |
| `update-db`            | Downloads or updates the offline databases in the `hallucinator` volume |
| `docker/Dockerfile`    | Multi-stage build: compiles the Rust tools, then copies them into an Alpine runtime image |
| `docker/tini.sh`       | Container entrypoint: hands `/db` to your UID/GID, then starts `tini` |
| `docker/entrypoint.sh` | Default container command (keeps the container idle)               |
| `docker/profile`       | Shell prompt and aliases for interactive sessions                  |

## Build the image

```sh
sh build.sh
```

The build uses `docker buildx build --load`. It clones the latest upstream
`hallucinator` source and compiles `hallucinator-tui` and `hallucinator-cli`
with `cargo build --release`. The binaries are installed into an Alpine-based
runtime image tagged `chunyingh/hallucinator:latest`, built for your machine's
architecture and loaded into the local Docker image store. To pick up upstream
changes, run the build again.

If you skip the build, the wrapper scripts make `docker run` pull
`chunyingh/hallucinator` from Docker Hub the first time they run.

### Optional: push a multi-arch image to Docker Hub

```sh
sh build.sh push
```

This builds for `linux/amd64` and `linux/arm64` and pushes the result to
Docker Hub as `chunyingh/hallucinator:latest`. The image is not loaded into
the local image store. Before the first push:

1. Log in to Docker Hub with an account that can push to the repository:

   ```sh
   docker login
   ```

2. Create a builder that uses the `docker-container` driver, because the
   default `docker` driver usually cannot build multi-platform images:

   ```sh
   docker buildx create --name multiarch-builder --driver docker-container --use
   docker buildx inspect --bootstrap   # start the builder and list supported platforms
   docker buildx ls                    # confirm multiarch-builder is selected (*)
   ```

   You only need to do this once per machine. `--use` makes it the current
   builder; to switch back later, run `docker buildx use default`.

   To build the platform that does not match your host, the builder uses QEMU
   emulation. Docker Desktop includes it. On Linux, if `inspect` does not list
   both platforms, install the emulators:

   ```sh
   docker run --privileged --rm tonistiigi/binfmt --install all
   ```

   Compiling Rust under emulation is slow, so expect the cross-architecture
   half of the build to take much longer than the native one.

To push to your own Docker Hub repository, change the `-t` tag in `build.sh`
and the image name in `hallucinator` and `update-db` to match.

## Offline databases

Lookups against local copies of the major bibliographic indexes are faster and
more reliable than online queries. The databases live in a Docker volume named
`hallucinator`, which Docker creates on first use. `update-db` runs
`hallucinator-cli` in the container to fetch them into that volume:

```sh
./update-db                 # update the default set: dblp, acl, iacr
./update-db arxiv openalex  # update only the named databases
./update-db shell           # open a shell in the container with the volume at /db
```

| Name       | File           | Updated by default |
|------------|----------------|:------------------:|
| `dblp`     | `dblp.db`      | yes                |
| `acl`      | `acl.db`       | yes                |
| `iacr`     | `iacr.db`      | yes                |
| `arxiv`    | `arxiv.db`     | no                 |
| `openalex` | `openalex.idx` | no                 |

Some sources need credentials. If `KAGGLE_API_TOKEN` is set in your
environment, it is passed into the container for the Kaggle-hosted downloads:

```sh
KAGGLE_API_TOKEN=... ./update-db arxiv
```

The databases can be large (`dblp.db` alone is several GB). Because they are
kept in the volume rather than in this repository, they persist across image
rebuilds. To see where Docker stores them, or to reclaim the space:

```sh
docker volume inspect hallucinator
docker volume rm hallucinator   # deletes all downloaded databases
```

## Check a paper

```sh
./hallucinator [options] /path/to/paper.pdf
```

Supported inputs are files ending in `.pdf`, `.bbl`, `.bib`, `.zip` or `.gz`.
The script:

1. Finds the first argument with a supported extension and mounts its directory
   as `/home/workdir` in the container. This is the only part of the host file
   system the tool can see.
2. Mounts the `hallucinator` volume as `/db`. In the image,
   `~/.local/share/hallucinator` links to `/db`, so `hallucinator-tui` finds the
   offline databases in its default location without extra options.
3. Runs `hallucinator-tui` as your own UID/GID, so any output files belong to
   you. The container is removed when the tool exits. On platforms where Python
   has no `os.getuid` (such as Windows), the scripts use UID/GID 0 instead.

All other arguments are passed through to `hallucinator-tui` unchanged. For the
available options, see the upstream project or run:

```sh
./hallucinator --help
```

### Interactive shell

```sh
./hallucinator          # shell with only the database volume
./hallucinator mount    # shell with the current directory mounted as well
```

Running `./hallucinator` without arguments prints the usage line and opens a
login shell in the container. Only the `hallucinator` volume is mounted, at
`/db`, which is also the starting directory; no host directory is visible.

With `mount`, the shell also mounts the current directory as `/home/workdir`
and starts there, so you can work on the files in it.

From either shell you can run `hallucinator-tui` or `hallucinator-cli` by hand.

## Windows

The wrapper scripts work on Windows with Docker Desktop and Python 3. Run them
in Windows Terminal (PowerShell or Command Prompt).

**Pull the image from Docker Hub.** `build.sh` is a POSIX shell script, so on
Windows use the published multi-arch image instead of building it:

```powershell
docker pull chunyingh/hallucinator
```

Run the same command again to pick up a newer image.

**Run the scripts through Python.** Windows ignores the `#!/usr/bin/env python3`
line, so `./hallucinator` does not work. Pass the script to the Python launcher
`py` instead (or to `python` if your installation has no `py`):

```powershell
py update-db
py update-db arxiv openalex
py hallucinator C:\Users\me\Papers\paper.pdf
py hallucinator                 # interactive shell
py hallucinator mount           # interactive shell with the current folder mounted
```

Paths with backslashes, forward slashes or spaces all work. Everything else
behaves as described above, except that the container runs as root (UID/GID 0),
because Windows has no Unix user IDs. This has no effect on the files you see
in Windows.

## License

MIT. See [LICENSE](LICENSE). The upstream `hallucinator` project is covered by
its own license.
