#!/bin/sh

docker run --rm -d -v /tmp/.X11-unix:/tmp/.X11-unix -v ~/.Xauthority:/home/inferno/.Xauthority -v $HOME:$HOME -e DISPLAY caerwyn/acme-sac:alpine-arm-slim
