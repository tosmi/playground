#!/bin/bash -x

set -euf -o pipefail

echo "Number of source images: $#"
echo "Source images: $*"
echo "Destination: ${PARAM_MULTIARCH_IMAGE}"

# buildah manifest create "${PARAM_MULTIARCH_IMAGE}

for image in "${@}"; do
  echo "${image}"
done