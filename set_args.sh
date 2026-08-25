#!/bin/sh

sed -i "s/registry/$NODE_NAME/g; s/test/$NODE_COOKIE/g" releases/0.0.1/vm.args

exec ./bin/registry console

