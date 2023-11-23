#!/bin/bash

jqverbose() {
  if $verbose; then echo $1 | jq; fi;
}

stream="stable"
arch="x86_64"
artifact="metal"
format="pxe"
versions='coreos.json'
streampath='https://builds.coreos.fedoraproject.org/streams'
verbose=false

while [ $# -gt 0 ]; do
  case "$1" in
    -s|--stream)
      stream="$2"
      ;;
    -a|--arch)
      arch="$2"
      ;;
    -t|--artifact)
      artifact="$2"
      ;;
    -f|--format)
      format="$2"
      ;;
    -v|--verbose)
      verbose="$2"
      ;;
    *)
      printf "***************************\n"
      printf "* Error: Invalid argument.*\n"
      printf "***************************\n"
      exit 1
  esac
  shift
  shift
done

data="$streampath/$stream.json"
echo "Checking updates from $stream stream from : $data"

echo "Looking for $artifact $arch release"
data=$(curl --no-progress-meter $data | jq .architectures.$arch.artifacts.$artifact)
jqverbose "${data}"

FCOSrelease=$(jq -n "$data" | jq --raw-output .release)
FCOSversion=$(jq --raw-output .$stream.$arch.$artifact.$format $versions)

if [ "${FCOSversion}" = "null" ]
then
  FCOSversion=0
fi

echo FCOSrelease: $FCOSrelease / FCOSversion: $FCOSversion

if $(jq -n "$data" | jq --raw-output --arg version $FCOSversion '.release > $version')
then
  echo "Looking for $format files"
  files=$(jq -n "$data" | jq .formats.$format) #filtering $format files version
  jqverbose "${files}"
  for file in $(jq -n "$files" | jq --raw-output 'keys[]') #downloading all files
  do

    echo "Looking for $file"
    filename="$file.$format.$artifact.$arch.$stream"
    fileinfo=$(jq -n "$files" | jq .$file) #filtering each file informations
    jqverbose "${fileinfo}"

    for try in {1..2} #let's try 2 times downloading with correct checksum
    do
      echo "Downloading $(jq -n "$fileinfo" | jq --raw-output .location) to $filename"
      curl -C - --no-progress-meter --parallel \
        -o $filename $(jq -n "$fileinfo" | jq --raw-output .location) \
        -o $filename.sig $(jq -n "$fileinfo" | jq --raw-output .signature) #Downloading fileinfo.location and .signature
      echo "Check sha256sum and GPG signature"
      if echo "$(jq -n "$fileinfo" | jq --raw-output .sha256) $filename" | sha256sum --check && gpg --verify $filename.sig
        then
          break
        else
          rm $filename $filename.sig
      fi
    done
  done
  cat <<< $(jq --arg release $FCOSrelease '.'$stream'.'$arch'.'$artifact'.'$format' = $release' $versions) > $versions
else
  echo "Up to date, nothing to do"
fi