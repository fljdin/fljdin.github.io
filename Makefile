
clean:
	rm -rf public/*

server:
	hugo server -D

build: clean
	HUGO_DISABLELANGUAGES="en" hugo