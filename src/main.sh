#!/usr/bin/env bash
set -e

function usage() {
  echo "Usage: validate <cpi release path> <stemcell path> <validator config path> [<working dir>]"
}

function error_with_usage() {
  echo "Error:" $1
  echo
  usage
  exit 1
}

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve symlinks
  SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$SCRIPT_DIR/$SOURCE" # resolve relative symlink
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"


cpi_release=$1
stemcell=$2
validator_config=$3

if [ -z "$cpi_release" ]; then
  error_with_usage "missing cpi release path"
fi
if [ -z "$stemcell" ]; then
  error_with_usage "missing stemcell path"
fi
if [ -z "$validator_config" ]; then
  error_with_usage "missing config path"
fi

#optional
temp_dir=${4:-`mktemp -d`}

logs=$temp_dir/logs
cpi_config=$temp_dir/cpi.json

source $SCRIPT_DIR/functions.sh

echo "Using '$temp_dir' as temporary directory"
mkdir -p $temp_dir

if [ -z "$(ls -A $temp_dir)" ]; then
  mkdir -p $logs
  echo "Installing CPI"
  install_cpi $cpi_release $cpi_config $temp_dir/cpi
  # TODO marker for stemcell version for validation
  extract_stemcell $stemcell $temp_dir/stemcell
  echo $cpi_release > $temp_dir/.completed
fi

if [ ! -e $temp_dir/.completed ]; then
  echo "The CPI installation did not finish successfully."
  echo "Execute 'rm -rf $temp_dir' and run the tests again."
  exit 1
fi

if [ "$(cat $temp_dir/.completed)" != "$cpi_release" ]; then
  echo "Provided CPI and pre-installed CPI don't match."
  echo "Execute 'rm -rf $temp_dir' and run the tests again."
  exit 1
fi

bundle_cmd="BUNDLE_GEMFILE=$SCRIPT_DIR/../Gemfile $temp_dir/packages/ruby_openstack_cpi/bin/bundle"
gems_folder=$temp_dir/packages/ruby_openstack_cpi/lib/ruby/gems/*
path=$temp_dir/packages/ruby_openstack_cpi/bin/:$PATH

set +e
logfile_path=$temp_dir/logs/bundle_install.log
env -i BUNDLE_CACHE_PATH="vendor/package" \
       PATH=$path \
       GEM_PATH=$gems_folder \
       GEM_HOME=$gems_folder \
       $bundle_cmd install --local 2>&1 > $logfile_path
       print_log_on_failure $logfile_path

env -i PATH=$path \
       GEM_PATH=$gems_folder \
       GEM_HOME=$gems_folder \
       BOSH_OPENSTACK_VALIDATOR_CONFIG=$validator_config \
       $bundle_cmd exec ruby $SCRIPT_DIR/generate_cpi_json.rb $cpi_config

exit_on_error

env -i \
  BOSH_PACKAGES_DIR=$temp_dir/packages \
  BOSH_OPENSTACK_CPI_LOG_PATH=$temp_dir/logs \
  BOSH_OPENSTACK_STEMCELL_PATH=$temp_dir/stemcell \
  BOSH_OPENSTACK_CPI_PATH=$temp_dir/cpi \
  BOSH_OPENSTACK_CPI_CONFIG=$cpi_config \
  PATH=$path \
  GEM_PATH=$gems_folder \
  GEM_HOME=$gems_folder \
  http_proxy=$http_proxy \
  https_proxy=$https_proxy \
  no_proxy=$no_proxy \
  $bundle_cmd exec gem environment 2>&1 > $temp_dir/logs/gem_environment.log
echo "Gems folder contains:" >> $temp_dir/logs/gem_environment.log
ls $temp_dir/packages/ruby_openstack_cpi/lib/ruby/gems >> $temp_dir/logs/gem_environment.log

if [ "${FAIL_FAST}" == "true" ];
then
  FAIL_FAST_OPTION="--fail-fast"
else
  FAIL_FAST_OPTION=""
fi

if [  -z ${TAG+x} ];
then
  TAG_OPTION=""
else
  TAG_OPTION="--tag ${TAG}"
fi

env -i \
  BOSH_PACKAGES_DIR=$temp_dir/packages \
  BOSH_OPENSTACK_CPI_LOG_PATH=$temp_dir/logs \
  BOSH_OPENSTACK_STEMCELL_PATH=$temp_dir/stemcell \
  BOSH_OPENSTACK_CPI_PATH=$temp_dir/cpi \
  BOSH_OPENSTACK_VALIDATOR_CONFIG=$validator_config \
  BOSH_OPENSTACK_CPI_CONFIG=$cpi_config \
  BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP=$BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP \
  VERBOSE_FORMATTER=$VERBOSE_FORMATTER \
  PATH=$path \
  GEM_PATH=$gems_folder \
  GEM_HOME=$gems_folder \
  http_proxy=$http_proxy \
  https_proxy=$https_proxy \
  no_proxy=$no_proxy \
  HOME=$HOME \
  $bundle_cmd exec rspec $SCRIPT_DIR/specs $TAG_OPTION $FAIL_FAST_OPTION --order defined \
  --color --require $SCRIPT_DIR/../lib/formatter.rb --format TestsuiteFormatter 2> $temp_dir/logs/testsuite.log
