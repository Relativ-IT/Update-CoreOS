#!/bin/bash

function jqverbose { if $verbose; then echo $1; echo $2 | jq; fi; }

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
      printf "Error: Invalid argument : $1 \n"
      exit 1
  esac
  shift
  shift
done

jqverbose "Looking for previous files :" "$(cat $history)"

data="$streampath/$stream.json"
echo "Checking $stream stream updates from : $data"

data=$(curl --no-progress-meter $data | jq .architectures.$arch.artifacts.$artifact) # Downloading and then Filtering Arch & Artifatct
jqverbose "Looking for $arch $artifact release :" "$data"

FCOSrelease=$(echo $data | jq --raw-output .release) # Filtering new release version
FCOSversion=$(jq --raw-output .$stream.$arch.$artifact.$format $history) # Filtering current/last local version

if [ "${FCOSversion}" = "null" ]; then FCOSversion=0; fi; # If no previous version was found, set it to 0 for later comparison
echo FCOS $arch $artifact release : $FCOSrelease / version : $FCOSversion

if $(echo $data | jq --raw-output --arg version $FCOSversion '.release > $version') # Check for updates
then
  
  filecounter=0
  downloads=$format.$artifact.$arch.$stream
  touch $downloads.part
  truncate -s 0 $downloads.part
  files=$(echo $data | jq .formats.$format) # Filtering $format files version
  jqverbose "Update found for $format files :" "$files"

  for file in $(echo $files | jq --raw-output 'keys[]') # For each file definition
  do

    let filecounter+=1
    filename="$file.$format.$artifact.$arch.$stream"
    fileinfo=$(echo $files | jq .$file) # Filtering file informations
    jqverbose "#$filecounter $file :" "$fileinfo"

    for try in {1..2} # Let's try 2 times downloading with correct checksum/gpg
    do

      upstreamfile=$(echo $fileinfo | jq --raw-output .location) # Filtering upstream file location
      upstreamsig=$(echo $fileinfo | jq --raw-output .signature) # Filtering upstream file signature
      upstreamsha256=$(echo $fileinfo | jq --raw-output .sha256) # Filtering upstream sha256 sum

      echo "Downloading $upstreamfile to $filename"
      curl -C - --no-progress-meter --parallel \
        $upstreamfile -o $filename \
        $upstreamsig -o $filename.sig # Downloading file and its signature

      echo "Checking sha256sum and GPG signature"
      if echo "$upstreamsha256 $filename" | sha256sum --check && gpg --verify $filename.sig
        then # GPG & SHASUM are ok
          echo $filename >> $downloads.part # Add downloaded file to history
          rm $filename.sig # Del signature file that is not needed anymore
          break
        else
          rm $filename $filename.sig # Restart from beginning
      fi
    done # End for try
  done # End for file

  if [[ -f $downloads.part ]] && [[ $(wc -l < $downloads.part) == $filecounter ]]
  then # All files were successfully downloaded and checked
    mv $downloads.part $downloads
    cat <<< $(jq --arg release $FCOSrelease '.'$stream'.'$arch'.'$artifact'.'$format' = $release' $history) > $history # Updating history file
    jqverbose "Updated versions :" "$(cat $history)"
  else
    echo "Something went wrong :/"
    rm $downloads.part
  fi

else
  echo "Up to date, nothing to do"
fi