.PHONY: deploy update logs ps down restart validate

deploy:
	./scripts/deploy.sh

update:
	./scripts/update.sh

logs:
	docker compose logs -f --tail=200

ps:
	docker compose ps

down:
	docker compose down

restart:
	docker compose restart

validate:
	docker compose config >/dev/null

