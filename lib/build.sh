build_failed() {
  head "Build failed"
  echo ""
  cat $warnings | indent
  info "We're sorry this build is failing! If you can't find the issue in application code,"
  info "please submit a ticket so we can help: https://help.heroku.com/"
  info "You can also try reverting to our legacy Node.js buildpack:"
  info "heroku config:set BUILDPACK_URL=https://github.com/heroku/heroku-buildpack-nodejs#v63"
  info ""
  info "Love,"
  info "Heroku"
}

build_succeeded() {
  head "Build succeeded!"
  echo ""
  (npm ls --depth=0 || true) 2>/dev/null | indent
  cat $warnings | indent
}

# Sets:
# iojs_engine
# node_engine
# npm_engine
# environment variables (from ENV_DIR)

read_current_state() {
  info "package.json..."
  assert_json "$build_dir/package.json"
  iojs_engine=$(read_json "$build_dir/package.json" ".engines.iojs")
  node_engine=$(read_json "$build_dir/package.json" ".engines.node")
  npm_engine=$(read_json "$build_dir/package.json" ".engines.npm")

  info "environment variables..."
  export_env_dir $env_dir
  export NPM_CONFIG_PRODUCTION=${NPM_CONFIG_PRODUCTION:-true}
}

show_current_state() {
  echo ""
  if [ "$iojs_engine" == "" ]; then
    info "Node engine:         ${node_engine:-unspecified}"
  else
    achievement "iojs"
    info "Node engine:         $iojs_engine (iojs)"
  fi
  info "Npm engine:          ${npm_engine:-unspecified}"
  echo ""

  printenv | grep ^NPM_CONFIG_ | indent
}

install_node() {
  local node_engine=$1

  # Resolve non-specific node versions using semver.herokuapp.com
  if ! [[ "$node_engine" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    info "Resolving node version ${node_engine:-(latest stable)} via semver.io..."
    node_engine=$(curl --silent --get --data-urlencode "range=${node_engine}" https://semver.herokuapp.com/node/resolve)
  fi
  info "$node_engine"
  info `node --version`
  info `node --version 2>/dev/null`

  if [[ `node --version 2>/dev/null` == "$node_engine" ]]; then
    info "node `node --version` already installed"
  else
    # Download node from Heroku's S3 mirror of nodejs.org/dist
    info "Downloading and installing node $node_engine..."
    node_url="http://s3pository.heroku.com/node/v$node_engine/node-v$node_engine-linux-x64.tar.gz"
    curl $node_url -s -o - | tar xzf - -C /tmp

    # Move node (and npm) into .heroku/node and make them executable
    mv /tmp/node-v$node_engine-linux-x64/* $heroku_dir/node
    chmod +x $heroku_dir/node/bin/*
    PATH=$heroku_dir/node/bin:$PATH
  fi
}

install_iojs() {
  local iojs_engine=$1

  # Resolve non-specific iojs versions using semver.herokuapp.com
  if ! [[ "$iojs_engine" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    info "Resolving iojs version ${iojs_engine:-(latest stable)} via semver.io..."
    iojs_engine=$(curl --silent --get --data-urlencode "range=${iojs_engine}" https://semver.herokuapp.com/iojs/resolve)
  fi
  
  if [[ `iojs --version 2>/dev/null` == "$iojs_engine" ]]; then
    info "iojs `iojs --version` already installed"
  else
    # TODO: point at /dist once that's available
    info "Downloading and installing iojs $iojs_engine..."
    download_url="https://iojs.org/dist/v$iojs_engine/iojs-v$iojs_engine-linux-x64.tar.gz"
    curl $download_url -s -o - | tar xzf - -C /tmp

    # Move iojs/node (and npm) binaries into .heroku/node and make them executable
    mv /tmp/iojs-v$iojs_engine-linux-x64/* $heroku_dir/node
    chmod +x $heroku_dir/node/bin/*
    PATH=$heroku_dir/node/bin:$PATH
  fi
}

install_npm() {
  # Optionally bootstrap a different npm version
  if [ "$npm_engine" != "" ]; then
    if ! [[ "$npm_engine" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      info "Resolving npm version ${npm_engine} via semver.io..."
      npm_engine=$(curl --silent --get --data-urlencode "range=${npm_engine}" https://semver.herokuapp.com/npm/resolve)
    fi
    if [[ `npm --version` == "$npm_engine" ]]; then
      info "npm `npm --version` already installed with node"
    else
      info "Downloading and installing npm $npm_engine (replacing version `npm --version`)..."
      npm install --unsafe-perm --quiet -g npm@$npm_engine 2>&1 >/dev/null | indent
    fi
    warn_old_npm `npm --version`
  else
    info "Using default npm version: `npm --version`"
  fi
}

build_dev_dependencies() {
  local current_config=$NPM_CONFIG_PRODUCTION
  export NPM_CONFIG_PRODUCTION=false

  info "Installing any new modules"
  npm install --unsafe-perm --quiet --userconfig $build_dir/.npmrc 2>&1 | indent

  export NPM_CONFIG_PRODUCTION=$current_config
}

build_bower() {
  if [ -f $build_dir/bower.json ]; then
    # make sure that bower is installed locally
    info "Found bower.js, installing bower..."
    npm install bower --unsafe-perm --quiet --userconfig $build_dir/.npmrc 2>&1 | indent

    info "Running bower install task"
    if [ "$NPM_CONFIG_PRODUCTION" = true ]; then
      info "...with --production flag"
      $build_dir/node_modules/.bin/bower install --quiet --production | indent
    else
      $build_dir/node_modules/.bin/bower install --quiet | indent
    fi
  else
    info "No bower.js found"
  fi
}

build_grunt() {
  if [ -f $build_dir/Gruntfile.js ] || [ -f $build_dir/Gruntfile.coffee ]; then
    # make sure that grunt-cli is installed locally (grunt should be in devDependencies)
    info "Found Gruntfile, installing grunt-cli..."
    npm install grunt-cli --unsafe-perm --quiet --userconfig $build_dir/.npmrc 2>&1 | indent

    info "Running grunt heroku task"
    $build_dir/node_modules/.bin/grunt heroku | indent
  else
    info "No Gruntfile (Gruntfile.js, Gruntfile.coffee) found"
  fi
}

prune_dev_dependencies() {
  if [ "$NPM_CONFIG_PRODUCTION" = true ]; then
    info "Pruning dev dependencies"
    npm --unsafe-perm prune --production 2>&1 | indent
  fi
}

clean_npm() {
  info "Cleaning npm artifacts"
  rm -rf "$build_dir/.node-gyp"
  rm -rf "$build_dir/.npm"
}
