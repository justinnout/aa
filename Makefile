.PHONY: build
build:
	nile compile

.PHONY: test
test:
	pytest tests/test_contract.py