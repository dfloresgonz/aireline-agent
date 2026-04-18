.PHONY: deploy destroy seed alexa

deploy:
	@bash scripts/deploy.sh

destroy:
	@bash scripts/destroy.sh

seed:
	@bash scripts/seed-kb.sh

alexa:
	@bash scripts/deploy-alexa.sh
