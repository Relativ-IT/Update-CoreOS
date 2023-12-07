#!/bin/bash

jqverbose() {
  if $verbose; then echo $1; echo $2 | jq; fi;
}

stream="stable"
arch="x86_64"
artifact="metal"
format="pxe"
history='coreos.json'
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
    -h|--history)
      history="$2"
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

jqverbose "Looking for previous files :" "$(cat $history)"

data="$streampath/$stream.json"
echo "Checking updates for $stream stream from : $data"

data=$(curl --no-progress-meter $data | jq .architectures.$arch.artifacts.$artifact) # Filtering Arch & Artifatct
jqverbose "Looking for $arch $artifact release :" "$data"

FCOSrelease=$(jq -n "$data" | jq --raw-output .release) # Filtering release version
FCOSversion=$(jq --raw-output .$stream.$arch.$artifact.$format $history) # Filtering current/last version

if [ "${FCOSversion}" = "null" ]; then FCOSversion=0; fi;

echo FCOS release: $FCOSrelease / FCOS version: $FCOSversion

if $(jq -n "$data" | jq --raw-output --arg version $FCOSversion '.release > $version') # Check for updates
then
  
  downloads=$format.$artifact.$arch.$stream
  files=$(jq -n "$data" | jq .formats.$format) #filtering $format files version
  jqverbose "Update found for $format files :" "$files"
  filecounter=0

  for file in $(jq -n "$files" | jq --raw-output 'keys[]') #downloading all files
  do

    let filecounter+=1
    filename="$file.$format.$artifact.$arch.$stream"
    fileinfo=$(jq -n "$files" | jq .$file) #filtering each file informations
    jqverbose "#$filecounter $file :" "$fileinfo"

    for try in {1..2} # Let's try 2 times downloading with correct checksum/gpg
    do

      echo "Downloading $(jq -n "$fileinfo" | jq --raw-output .location) to $filename"
      curl -C - --no-progress-meter --parallel \
        -o $filename $(jq -n "$fileinfo" | jq --raw-output .location) \
        -o $filename.sig $(jq -n "$fileinfo" | jq --raw-output .signature) #Downloading fileinfo.location and .signature

      echo "Checking sha256sum and GPG signature"
      if echo "$(jq -n "$fileinfo" | jq --raw-output .sha256) $filename" | sha256sum --check && gpg --verify $filename.sig
        then # GPG & SHASUM are ok
          echo $filename >> $downloads.part # Add downloaded file to history
          rm $filename.sig # del signature file that is not needed anymore
          break
        else
          rm $filename $filename.sig # restart from beginning
      fi
    done # End for try
  done # End for file

  if [[ -f $downloads.part ]] && [[ $(wc -l < $downloads.part) == $filecounter ]]
  then # All files were successfully downloaded and checked
    mv $downloads.part $downloads
    cat <<< $(jq --arg release $FCOSrelease '.'$stream'.'$arch'.'$artifact'.'$format' = $release' $history) > $history # Updating history file
    jqverbose "Updated versions :" "$(cat $history)"
  fi

else
  echo "Up to date, nothing to do"
fi