#!/bin/bash

git add *
git commit -m "source changed"
git push -u origin origin

hexo g -d

