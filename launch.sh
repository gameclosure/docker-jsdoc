#!/bin/bash
set -e

## REQUIREMENTS ##
if [ -z "$GIT_REMOTE" ]; then
  echo "GIT_REMOTE is unset"
  exit 1
fi
if [ -z "$GIT_REF" ]; then
  echo "GIT_REF is unset"
  exit 1
fi
## ##

## OPTIONAL ##
if [ -z "$CONFIG_FILE" ]; then
  CONFIG_FILE="conf.json"
fi

OPTIONAL_ARGS=""
if [ "$TEMPLATE_DIR" ]; then
  OPTIONAL_ARGS="-t $TEMPLATE_DIR"
fi
## ##

INPUT_DIR="/remote-app"
OUTPUT_DIR="/doc-output"

# If the directory exists, make sure we reset it
if [ -d "$INPUT_DIR" ] && [ -d "$INPUT_DIR/.git" ]; then
  (
    echo "*** git reset and fetch"
    cd $INPUT_DIR
    git reset --hard
    git fetch
  )
else
  # Clone the repo
  echo "*** git clone $GIT_REMOTE"
  git clone $GIT_REMOTE $INPUT_DIR
fi

# Checkout the proper ref
(
  echo "*** git checkout $GIT_REF and pull"
  cd $INPUT_DIR
  git checkout $GIT_REF
  git pull
)

# Check for a package.json and try to run npm install
PACKAGE_JSON="$INPUT_DIR/package.json"
if [ -f "$PACKAGE_JSON" ]; then
  echo "*** package.json discovered, trying npm install"
  (
    # no errors, in case package.json is bogus
    set +e
    cd $INPUT_DIR
    npm install
    set -e
  )
fi

# Time to run the docs
(
  echo "*** running docs"
  cd /jsio-preprocess

  # Check for presence of conf file
  CONF="$INPUT_DIR/$CONFIG_FILE"
  if [ -f "$CONF" ]; then
    OPTIONAL_ARGS="$OPTIONAL_ARGS -c $CONF"
  fi

  # Try to grab a remote name to use as the fallback app name - lol awk
  REMOTE_NAME=`cd $INPUT_DIR && git remote -v | awk '{print $2}' | awk -F "/" 'NR==1{print $(NF)}'`
  if [ ! -z "$REMOTE_NAME" ]; then
    OPTIONAL_ARGS="$OPTIONAL_ARGS -n $REMOTE_NAME"
  fi

  # Run jsdoc
  ./node_modules/gulp/bin/gulp.js \
    -s $INPUT_DIR \
    -d $OUTPUT_DIR \
    $OPTIONAL_ARGS

  # Upload!
  # TODO: at some point in time, the upload should happen from a secure location
  # ./node_modules/gulp/bin/gulp.js \
  #   -d $OUTPUT_DIR \
  #   upload
)

# Complete
ls $OUTPUT_DIR
