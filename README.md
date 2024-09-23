# SuperKIX for CardDemo

The original README is [README.md](README.md).

## Server configuration

For the server to work, some configurations needs to be done.
This is done in a `config.toml` file containing the following fields:

- `pct_files`, an array of paths to files containing the Program Control
Tables, i.e. informations that link transactions to programs.

- `fct_files`, an array of paths to files containing the File Control
Tables, i.e. informations that link transactions to files.

- `program_folders` is an array of pathes to folders where the GnuCOBOL modules
will be found.

- `map_folder` is the folder where the physical BMS maps will be found.

- `job` is the name that will be given when the SuperKIX application asks for a
JCL job id.

- the `[good_morning]` section contains informations on the transaction that
will be run when a new terminal is connected:
    + `prog`: the name of the program that will be run when the terminal is
    connected;
    + `tranid`: the name of the transaction that will be used when the terminal
    is connected.

> NOTE:
> All the pathes in the `config.toml` file must be relative to the `config.toml`
> file.

Example:

```toml
pct_files = ["pct.json"]
fct_files = []
program_folders = ["_build/cobol/modules"]
map_folder = "_build/map"
job = "CARDDEMO"

[files]
data_path = "app/data/EBCDIC/"
handler = "vsam"

[good_morning]
prog = "COSGN00C"
tranid = "CC00"
```

## Data configuration

A `[files]` section is dedicated to the management of files. It must contain
two fields:
- `data_path` containing the path to the data files used by the application;
- `handler` which contains either `"vsam"` or `"bdb"` depending on the backend
used to handle files.

Example:

```toml
[files]
data_path = "app/data/EBCDIC/"
handler = "vsam"
```

## Building the application

Run `make DATA_MGMT=<data_handler>` from this project's directory where
`data_handler` is:
- `sql` for SQL persistent data management;
- `vsam` for virtual access storage method.

> NOTE:
> Default paths and executable names are given in `Makefile.defaults`; to
change them in order to match your configuration, you may create a
`Makefile.config` with suitable assignments to those same variables.  The
default configuration notably assumes that `padbol`, `gixpp`, and `cobc` are
available in the `PATH`.

## Running the application from Rust sources

You must have Rust installed with `cargo`. We assume your project is at path
`~/cobol_app` and the `padbol` project at `~/padbol`.

```sh
cd ~/padbol/superkix
cp -r ~/cobol_app watcher
cargo run -- run watcher
```

then, in another terminal:

```sh
pkill -HUP server
```

You can now use:
```sh
cargo run -- run watcher
```

from `~/padbol/superkix` to run the server and wait for a terminal connection.

To connect to the server you can use any 3270 emulator that supports TN3270E,
and connect to `localhost:1024`. We recommend the
[x3270 project](https://github.com/pmattes/x3270) and in particular the `c3270`
emulator you can used that way:

```sh
$ c3270
c3270> connect localhost:1024
<ESC>
c3270> disconnect
c3270> exit
```
