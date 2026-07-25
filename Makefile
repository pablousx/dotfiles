.PHONY: check xxh-build

check:
	./tests/run.sh

xxh-build:
	./modules/xxh-plugin/build.sh
