# osctl-template 8                2019-04-06                             19.03.0

## NAME
`osctl-template` - build, test and deploy vpsAdminOS container templates

## SYNOPSIS
`osctl-template` [*global options*] *command* [*command options*] [*arguments...*]

## DESCRIPTION
`osctl-template` manages containers that serve as builders and uses them to
build container templates. `osctl-template` itself does not know how to build
templates. It is concerned with managing build containers, executing arbitrary
builds and testing resulting templates.

`osctl-template` has to be used in conjuction with program or programs that know
how to build specific distribution templates. vpsAdminOS comes with one such
collection of template building scripts:
<https://github.com/vpsfreecz/build-vpsfree-templates/tree/branch/vpsadminos>.

See `TEMPLATE BUILDER INTERFACE` for more information about the interaction
of `osctl-template` with template building programs.

## COMMANDS
`ls` [*options*]
  List available templates.

    `-H`, `--hide-header`
      Do not show header, useful for scripts.

    `-L`, `--list`
      List available parameters and exit.
    
    `-o`, `--output` *parameters*
      Select parameters to output, comma separated.

    `-s`, `--sort` *parameters*
      Sort output by parameters, comma separated.

`build` [*options*] `all`|*template*[`,`*template...*]
  Build selected templates.

    `--build-dataset` *dataset*
      Name of a ZFS filesystem which can be used to build templates. Required.

    `--output-dir` *dir*
      Directory where the resulting templates are stored. Defaults to `./output`.

    `--vendor` *vendor*
      Override vendor attribute defined by the template.

`test` [*options*] `all`|*template*[`,`*template...*] [*test*[`,`*test...*]]
  Run one or more tests on all or selected templates. If the template is not
  found in the output directory, it is built, otherwise a cached version is
  used. Rebuild can be forced using option `--rebuild`.

    `--build-dataset` *dataset*
      Name of a ZFS filesystem which can be used to build templates. Required.

    `--output-dir` *dir*
      Directory where the resulting templates are stored. Defaults to `./output`.

    `--vendor` *vendor*
      Override vendor attribute defined by the template.

    `--rebuild`
      Rebuild the template even if it is found in the output directory.

`instantiate` [*options*] *template*
  Create a container from the build template. If the template is not found in
  the output directory, it is built, otherwise a cached version is used. Rebuild
  can be forced using option `--rebuild`.

    `--build-dataset` *dataset*
      Name of a ZFS filesystem which can be used to build templates. Required.

    `--output-dir` *dir*
      Directory where the resulting templates are stored. Defaults to `./output`.

    `--vendor` *vendor*
      Override vendor attribute defined by the template.

    `--rebuild`
      Rebuild the template even if it is found in the output directory.

    `--container` *ctid*
      Do not create a new container, but reinstall container *ctid* to
      *template*. Configuration of the existing container is kept.

`ct ls` [*options*]
  List managed build-related containers.

    `-H`, `--hide-header`
      Do not show header, useful for scripts.

    `-L`, `--list`
      List available parameters and exit.
    
    `-o`, `--output` *parameters*
      Select parameters to output, comma separated.

    `-s`, `--sort` *parameters*
      Sort output by parameters, comma separated.

## TEMPLATE BUILDER INTERFACE
Template building programs define builders and actual templates to be built.
Builders are simply containers, in which the templates are then built.

`osctl-template` requires three executable files in the current working
directory: `bin/config`, `bin/runner` and `bin/test`.

`bin/config` is used to gather information about builders and templates. It is
called from the vpsAdminOS host.

`bin/runner` is used to either setup builders or build templates. It is called
within build containers managed by `osctl-template`.

`bin/test` is used to test built templates. It is run on the vpsAdminOS host
and can use `osctl` to test containers managed by `osctl-template`. Since
the tests may require additional programs, `bin/test` is invoked by a `nix-shell`
operating on `./shell-test.nix`. You can configure your dependencies in this Nix
file.

All executables have to implement argument-based commands described below.

### bin/config interface
`bin/config builder list`
  List available builders, one per line.

`bin/config builder show` *name*
  Show builder attributes, one per line, `<attribute>=<value>`.

`bin/config template list`
  List available templates, one per line.

`bin/config template show` *name*
  Show template attributes, one per line, `<attribute>=<value>`.

### bin/runner interface
`bin/runner builder setup` *name*
  Setup build container, i.e. install required packages.

`bin/runner` template build *build-id* *work-dir* *install-dir* *name*
  Build template *name* to directory *install-dir*. Temporary files can be
  saved to *work-dir*. *build-id* should be used when creating temporary
  directories or files as a unique identifier.

### bin/test interface
`bin/test template run` *name* *ctid*
  Run test *name* on container *ctid*. The test is considered successful when
  the programs exits with `0`.

### Builder attributes

 - `DISTNAME`
 - `RELVER`
 - `ARCH`
 - `VENDOR`
 - `VARIANT`

### Template attributes

 - `BUILDER`
 - `DISTNAME`
 - `RELVER`
 - `ARCH`
 - `VENDOR`
 - `VARIANT`

Only `BUILDER` is required. Other attributes can be passed within the template
name in the following form: *DISTNAME*[`-`*RELVER*[`-`*ARCH*[`-`*VENDOR*[`-`*VARIANT*]]]]

## BUGS
Report bugs to https://github.com/vpsfreecz/vpsadminos/issues.

## ABOUT
`osctl-template` is a part of [vpsAdminOS](https://github.com/vpsfreecz/vpsadminos).