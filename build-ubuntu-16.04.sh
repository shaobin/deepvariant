set -eux -o pipefail

export DV_COPT_FLAGS="--copt=-msse4.1 --copt=-msse4.2 --copt=-mavx --copt=-O3"
# TensorFlow 1.8.0
export DV_TENSORFLOW_GIT_SHA="93bc2e2072e0daccbcff7a90d397b704a9e8f778"
export DV_PACKAGE_CURL_PATH="https://storage.googleapis.com/deepvariant/packages"

# install prerequisite
sudo -H apt-get -qq -y update
sudo -H apt-get -y install pkg-config zip zlib1g-dev unzip curl g++ git
# for htslib
sudo -H apt-get -y install libssl-dev libcurl4-openssl-dev liblz-dev libbz2-dev liblzma-dev
# for the debruijn graph
sudo -H apt-get -y install libboost-graph-dev
sudo -H apt-get -y install libcupti-dev
sudo -H apt-get -y install parallel

sudo -H apt-get -y install python-dev python-pip python-wheel
sudo -H pip install --upgrade pip

sudo -H pip install contextlib2
sudo -H pip install enum34
sudo -H pip install intervaltree
sudo -H pip install 'mock>=2.0.0'
sudo -H pip install 'numpy>=1.12'
sudo -H pip install 'requests>=2.18'
sudo -H pip install 'scipy>=1.0'
sudo -H pip install 'oauth2client>=4.0.0'
sudo -H pip install 'crcmod>=1.7'
sudo -H pip install six
sudo -H pip install --upgrade 'tensorflow-gpu==1.8.0'

# Java is available on Kokoro, so we add this cutout.
if ! java -version 2>&1 | fgrep "1.8"; then
  echo "No Java 8, will install."
  sudo -H apt-get install -y software-properties-common debconf-utils
  sudo add-apt-repository -y ppa:webupd8team/java
  sudo -H apt-get -qq -y update
  echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
  sudo -H apt-get install -y oracle-java8-installer
  sudo -H apt-get -y install ca-certificates-java
  sudo update-ca-certificates -f
else
  echo "Java 8 found, will not reinstall."
fi

function update_bazel_linux {
  BAZEL_VERSION=$1
  rm -rf ~/bazel
  mkdir ~/bazel

  pushd ~/bazel
  curl -L -O https://github.com/bazelbuild/bazel/releases/download/"${BAZEL_VERSION}"/bazel-"${BAZEL_VERSION}"-installer-linux-x86_64.sh
  chmod +x bazel-*.sh
  ./bazel-"${BAZEL_VERSION}"-installer-linux-x86_64.sh --user
  rm bazel-"${BAZEL_VERSION}"-installer-linux-x86_64.sh
  popd

  PATH="$HOME/bin:$PATH"
}

bazel_ver="0.11.1"
if
  v=$(bazel --bazelrc=/dev/null --nomaster_bazelrc version) &&
  echo "$v" | awk -v b="$bazel_ver" '/Build label/ { exit ($3 != b)}'
then
  echo "Bazel $bazel_ver already installed on the machine, not reinstalling"
else
  update_bazel_linux "$bazel_ver"
fi

if [[ -e /usr/local/clif/bin/pyclif ]];
then
  echo "CLIF already installed."
else
  # Figure out which linux installation we are on to fetch an appropriate
  # version of the pre-built CLIF binary. Note that we only support now Ubuntu
  # 14 and 16.
  case "$(lsb_release -d)" in
    *Ubuntu*16.*.*) export DV_PLATFORM="ubuntu-16" ;;
    *Ubuntu*14.*.*) export DV_PLATFORM="ubuntu-14" ;;
    *) echo "CLIF is not installed on this machine and a prebuilt binary is not
unavailable for this platform. Please install CLIF at
https://github.com/google/clif before continuing."
    exit 1
  esac

  OSS_CLIF_CURL_ROOT="${DV_PACKAGE_CURL_PATH}/oss_clif"
  OSS_CLIF_PKG="oss_clif.${DV_PLATFORM}.latest.tgz"

  if [[ ! -f "/tmp/${OSS_CLIF_PKG}" ]]; then
    curl "${OSS_CLIF_CURL_ROOT}/${OSS_CLIF_PKG}" > /tmp/${OSS_CLIF_PKG}
  fi

  (cd / && sudo tar xzf "/tmp/${OSS_CLIF_PKG}")
  sudo ldconfig  # Reload shared libraries.
fi

rm -fr ../tensorflow

(cd .. &&
 git clone https://github.com/tensorflow/tensorflow &&
 cd tensorflow &&
 git checkout "${DV_TENSORFLOW_GIT_SHA}" &&
 echo | ./configure)

# run tests
bazel test -c opt --local_test_jobs=1 ${DV_COPT_FLAGS} "$@" deepvariant/...
bazel test -c opt --local_test_jobs=1 ${DV_COPT_FLAGS} "$@" deepvariant:gpu_tests

# build binaries
#bazel build -c opt ${DV_COPT_FLAGS} "$@" deepvariant:binaries
# Bundle the licenses
#bazel build :licenses_zip

# build release binaries
bazel --batch build -c opt ${DV_COPT_FLAGS} --build_python_zip :binaries
bazel --batch build :licenses_zip
