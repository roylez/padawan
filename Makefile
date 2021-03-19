export hostname := $(shell hostname)
export app=padawan

.PHONY: iex chat
chat: export PADAWAN_CHAT_ADAPTER=console

chat iex:
	iex --name ${app}@${hostname}.local -S mix

.PHONY: docker
docker:
	docker build -t ${app} .
