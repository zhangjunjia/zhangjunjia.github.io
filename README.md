# zhangjunjia

0. install node.js & npm
1. npm install hexo-cli -g && npm install
2. curl -s https://api.github.com/repos/iissnan/hexo-theme-next/releases/latest | grep tarball_url | cut -d '"' -f 4 | wget -i - -O- | tar -zx -C themes/next --strip-components=1
3. restore themes_next_config.yml
4. hexo generate server
5. hexo new post title

