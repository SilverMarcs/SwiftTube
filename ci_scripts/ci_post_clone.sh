#!/bin/sh
# 2026-07-03: builds 1-8 already exist in ASC (8 was uploaded manually while the
# Xcode Cloud run counter was at 4), so offset the counter to keep CFBundleVersion
# strictly increasing — otherwise uploads fail with ITMS-90061.
set -e
BUILD_NUMBER=$((CI_BUILD_NUMBER + 5))
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcrun agvtool new-version -all "$BUILD_NUMBER"
echo "Set build number to $BUILD_NUMBER (CI_BUILD_NUMBER=$CI_BUILD_NUMBER + 5)"
