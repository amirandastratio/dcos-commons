#!/bin/bash

set -e

CLEANUP_PATH=`pwd`
VERSION="0.12.0"

cleanup() {
    debug "Cleaning up"
    rm -rf $CLEANUP_PATH/template.zip
}

trap cleanup INT TERM

error_msg() {
    echo "---"
    echo "Failed to generate the project: Exited early at $0:L$1"
    echo "To try again, re-run this script."
    echo "---"
}
trap 'error_msg ${LINENO}' ERR

info() {
    echo $1
}

debug() {
    if [[ -z "${DEBUG// }" ]]; then
        return
    fi
    echo "DEBUG: $1"
}

PROJECT_NAME=$1
PROJECT_PATH=$2

if [[ -z "${PROJECT_NAME// }" ]]; then
    echo "You must provide the name of the project as the first argument"
    echo "Usage: ./new-standalone-service.sh project-name"
    echo "Example: ./new-standalone-service.sh kafka"
    cleanup
    exit 1
fi

if [[ -z "${PROJECT_PATH// }" ]]; then
    PROJECT_PATH=$(pwd)
fi

debug "Scaffolding $PROJECT_NAME from template"

cp -R frameworks/template $PROJECT_PATH/$PROJECT_NAME
cp -R tools $PROJECT_PATH/$PROJECT_NAME/tools
cp ./.gitignore $PROJECT_PATH/$PROJECT_NAME
rm -rf $PROJECT_PATH/$PROJECT_NAME/build
rm -rf $PROJECT_PATH/$PROJECT_NAME/cli/dcos-*/*.whl
rm -rf $PROJECT_PATH/$PROJECT_NAME/cli/dcos-*/dcos-*
rm -rf $PROJECT_PATH/$PROJECT_NAME/cli/python/{build,dist}
rm -rf $PROJECT_PATH/$PROJECT_NAME/build.sh

cat > $PROJECT_PATH/$PROJECT_NAME/build.sh <<'EOF'
#!/bin/bash
set -e

# capture anonymous metrics for reporting
curl https://mesosphere.com/wp-content/themes/mesosphere/library/images/assets/sdk/build-sh-start.png >/dev/null 2>&1

FRAMEWORK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR=$FRAMEWORK_DIR/build/distributions
PUBLISH_STEP=${1-none}
export REPO_NAME="$(basename $FRAMEWORK_DIR)"
export BUILD_BOOTSTRAP=no
export TOOLS_DIR=${FRAMEWORK_DIR}/tools
export CLI_DIR=${FRAMEWORK_DIR}/cli
export ORG_PATH=github.com/$REPO_NAME
${FRAMEWORK_DIR}/tools/build_framework.sh $PUBLISH_STEP $REPO_NAME $FRAMEWORK_DIR $BUILD_DIR/$REPO_NAME-scheduler.zip

# capture anonymous metrics for reporting
curl https://mesosphere.com/wp-content/themes/mesosphere/library/images/assets/sdk/build-sh-finish.png >/dev/null 2>&1
EOF

chmod +x $PROJECT_PATH/$PROJECT_NAME/build.sh
mv $PROJECT_PATH/$PROJECT_NAME/cli/dcos-template $PROJECT_PATH/$PROJECT_NAME/cli/dcos-$PROJECT_NAME
mv $PROJECT_PATH/$PROJECT_NAME/src/main/java/com/mesosphere/sdk/template/ $PROJECT_PATH/$PROJECT_NAME/src/main/java/com/mesosphere/sdk/$PROJECT_NAME/
mv $PROJECT_PATH/$PROJECT_NAME/src/test/java/com/mesosphere/sdk/template/ $PROJECT_PATH/$PROJECT_NAME/src/test/java/com/mesosphere/sdk/$PROJECT_NAME/

UPPER_CASE_PROJECT_NAME=$(echo $PROJECT_NAME | awk '{print toupper($0)}')

find $PROJECT_PATH/$PROJECT_NAME -type f -exec sed -i.bak "s/template/$PROJECT_NAME/g; s/TEMPLATE/$UPPER_CASE_PROJECT_NAME/g; s/template/$PROJECT_NAME/g" {} \;
sed -i.bak -e '21,$ d' $PROJECT_PATH/$PROJECT_NAME/src/main/dist/svc.yml
find $PROJECT_PATH/$PROJECT_NAME -type f -name *.bak -exec rm -f {} \;

sed -i.bak "s/compile project(\":scheduler\")/compile \"mesosphere:scheduler:$VERSION\"/g" $PROJECT_PATH/$PROJECT_NAME/build.gradle
sed -i.bak "s/compile project(\":executor\")/compile \"mesosphere:executor:$VERSION\"/g" $PROJECT_PATH/$PROJECT_NAME/build.gradle
sed -i.bak "s/testCompile project(\":testing\")/testCompile \"mesosphere:testing:$VERSION\"/g" $PROJECT_PATH/$PROJECT_NAME/build.gradle
sed -i.bak '/distZip.dependsOn ":executor:distZip"/d' $PROJECT_PATH/$PROJECT_NAME/build.gradle
sed -i.bak '/distZip.finalizedBy copyExecutor/d' $PROJECT_PATH/$PROJECT_NAME/build.gradle
rm -f $PROJECT_PATH/$PROJECT_NAME/build.gradle.bak

GRADLEW=$(pwd)/gradlew

pushd $PROJECT_PATH/$PROJECT_NAME
$GRADLEW wrapper --gradle-version 3.4.1
popd

echo "New project created successfully"