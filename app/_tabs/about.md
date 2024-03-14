---
# the default layout is 'page'
icon: fas fa-info-circle
order: 4
---
{% capture start_year %}2015{% endcapture %}
{% capture current_year %}{{ "now" | date: "%Y" }}{% endcapture %}

Hey there! I’m Suraj, a Senior DevOps Engineer with over {{ current_year | minus: start_year }} years of experience in IT, specializing in Kubernetes, Docker, Terraform, Configuration Management, CI/CD, Automation and Observability in both conventional and cloud-native environments. I’ve worked with a diverse set of global clients, including international banks, telecommunication companies, retail businesses and financial services.

I enjoy self-hosting, and this blog is a platform to share what I’ve learned while building my home server, the DevOps practices I follow, the [source code](https://github.com/c0depool/c0depool-blog) of my setups, and much more. Since this blog is self-hosted at my home, if you ever encounter a `503` status code, please assume that my ISP has decided to shut down my internet for some reason, or my kid has unplugged some random cable from the server - a refurbished Asus Chromebox! I hope you find something useful here. 🙂

You can reach out to me at [{{ site.social.email }}](mailto:{{ site.social.email }}).