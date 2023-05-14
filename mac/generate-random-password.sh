#!/bin/bash

# Generate a random password
RANDOM_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*()_-+=' | fold -w 16 | head -n 1)

echo "Random MySQL password: $RANDOM_PASSWORD"
