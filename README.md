# zhangjunjia

1. npm install hexo-cli -g
2. curl -s https://api.github.com/repos/iissnan/hexo-theme-next/releases/latest | grep tarball_url | cut -d '"' -f 4 | wget -i - -O- | tar -zx -C themes/next --strip-components=1
3. hexo generate server
4. hexo new post title

