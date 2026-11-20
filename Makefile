.PHONY: ci docs release

# All checks: hook self-test, session-start, installer, manifests and versions, claude plugin validate.
ci:
	bash tools/ci.sh

# Rebuild docs/guide and docs/slides from their sources.
docs:
	python3 tools/build_docs.py

# Set a new version everywhere it is recorded and run the checks: make release VERSION=1.2.0
release:
	bash tools/release.sh $(VERSION)
