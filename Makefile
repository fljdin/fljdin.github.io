
clean:
	rm -rf public/*

server:
	hugo server -D

build: clean
	hugo