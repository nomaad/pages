
#blogdown::new_site(theme = 'gcushen/hugo-academic')

# https://web.archive.org/web/20190622040330/https://sourcethemes.com/academic/docs/get-started/

rm(list=ls())

options(blogdown.knit.on_save = FALSE)
options(blogdown.knit.serve_site = FALSE)

blogdown::build_site()
blogdown::serve_site()

blogdown::stop_server()


