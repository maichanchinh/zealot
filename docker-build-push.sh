#!/bin/bash

# Đặt biến version
version="6.1.1"

# Build Docker image
docker build -t zealot:$version -t 192.168.1.59:5000/zealot:$version -t 192.168.1.59:5000/zealot:latest .

# Push Docker image
docker push 192.168.1.59:5000/zealot:latest
docker push 192.168.1.59:5000/zealot:$version
