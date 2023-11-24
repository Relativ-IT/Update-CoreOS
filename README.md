# Update-CoreOS

First of all, I'm used to consider containers as disposable ! What about OSes ? They are disposable to !
That's why I'm using [Fedora CoreOS](https://getfedora.org/fr/coreos?stream=stable), an immutable OS absolutly disposable : Only datas are important !

So, I'm used to boot CoreOS from a PXE/TFTP server, and to use containerized apps to deal with datas without installing anything !

Let me describe this **WIP** repo ...

## Update.sh

**dependency** : You must have [`jq`](https://jqlang.github.io/jq/) installed

A simple bash script, that relatively fit the need, that allow to download CoreOS artefacts.
This script was firstly intended to manually download `x86_64/metal/pxe` artefacts for my home lab (defaults option values)
I ended to make it more "agnostic" and "automation fitted" to allow downloading needed artefacts (with options)

Options are, space delimited : (e.g.: `./Update.sh -v true`)

- `-s` or `--stream` usually: stable, testing or next -> défault : `stable`
- `-a` or `--arch` usually: aarch64, ppc64le, s390x, x86_64 -> default: `x86_64`
- `-t` or `--artifact` ouch ! aliyun, aws, azure, azurestack, digitalocean, exoscale, gcp, hyperv, ibmcloud, kubevirt, metal, nutanix, openstack, qemu, irtualbox, vmware, vultr... and so on depending previous choices -> default : `metal`
- `-f` or `--format`Arrgh ! Really depending of previous choices -> default : `pxe`
- `-v` or `--verbose` If ever you want to see well formatted json output -> default : `false`
- `-h` or `--history`default file path to `coreos.json` that must at least contains `{}`data, there's no error check for this option !

It will ouput artefacts, GPG and SHASUM checked, and a file named as `$format.$artifact.$arch.$stream` that contains the list of downloaded files for later use .. or not
`coreos.json`/`--history` file will be updated with version number from released/downloaded artefacts to remember last updates

## Jenkinsfile

The "end user" of `Update.sh` :

- Will get gpg keys from [fedora  project](https://fedoraproject.org/fedora.gpg) as other things.
- Will get latest history file from artefact server (the PXE/TFTP server)
- Will `matrix` `Update.sh` options in order to use it and ...
- Will get downloads from `Update.sh` and upload them to PXE/TFTP server via ssh
- And save `--history` file to keep in memory of latest downloaded artefacts versions

## coreos.json

The f**g empty template of all things ! that's all we need to know :relaxed:

## TODO

send reboot cmd to servers that depend on PXE artefacts
