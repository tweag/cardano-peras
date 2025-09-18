#!/usr/bin/env bash

NODE=node1

grep -Po "(?<=Serving files at: )(.*)" "testnet/logs/$NODE/stdout.log" | \
  xargs xdg-open
