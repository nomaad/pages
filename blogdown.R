
# install.packages("tidyverse")

# blogdown::install_hugo()
# blogdown::hugo_version()
# options(blogdown.hugo.version = "0.147.9" )

blogdown::build_site(build_rmd = 'newfile')
blogdown::serve_site()
blogdown::stop_server()

blogdown::check_site()