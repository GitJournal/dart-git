#!/usr/bin/env bash
# This is supposed to run on the CI

set -eux

dart pub global activate coverage
dart test --coverage="coverage"
format_coverage --lcov --in=coverage --out=coverage.lcov --packages=.packages --report-on=lib

sudo apt-get install -y lcov
genhtml coverage.lcov -o coverage_html
