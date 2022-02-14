fmt:
	dart run import_sorter:main

lint:
	dart analyze
	dart run dart_code_metrics:metrics lib

test:
	dart test

build:
	dart compile exe bin/main.dart -o dartgit

# https://stackoverflow.com/a/26339924/147435
.PHONY: list test
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'
