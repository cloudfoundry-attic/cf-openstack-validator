#!/usr/bin/env bash

: ${temp_dir:?}
: ${logs:?}

function install_cpi() {
  local src=$1
  local cpi_config=$2
  local target=$3
  extract_release $src $temp_dir/cpi-release
  compile_package ruby_openstack_cpi $temp_dir/cpi-release $temp_dir/packages
  compile_package bosh_openstack_cpi $temp_dir/cpi-release $temp_dir/packages
  render_cpi $target $temp_dir/packages $cpi_config
}

function extract_release() {
  local src=$1
  local target=$2
  echo "Extracting release '$src' into '$target'"
  mkdir -p $target
  tar -xzf $src -C $target
  pushd $target/packages > /dev/null
    mkdir ruby_openstack_cpi
    tar -xzf ruby_openstack_cpi.tgz -C ruby_openstack_cpi

    mkdir bosh_openstack_cpi
    tar -xzf bosh_openstack_cpi.tgz -C bosh_openstack_cpi
  popd > /dev/null
}

function extract_stemcell() {
  local src=$1
  local target=$2
  mkdir -p $target
  tar -xzf $src -C $target
}

function compile_package() {
  local package_name=$1
  local src=$2
  local target=$3

  echo "Compiling package '$package_name' from '$src' into '$target'"
  mkdir -p $target/$package_name
  pushd $src/packages/$package_name > /dev/null
    chmod +x ./packaging
    logfile_path=$logs/packaging-$package_name.log
    set +e
    env -i PATH=$PATH BOSH_INSTALL_TARGET=$target/$package_name BOSH_PACKAGES_DIR=${target} ./packaging &> $logfile_path
    print_log_on_failure $logfile_path
  popd > /dev/null
}

function render_cpi() {
  local target=$1
  local packages=$2
  local cpi_config=$3

  #TODO we should really render from our release (we will have to fork external_cpi.rb though)
  echo "Render CPI executable as '$target'"
  cat > "$target" <<EOF
#!/usr/bin/env bash

BOSH_PACKAGES_DIR=\${BOSH_PACKAGES_DIR:-$packages}

PATH=\$BOSH_PACKAGES_DIR/ruby_openstack_cpi/bin:\$PATH
export PATH

export BUNDLE_GEMFILE=\$BOSH_PACKAGES_DIR/bosh_openstack_cpi/Gemfile

bundle_cmd="\$BOSH_PACKAGES_DIR/ruby_openstack_cpi/bin/bundle"
read -r INPUT
echo \$INPUT | \$bundle_cmd exec \$BOSH_PACKAGES_DIR/bosh_openstack_cpi/bin/openstack_cpi $cpi_config
EOF
  chmod +x $target
}

function print_log_on_failure() {
    if [ $? -ne 0 ]; then
        set -e
        echo "You can find more information in the logs at $1"
        exit 1
    fi
}