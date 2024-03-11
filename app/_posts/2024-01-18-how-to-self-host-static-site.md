---
title: How to Build and Self-Host a Static Website
date: 2024-02-13 00:59:00 +0000
categories: [Blogging]
tags: [self-hosting]
pin: true
---

This blog is (mostly) self-hosted at my home on an old Asus Chromebox running as a container in my local Kubernetes cluster. That being said, running a static website at home doesn’t require any fancy hardware, containers, or Kubernetes. You can run this off a tiny Raspberry Pi Zero, an old laptop, or even an old smartphone. If you don’t want to self-host, there are lots of hosting services like [Github pages](https://pages.github.com/), [Netlify](https://www.netlify.com/), [Heroku](https://www.heroku.com/) etc., where you can run your static site for free! However, in this guide, we dive a little deeper into self-hosting and explore various ways we can run a website at home. If you feel this is total overkill, you are probably right! 😉

## What is a static-website?

A static website is a type of website that displays fixed content to users. In contrast to dynamic websites, which generate content on the fly, static websites have pre-built content that remains the same for every user. The content is typically coded in HTML and may include stylesheets and JavaScript for presentation and interactivity. Static websites are great for blogs, resumes, portfolios or similar sites which don't need complex interactive features, backend databases, user logins etc. 

If you are not a front-end developer, it might be difficult to code, maintain and update static websites on your own. [Static Site Generators](https://www.cloudflare.com/learning/performance/static-site-generator/) (SSGs) are tools that automate the process of creating static websites. They take source files, often written in Markdown or a similar markup language, along with templates and other assets and generate a complete set of static HTML, CSS and JavaScript files.

Some of the popular SSGs include [Jekyll](https://jekyllrb.com/), [Hugo](https://gohugo.io/), [Gatsby](https://www.gatsbyjs.com/) and [Eleventy](https://www.11ty.dev/). We will use Jekyll for this guide since this blog was made using Jekyll with [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) theme.

## Prerequisites for this guide

- Ownership of a domain. Although it is possible to use a free subdomain using services like [DuckDNS](https://www.duckdns.org/), having a custom domain allows you to create a unique and memorable identity for your website.
- A Linux machine for building your site and hosting it. Preferably debian based, like [Ubuntu Server 22.04.3 LTS](https://releases.ubuntu.com/jammy/)
- Basic understanding of Linux and Networking.

## Building the Static Site

Jekyll has a pretty good [step-by-step tutorial](https://jekyllrb.com/docs/step-by-step/01-setup/) on how to build a basic website, however if you are looking for a stylized site with a minimal theme you are better off using any of the open source Jekyll themes from [jekyllthemes.org](http://jekyllthemes.org/). A typical Jekyll theme project directory structure includes:

- _config.yaml: This YAML file contains configuration settings for the Jekyll site, including site metadata, settings for plugins and other global configurations.
- _includes: This directory contains snippets of reusable code that can be included in layouts and posts using [Liquid](https://jekyllrb.com/docs/liquid/) tags. This helps in modularizing the code.
- _layouts: This directory holds the templates for different layouts used across the site. Layouts define the overall structure of pages and content can be injected into these layouts.
- _posts: This directory is used to store blog posts. Posts are written in Markdown or HTML and follow a specific naming convention (YYYY-MM-DD-title.md) to determine the publication date.
- _data: Since Jekyll doesn't use a database, this folder can contain files (YAML, JSON, CSV or TSV) with structured data that can be used in the site. Data files can be accessed within templates to populate content dynamically.
- index.md (or index.html): The main entry point of the site, where the homepage content is defined. The index.md file is automatically used as the homepage unless configured otherwise.

You can read more about the Jekyll directory structure in the official [documentation](https://jekyllrb.com/docs/structure/).

Most of the themes you see at [jekyllthemes.org](http://jekyllthemes.org/) would have the above directory structure. 

1. On your Linux machine, install Jekyll. 
```bash
# Prerequisites
sudo apt install ruby-full build-essential zlib1g-dev
# Setup gems path
echo '# Install Ruby Gems to ~/gems' >> ~/.bashrc
echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc
echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
# Install Jekyll and Bundler
gem install jekyll bundler
```
2. Clone the theme project to your linux machine, we use Chirpy theme for this guide:
```bash
git clone https://github.com/cotes2020/jekyll-theme-chirpy.git
cd jekyll-theme-chirpy
```
3. Update the `_config.yml` file with your site details.
4. If you have chosen a blog theme, add a post in the `_posts` directory.
5. If you have custom images, icons or stylesheets, update the `assets` directory.
6. Additionally, read the theme documentation and update any other files as necessary.
7. Once you are done, it is time to install the dependencies and build the site. Run below commands from the root directory of your site.
```bash
# Install dependencies.
bundle install
# Build and serve the site
bundle exec jekyll serve --host 0.0.0.0 --port 9000 --incremental
```
8. Your site files will be generated in the _site directory and you can browse it at `http://localhost:9000`.
9. If required, you can now make modifications to your site and view the preview in your browser.
10. Once you are done editing your site , you can run below command to create a final build in the `_site` directory.
```bash
JEKYLL_ENV=production bundle exec jekyll build
```

## Serving the Static Site using a Web Server

A web server is software that serves as the foundation for delivering web content over the network. It handles incoming requests from clients (such as web browsers), processes these requests and sends back the appropriate responses, typically in the form of HTML pages, images or other resources. Web servers generally use HTTP protocol to facilitate communication between clients and servers. Examples of web servers include Apache, Nginx, Microsoft Internet Information Services (IIS) etc.

Since we are serving a static website, we just need a light-weight performance oriented web server and Nginx is one of the best and battle-tested choice. Let us install Nginx on a machine which you want to use as your *server*.

The installation steps differ based on your operating system, for this guide we use [Ubuntu Server 22.04.3 LTS](https://releases.ubuntu.com/jammy/). Please refer the Nginx [documentation](https://www.nginx.com/resources/wiki/start/topics/tutorials/install/) for other operating systems.

1. Install Nginx.
```bash
sudo apt update
sudo apt install nginx
sudo systemctl start nginx
```
2. Your Nginx web server should be now running at `http://localhost` and should give you a default welcome page.
3. Copy your static site contents from `_site` directory to `/usr/share/nginx/html/`, replacing the existing files in the destination directory. Your `/usr/share/nginx/html/` directory should now look like:
```
/usr/share/nginx/html
├── 404.html
├── about
├── app.js
├── archives
├── assets
├── categories
├── feed.xml
├── index.html
├── norobots
├── posts
├── redirects.json
├── robots.txt
├── sitemap.xml
├── sw.js
├── tags
└── unregister.js
```
4. Nginx will now serve your static site at `http://localhost`.

## Exposing the Static Site to Internet

Once your website is production ready, it is time to publish it to the internet. The easiest way to do this is by doing a [port-forward](https://portforward.com/) of your web server port and then accessing your website via your public IP or a domain mapped to your public IP. However, if you are planning to self-host at home, it is not a good idea to expose your home server to the internet as it can increase the risk of security vulnerabilities and potential attacks, unless you have good security infrastructure. Additionally, some ISPs use [CGNAT](https://en.wikipedia.org/wiki/Carrier-grade_NAT) and port-forwarding might not even work on such networks. Let us look at some of the other options:

- Creating a [Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/) to your web-server and allowing Cloudflare to act as a reverse-proxy.
- Creating a simple SSH reverse tunnel to a remote cloud instance which acts as a reverse-proxy.
- Creating a self managed WireGuard VPN tunnel to a remote cloud instance which acts as a reverse-proxy.
- Using AWS or other public cloud platforms to act as a front-end or Web Application Firewall.

For this guide, we use Cloudflare Tunnels due to its simplicity and ease of use. Cloudflare is an industry leader in Content Delivery Network, DDoS Protection and Website Performance Optimization. Cloudflare Tunnels allows you to create a free tunnel to expose your websites via Cloudflare's proxy which hides your public IP, provides free SSL certificate, enables DDoS protection, caching, Firewall, Email routing and much more! However, please keep in mind that Clouflare can technically inspect your traffic even if you use SSL/TLS as they intercept SSL communication using their own certificate. Since we are hosting a static website, it shouldn't matter to us since there is no user login or data transfer to the server. Let us get stared with Cloudflare Tunnel.

1. Sign up for a [Cloudflare account](https://dash.cloudflare.com/sign-up).
2. From your Cloudflare Dashboard, select Websites → Add a site → and enter your domain name:
![Cloudflare add site](/assets/img/2024-01-18-how-to-self-host-static-site/cloudflare_add_site.png)
3. Select the free plan and click on next.
4. If your domain is registered via Cloudflare, you don't have to update your nameservers, otherwise update your nameservers as shown by Cloudflare. You might need to check your registrar's documentation for this. More info [here](https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/).
5. Once your nameservers are updated, the sites should show as active in Cloudflare dashboard.
6. Install `cloudflared` on your web server.
```bash
# Add cloudflare gpg key
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
# Add this repo to your apt repositories
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared jammy main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
# install cloudflared
sudo apt update
sudo apt install cloudflared
```
7. Create the tunnel.
```bash
# Switch to root
sudo su -
# Login to Cloudflare
# This should open a browser, login with your username and password, and select the site which you just added.
cloudflared tunnel login
# Create tunnel
cloudflared tunnel create <Tunnel-Name>
# Note your tunnel UUID
```
8. Create a configuration file `config.yaml` in your `$HOME/.cloudflared` directory with below content (update paths and UUID):
```yaml
url: http://localhost:80 
tunnel: <Tunnel-UUID>
credentials-file: /root/.cloudflared/<Tunnel-UUID>.json
```
9. Start routing traffic.
```bash
cloudflared tunnel route dns <Tunnel-Name> <Domain-Name>
```
10. Install cloudflared as a service.
```bash
cloudflared service install
systemctl start cloudflared
systemctl status cloudflared
```
11. If the configuration is correct, your static site should be now exposed to the internet via your domain name.

To troubleshoot your tunnel, check the logs using the command `journalctl -u cloudflared.service` for any issues.

That will be it for this guide. Congratulations on self-hosting your static website! 🚀\
Stay tuned for similar guides. Thank you!
