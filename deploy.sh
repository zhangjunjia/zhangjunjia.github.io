#!/bin/bash

git add source/_posts/*
git commit -m "source changed"
git push -u origin origin

hexo g -d

