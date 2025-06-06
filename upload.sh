#!/usr/bin/env bash
git submodule update --remote --merge
hugo
git add .
git commit -m "update"
git push origin main
