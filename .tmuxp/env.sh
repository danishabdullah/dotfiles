#! /bin/bash
source /Users/danish/anaconda/bin/activate webfrontend
export FLASK_ENV=DEBUG
export DB_PORT=tcp://localhost:5432 
export RABBITMQ_PORT=tcp://localhost:5672