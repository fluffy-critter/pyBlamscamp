all: setup version format mypy pylint

.PHONY: setup
setup:
	poetry install

.PHONY: format
format:
	poetry run isort .
	poetry run autopep8 -r --in-place .

.PHONY: test
test:
	# this really should be done using pytest but ugh
	rm -rf test_output
	mkdir -p test_output/album/mp3/dir_should_be_removed
	touch test_output/album/mp3/extraneous-file.txt
	touch test_output/album/mp3/dir_should_be_removed/extraneous-file.txt
	poetry run blamscamp tests/album test_output/album
	poetry run blamscamp --init tests/derived test_output/derived --json derived.json

.PHONY: pylint
pylint:
	poetry run pylint blamscamp

.PHONY: mypy
mypy:
	poetry run mypy -p blamscamp --ignore-missing-imports

.PHONY: preflight
preflight:
	@echo "Checking commit status..."
	@git status --porcelain | grep -q . \
		&& echo "You have uncommitted changes" 1>&2 \
		&& exit 1 || exit 0
	@echo "Checking branch..."
	@[ "$(shell git rev-parse --abbrev-ref HEAD)" != "main" ] \
		&& echo "Can only build from main" 1>&2 \
		&& exit 1 || exit 0
	@echo "Checking upstream..."
	@git fetch \
		&& [ "$(shell git rev-parse main)" != "$(shell git rev-parse main@{upstream})" ] \
		&& echo "main branch differs from upstream" 1>&2 \
		&& exit 1 || exit 0

.PHONY: version
version: blamscamp/__version__.py
blamscamp/__version__.py: pyproject.toml
	# Kind of a hacky way to get the version updated, until the poetry folks
	# settle on a better approach
	printf '""" version """\n__version__ = "%s"\n' \
		`poetry version | cut -f2 -d\ ` > blamscamp/__version__.py

.PHONY: build
build: version preflight pylint
	poetry build

.PHONY: clean
clean:
	rm -rf dist .mypy_cache .pytest_cache .coverage
	find . -name __pycache__ -print0 | xargs -0 rm -r

.PHONY: upload
upload: clean test build
	poetry publish
