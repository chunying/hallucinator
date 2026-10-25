# hallucinator
A Sandboxed Runtime for Hallucinated Reference Detector

This repository packages [gianlucasb/hallucinator](https://github.com/gianlucasb/hallucinator),
a tool that checks the references in a paper for citations that do not exist,
into a Docker image. Thin wrapper scripts run the tool inside a disposable
container. The container can only see the directory holding the file you are
checking and a Docker volume named `hallucinator` that stores the offline
bibliographic databases.

## Requirements

- Docker
- Python 3 (for the `hallucinator` and `update-db` wrapper scripts)

## Repository layout

| Path                   | Description                                                        |
|------------------------|--------------------------------------------------------------------|
| `build.sh`             | Builds the `chuang/hallucinator` Docker image                      |
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

The build clones the latest upstream `hallucinator` source and compiles
`hallucinator-tui` and `hallucinator-cli` with `cargo build --release`. The
binaries are installed into an Alpine-based runtime image tagged
`chuang/hallucinator`. To pick up upstream changes, run the build again.

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

Running `./hallucinator` without arguments prints the usage line and opens a
login shell in the container. Only the `hallucinator` volume is mounted, at
`/db`, which is also the starting directory; no host directory is visible.
From there you can run `hallucinator-tui` or `hallucinator-cli` by hand.

## License

MIT. See [LICENSE](LICENSE). The upstream `hallucinator` project is covered by
its own license.
