.PHONY: deploy destroy seed

deploy:
	@bash scripts/deploy.sh

destroy:
	@bash scripts/destroy.sh

seed:
	@bash scripts/seed-kb.sh
