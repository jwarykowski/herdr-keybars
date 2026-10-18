.PHONY: lint test check

lint:
	shellcheck bin/watch bin/next-agent bin/bridge bin/setup bin/focus tests/*.sh

test:
	bash tests/watch_test.sh
	bash tests/bridge_test.sh

check: lint test
