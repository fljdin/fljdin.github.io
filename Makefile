BIND=localhost
ifeq ($(PUBLIC),1)
	BIND=$(shell hostname)
endif

clean:
	rm -rf public/*

server:
	hugo server --bind $(BIND) --baseURL "http://$(BIND)" -D

build: clean
	HUGO_DISABLELANGUAGES="en" hugo
