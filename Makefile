
clean:
	rm -rf public/*

server:
	hugo server --bind $(shell hostname) --baseURL "http://$(shell hostname)" -D

build: clean
	HUGO_DISABLELANGUAGES="en" hugo