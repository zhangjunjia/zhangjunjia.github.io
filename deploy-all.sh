#!/bin/bash

git add source/*
git commit -m "source changed"
git push -u origin origin

hexo g -d

