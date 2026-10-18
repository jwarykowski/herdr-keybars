.PHONY: lint test check

lint:
	shellcheck -x bin/* lib/*.sh tests/*.sh

test:
	bash tests/watch_test.sh
	bash tests/github_test.sh
	bash tests/actions_test.sh
	bash tests/mcp_test.sh

check: lint test
