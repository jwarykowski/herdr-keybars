.PHONY: lint test check

lint:
	shellcheck bin/watch bin/next-agent tests/*.sh

test:
	bash tests/watch_test.sh

check: lint test
