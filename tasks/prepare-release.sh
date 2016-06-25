#!/bin/bash

set -e

# copy the entire packer project to the task output
cp -a concourse-packer/. prepare-release/

# copy the concourse binary to the task output
cp concourse-release/concourse_linux_amd64 prepare-release/cookbooks/concourse/files/.

# get version from the version file
VERSION=$(cat concourse-release/version)

# append the version to the base config
if [ -z "$CONFIG" ]; then
  CONFIG="$VERSION"
else
  CONFIG="$CONFIG, \"concourse_version\": \"$VERSION\" "
fi

echo "version=$VERSION"

cat <<EOF > prepare-release/secrets.json
{ $CONFIG }
EOF
