#!/usr/bin/env bash
set -e

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve symlinks
  SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$SCRIPT_DIR/$SOURCE" # resolve relative symlink
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"


#TODO validate arguments
#mandatory
cpi_release=$1
stemcell=$2
cpi_config=$3

#optional
temp_dir=${4:-`mktemp -d`}
logs=$temp_dir/logs

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


bundle_cmd="$temp_dir/packages/ruby_openstack_cpi/bin/bundle"
gems_folder=$temp_dir/packages/ruby_openstack_cpi/lib/ruby/gems/*
path=$temp_dir/packages/ruby_openstack_cpi/bin/:$PATH

env -i PATH=$path \
       GEM_PATH=$gems_folder \
       GEM_HOME=$gems_folder \
       $bundle_cmd install 2>&1 > $temp_dir/logs/bundle_install.log

env -i \
  BOSH_PACKAGES_DIR=$temp_dir/packages \
  BOSH_OPENSTACK_CPI_LOG_PATH=$temp_dir/logs \
  BOSH_OPENSTACK_STEMCELL_PATH=$temp_dir/stemcell \
  BOSH_OPENSTACK_CPI_PATH=$temp_dir/cpi \
  BOSH_OPENSTACK_CPI_CONFIG=$cpi_config \
  PATH=$path \
  GEM_PATH=$gems_folder \
  GEM_HOME=$gems_folder \
  $bundle_cmd exec gem environment 2>&1 > $temp_dir/logs/gem_environment.log
echo "Gems folder contains:" >> $temp_dir/logs/gem_environment.log
ls $temp_dir/packages/ruby_openstack_cpi/lib/ruby/gems >> $temp_dir/logs/gem_environment.log

env -i \
  BOSH_PACKAGES_DIR=$temp_dir/packages \
  BOSH_OPENSTACK_CPI_LOG_PATH=$temp_dir/logs \
  BOSH_OPENSTACK_STEMCELL_PATH=$temp_dir/stemcell \
  BOSH_OPENSTACK_CPI_PATH=$temp_dir/cpi \
  BOSH_OPENSTACK_CPI_CONFIG=$cpi_config \
  PATH=$path \
  GEM_PATH=$gems_folder \
  GEM_HOME=$gems_folder \
  $bundle_cmd exec rspec $SCRIPT_DIR/specs --order defined --color --format documentation 2> $temp_dir/logs/testsuite.log
