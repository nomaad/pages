library(quanteda)
library(quanteda.dictionaries)
library(readtext)
library(ggplot2)
library(tidyverse)
library(tidytext)
library(topicmodels)
library(stringr)

setwd("~/OneDrive - Universität Basel/Bücher/MEW/Kapital")

kapital <- readtext("*.pdf", docvarsfrom = "filenames")
kapital
docvars(kapital)

# clean
kapital$text <- gsub("\n", " ", kapital$text)

# create corpus
kapital_corp <- corpus(kapital)
corp_summary <- summary(kapital_corp)

docvars(kapital_corp, "ID") <- c("Band 1", "Band 2", "Band 3")
docvars(kapital_corp)

# keywords in context
kwictexts <- kwic(kapital_corp, "Produktionsverhältnisse")
head(kwictexts)

# create dfm
dfm <- dfm(kapital_corp, 
           remove = c(stopwords("german"), stopwords("english"), LETTERS, letters, 
                      c("usw", "daher", "de", "i.e", "ver-", "pfd", "ä", "ö", "ü", "z.b", "pfd.st", "st", "ver", "ii")), 
           stem = F,
           tolower=T,
           what = "word",
           remove_punct = T,
           remove_symbols = T,
           remove_numbers = T,
           remove_url = T,
           remove_separators = T,)


topfeatures(dfm, n = 50)

# two most frequent features? Kapital und Arbeit of course?
freq <- textstat_frequency(dfm, n = 2)
ggplot(freq, aes(x = reorder(feature, frequency), y = frequency)) + 
  geom_point() +
  coord_flip() +
  labs(x = NULL, y = "Frequency", title = "Two most frequent words in Marx's Capital(1-3)") +
  theme_bw()

# 20 most frequent? capital dominates!
freq <- textstat_frequency(dfm, n = 20)
ggplot(freq, aes(x = reorder(feature, frequency), y = frequency)) + 
  geom_point() +
  coord_flip() +
  labs(x = NULL, y = "Frequency", title = "Most frequent words in Marx's Capital(1-3)") +
  theme_bw()

# 10 most frequent per book
freq <- textstat_frequency(dfm, n = 15, group = "ID")
ggplot(freq, aes(x = reorder_within(feature, frequency, group), y = frequency)) + 
  geom_point() +
  coord_flip() + 
  facet_grid(group~., scales = "free") +
  scale_x_reordered() +
  labs(x = NULL, y = "Frequency", title = "Most frequent words per Book in Marx's Capital(1-3)") +
  theme_bw()

# wordcloud
textplot_wordcloud(dfm, min.freq=20, random.order = FALSE, rot.per = .25,
                   colors = RColorBrewer::brewer.pal(8,"Dark2"))

# sentiment analysis
dfm_senti <- dfm(kapital_corp, dictionary = data_dictionary_sentiws)
dfm_senti # yes, positive books! no polemics found.

# topic modelling
# set to a fixed number of 6 topics
lda <-LDA(dfm, k = 4, method="Gibbs", 
             control = list(seed = 1234, verbose=50))
wp <- tidy(lda, matrix = "beta")
wp_terms <- wp %>%
  group_by(topic) %>%
  top_n(10, beta) %>%
  ungroup() %>%
  arrange(topic,-beta)
# plot most common words per topic
ggplot(wp_terms, aes(reorder_within(term, beta, topic), beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free") +
  coord_flip() +
  scale_x_reordered() +
  labs(x = "term", title = "Most common words") + theme_bw()


# ------------------------ ADORNO ------------------------------------

# load
setwd("~/OneDrive - Universität Basel/Bücher/Adorno GS/")
adorno <- readtext("*.txt", docvarsfrom = "filenames")
adorno$text <- gsub("\n", " ", adorno$text)
adorno_corp <- corpus(adorno)

# create dfm
dfm <- dfm(adorno_corp, 
           remove = c(stopwords("german"), stopwords("english"),c("minima", "moralia", "soziologische", "schriften"), LETTERS, letters), 
           stem = T,
           tolower=T,
           what = "word",
           remove_punct = T,
           remove_symbols = T,
           remove_numbers = T,
           remove_url = T,
           remove_separators = T,)

# topfeatures?
topfeatures(dfm, n = 50)

# most frequent features?
freq <- textstat_frequency(dfm_subset(dfm, docvar1=="Band 3"), n = 20)
ggplot(freq, aes(x = reorder(feature, frequency), y = frequency)) + 
  geom_point() +
  coord_flip() +
  labs(x = NULL, y = "Worthäufigkeit") +
  theme_bw()
freq <- textstat_frequency(dfm_subset(dfm, docvar1=="Band 8"), n = 20)
ggplot(freq, aes(x = reorder(feature, frequency), y = frequency)) + 
  geom_point() +
  coord_flip() +
  labs(x = NULL, y = "Worthäufigkeit" ) +
  theme_bw()

# Hapax legomenon
library("spacyr")
spacy_initialize(model = "de")
txt <- readtext("Band 3_Dialektik der Aufklärung. Philosophische Fragmente.txt", docvarsfrom = "filenames")
txtparsed <- spacy_parse(txt, tag = TRUE, pos = TRUE)
nouns <- with(txtparsed, subset(token, pos == "NOUN"))
propernouns <- with(txtparsed, subset(token, pos == "PROPN"))

dda_dfm <- dfm_subset(dfm, docvar1=="Band 3")
freq <- textstat_frequency(dfm_select(dda_dfm, pattern = nouns))
hapax <- freq %>% filter(frequency == 1)
sample(hapax$feature,10)


tstat_lexdiv <- textstat_lexdiv(dda_dfm, measure="S")
tail(tstat_lexdiv, 5)

# wordcloud
textplot_wordcloud(dfm_subset(dfm, docvar1=="Band 3"), min.freq=20, random.order = FALSE, rot.per = .25,
                   colors = RColorBrewer::brewer.pal(8,"Dark2"))

# topic modelling
# set to a fixed number of topics
lda <-LDA(dfm_subset(dfm, docvar1=="Band 3"), k = 3, method="Gibbs", 
          control = list(seed = 1234, verbose=50))

wp <- tidy(lda, matrix = "beta")
wp_terms <- wp %>%
  group_by(topic) %>%
  top_n(10, beta) %>%
  ungroup() %>%
  arrange(topic,-beta)
# plot most common words per topic
ggplot(wp_terms, aes(reorder_within(term, beta, topic), beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free") +
  coord_flip() +
  scale_x_reordered() +
  labs(x = "term", title = "Most common words") + theme_bw()

# sentiment analysis
dfm_senti <- dfm(adorno_corp, dictionary = data_dictionary_sentiws)
dfm_senti # 
