set -eux -o pipefail

export DV_COPT_FLAGS="--copt=-msse4.1 --copt=-msse4.2 --copt=-mavx --copt=-O3"
# TensorFlow 1.7.0
export DV_TENSORFLOW_GIT_SHA="024aecf414941e11eb643e29ceed3e1c47a115ad"
export DV_PACKAGE_CURL_PATH="https://storage.googleapis.com/deepvariant/packages"

PATH="$HOME/bin:$PATH"

# run tests
bazel test -c opt --local_test_jobs=1 ${DV_COPT_FLAGS} "$@" deepvariant/...
bazel test -c opt --local_test_jobs=1 ${DV_COPT_FLAGS} "$@" deepvariant:gpu_tests

# build binaries
bazel build -c opt ${DV_COPT_FLAGS} "$@" deepvariant:binaries

# Bundle the licenses
bazel build :licenses_zip