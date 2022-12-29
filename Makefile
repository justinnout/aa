.PHONY: build
build:
	nile compile

.PHONY: test
test:
	pytest tests/*