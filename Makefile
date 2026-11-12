.PHONY: all help init download import up start down stop restart status logs test purge-cache update reset

all: help

help:
	@./makina

init:
	@./makina init

download:
	@./makina download $(AREA)

import:
	@./makina import $(FILE)

up start:
	@./makina start

down stop:
	@./makina stop

restart:
	@./makina restart

status ps:
	@./makina status

logs:
	@./makina logs $(SERVICE)

test:
	@./makina test

purge-cache:
	@./makina purge-cache

update:
	@./makina update

reset:
	@./makina reset
