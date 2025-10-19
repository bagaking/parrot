
export CODEX_HOME := $(PWD)/.codex

.PHONY: codex codex_home cc_codex validate

init:
	specify init . --ai codex

codex_home:
	@echo "CODEX_HOME=$(CODEX_HOME)"

codex: codex_home
	@echo "Running codex with CODEX_HOME=$(CODEX_HOME)"
	codex --dangerously-bypass-approvals-and-sandbox

cc_codex: codex_home
	@echo "Running codex with CODEX_HOME=$(CODEX_HOME)"
	ccmodel --env CODEX_HOME=$(CODEX_HOME) exec run codex -- --dangerously-bypass-approvals-and-sandbox

validate:
	ruby tools/validate_specs.rb
