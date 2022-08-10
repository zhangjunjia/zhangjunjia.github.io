#!/bin/bash

git add source/_posts/*
git add *json
git add *yml
git add *md
git add *sh
git add .gitignore
git add themes/*
git commit -m "source changed"
git push -u origin origin
#hexo g -d

