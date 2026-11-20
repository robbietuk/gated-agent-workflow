.PHONY: ci docs

# All checks: hook self-test, session-start, installer, manifests and versions, claude plugin validate.
ci:
	bash tools/ci.sh

# Rebuild docs/guide and docs/slides from their sources.
docs:
	python3 tools/build_docs.py
