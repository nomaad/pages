---
title: "Automatisierte Inhaltsanalyse & Kategorisierung von QAnon-Tweets"
summary: "Die COVID-19-Pandemie führte zu einer ansteigenden Verbreitung der rechtsextremen Verschwörungstheorie QAnon. In diesem Beitrag wird dies anhand von Twitterdaten empirisch überprüft. Zusätzlich wird mit einer nonparametrischen, automatisierten Inhaltsanalyse  (readme2) eingeschätzt, wieviele der Tweets sich  affirmativ bzw. kritisch auf QAnon beziehen."
author: "Matthias Zaugg"
date: "2020-08-18"
#categories: ["Tech"]
tags: ["Autoritärer Charakter", "Quantitative Textanalyse", "Rechtsextremismus"]
output: html_document
reading_time: FALSE
---

<link href="{{< blogdown/postref >}}index_files/htmltools-fill/fill.css" rel="stylesheet" />
<script src="{{< blogdown/postref >}}index_files/htmlwidgets/htmlwidgets.js"></script>

<script src="{{< blogdown/postref >}}index_files/plotly-binding/plotly.js"></script>

<script src="{{< blogdown/postref >}}index_files/typedarray/typedarray.min.js"></script>

<script src="{{< blogdown/postref >}}index_files/jquery/jquery.min.js"></script>

<link href="{{< blogdown/postref >}}index_files/crosstalk/css/crosstalk.min.css" rel="stylesheet" />
<script src="{{< blogdown/postref >}}index_files/crosstalk/js/crosstalk.min.js"></script>

<link href="{{< blogdown/postref >}}index_files/plotly-htmlwidgets-css/plotly-htmlwidgets.css" rel="stylesheet" />
<script src="{{< blogdown/postref >}}index_files/plotly-main/plotly-latest.min.js"></script>

<link href="{{< blogdown/postref >}}index_files/htmltools-fill/fill.css" rel="stylesheet" />
<script src="{{< blogdown/postref >}}index_files/htmlwidgets/htmlwidgets.js"></script>

<script src="{{< blogdown/postref >}}index_files/plotly-binding/plotly.js"></script>

<script src="{{< blogdown/postref >}}index_files/typedarray/typedarray.min.js"></script>

<script src="{{< blogdown/postref >}}index_files/jquery/jquery.min.js"></script>

<link href="{{< blogdown/postref >}}index_files/crosstalk/css/crosstalk.min.css" rel="stylesheet" />
<script src="{{< blogdown/postref >}}index_files/crosstalk/js/crosstalk.min.js"></script>

<link href="{{< blogdown/postref >}}index_files/plotly-htmlwidgets-css/plotly-htmlwidgets.css" rel="stylesheet" />
<script src="{{< blogdown/postref >}}index_files/plotly-main/plotly-latest.min.js"></script>

Die durch die COVID-19-Pandemie verursachte globale Unsicherheit, führte zu einer zunehmenden Verbreitung von Verschwörungstheorien, darunter die rechtsextreme und trumpistische Verschwörungstheorie [QAnon](https://de.wikipedia.org/wiki/QAnon)[^1].

In diesem Beitrag wird untersucht, ob sich solche Tendenzen in Twitter-Daten erkennen lassen. Dazu wurden Tweets gesammelt, welche sich auf QAnon beziehen und während des Lockdowns abgesetzt wurden. Basierend auf diesem Dataset erfolgt einerseits eine Gegenüberstellung zu der Zunahme von COVID-19-Fällen im gleichen Zeitraum. Andererseits wird mittels Machine Learning durch eine nonparametrische, automatisierte Inhaltsanalyse mit [readme2](https://github.com/iqss-research/readme-software) eine Einschätzung darüber abgegeben, wieviele der Tweets sich affirmativ bzw. kritisch auf QAnon beziehen.

### Die Twitter-Daten

Das Dataset besteht aus 11’363 deutschsprachigen Tweets aus dem Zeitraum 1. Februar 2020 bis 24. April 2020, welche sich entweder durch das Schlagwort “QAnon” oder “wwg1wga” (ein Leitspruch und Codewort der Anhänger\*innen, stehend für “where we go one, we go all” - der autoritäre Charakter kondensiert in einen Hashtag?!) auf QAnon beziehen. Diese wurden mit dem Python-Skript [TweetScraper](https://github.com/jonbakerfish/TweetScraper) aggregiert, in einer lokalen [MongoDB](https://www.mongodb.com/)-Datenbank gespeichert und nach der Codierung (siehe unten) als JSON-Dump exportiert ([hier](qanon_dump.json).

## Zunehmende COVID-19-Fälle vs. Anzahl QAnon-Tweets

Zunächst soll überprüft werden, ob in den Daten tatsächlich eine Zunahme von QAnon-Tweets während der Corona-Pandemie feststellbar ist. Dafür werden die Anzahl Tweets pro Tag der Anzahl COVID-19-Fälle in der Schweiz, Deutschland und Österreich im gleichen Zeitraum gegenübergestellt.

Lesen wir die Daten ein:

``` r
# Load the data from dump-file
tweets <- jsonlite::stream_in(file("qanon_dump.json"), verbose = F)
```

Für die Zeitstrahl-Analyse werden die Tweets nun nach Veröffentlichkeitsdatum geordnet und gruppiert:

``` r
# Prepare data for timeline analysis
tweets_uncoded <- tweets %>%
  filter(is.na(code)) %>% # Filter out coded tweets - the dates of these got messed up while coding unfortunately..
  mutate(
    datetime = datetime %>% 
    parse_date_time(orders = ' %Y-%m-%d %H%M%S') # Parse date
  ) %>%
  mutate(datetime = datetime + 1*60*60) %>% # Set time from UTC to CET.
  mutate(datetime = datetime %>% round(units = 'days') %>% as.POSIXct()) # Remove the time, we just need the dates
 
# What timerange do we have?
# tweets_uncoded %>% pull(datetime) %>% min()
# tweets_uncoded %>% pull(datetime) %>% max()

# Group by day
tweet_groups <- tweets_uncoded %>% group_by(datetime) %>% tally() %>% rename(date = datetime)
```

Mit dem R-Package `tidycovid19` können wir ein Dataset mit der Anzahl COVID-19-Fällen laden und diese ebenfalls nach Datum gruppieren. Da nur Tweets aus dem deutssprachigen Raum analysiert werden, berücksichtigen wir auch nur Fallzahlen aus Deutschland, Österreich und der Schweiz. Dabei werden die COVID-19-Fallzahlen für die Visualisierung proportional zur Anzahl Tweets herunterskaliert - die Messeinheit der Y-Achse stimmt also in der Grafik nur für die Anzahl Tweets, nicht aber für die COVID-19-Fallzahlen!

``` r
# Get covid-cases via tidycovid19 package
# covid <- download_merged_data(cached = TRUE)
covid <- jsonlite::stream_in(file("covid_data.json"), verbose = F)

# German cases
covidDE <- covid %>%
  filter(iso3c == "DEU") %>%
  select(date, confirmed) %>%
  mutate(confirmed = round(confirmed/382)) %>% # Normalize case numbers proportionaly to the maximum numbers of tweets (max (max 400/day)
  mutate(
    date = date %>% 
    # Parse date.
    parse_date_time(orders = ' %Y-%m-%d')
  ) %>%
  filter(date > "2020-02-01" & date <"2020-04-25")

# Swiss cases
covidCH <- covid %>%
  filter(iso3c == "CHE") %>%
  select(date, confirmed) %>%
  mutate(confirmed = round(confirmed/71)) %>% # Normalize case numbers proportionaly to the maximum numbers of tweets (max 400/day)
  mutate(
    date = date %>% 
    # Parse date.
    parse_date_time(orders = ' %Y-%m-%d')
  ) %>%
  filter(date > "2020-02-01" & date <"2020-04-25")

# Austrian cases
covidAT <- covid %>%
  filter(iso3c == "AUT") %>%
  select(date, confirmed) %>%
  mutate(confirmed = round(confirmed/37)) %>% # Normalize case numbers proportionaly to the maximum numbers of tweets (max 400/day)
  mutate(
    date = date %>% 
    # Parse date.
    parse_date_time(orders = ' %Y-%m-%d')
  ) %>%
  filter(date > "2020-02-01" & date <"2020-04-25")

# join tweets & covid-cases
tweets_covid <- covidDE %>% 
  right_join(covidCH, by="date") %>% 
  right_join(covidAT, by="date") %>% 
  right_join(tweet_groups, by="date") %>%
  select(date, Covid_DE = confirmed.x, Covid_CH = confirmed.y, Covid_AUT = confirmed, Num_Tweets=n) # rename columns for plotly
```

Die nach Tag gruppierte Anzahl Tweets und COVID-19-Fälle können nun visualisiert werden:

``` r
# "Melt" the dates for plotting
melted <- melt(tweets_covid, id="date")

# Prepare plot
plot <- ggplot(data=melted,
    aes(x=date, y=value, colour=variable)) +
    geom_line() +
    labs(title = 'Anzahl QAnon-Tweets vs. COVID-19-Fälle',
           y = 'Anzahl Tweets',
           x = 'Datum',
           subtitle = str_c("Total 11'363 Tweets aus dem Zeitraum 01.02.2020-24.04.2020",
                              "(COVID-19-Fälle sind normalisiert, Y-Achse misst nur Anzahl Tweets)"),
           colour = ""
           )

# plot it
fig <- ggplotly(plot)
fig
```

<div class="plotly html-widget html-fill-item" id="htmlwidget-1" style="width:672px;height:480px;"></div>
<script type="application/json" data-for="htmlwidget-1">{"x":{"data":[{"x":[1580515200,1580601600,1580688000,1580774400,1580860800,1580947200,1581033600,1581120000,1581206400,1581292800,1581379200,1581465600,1581552000,1581638400,1581724800,1581811200,1581897600,1581984000,1582070400,1582156800,1582243200,1582329600,1582416000,1582502400,1582588800,1582675200,1582761600,1582848000,1582934400,1583020800,1583107200,1583193600,1583280000,1583366400,1583452800,1583539200,1583625600,1583712000,1583798400,1583884800,1583971200,1584057600,1584144000,1584230400,1584316800,1584403200,1584489600,1584576000,1584662400,1584748800,1584835200,1584921600,1585008000,1585094400,1585180800,1585267200,1585353600,1585440000,1585526400,1585612800,1585699200,1585785600,1585872000,1585958400,1586044800,1586131200,1586217600,1586304000,1586390400,1586476800,1586563200,1586649600,1586736000,1586822400,1586908800,1586995200,1587081600,1587168000,1587254400,1587340800,1587427200,1587513600,1587600000,1587686400],"y":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,2,2,3,3,4,5,5,10,12,15,19,24,32,40,52,58,65,76,86,98,115,133,151,163,175,188,204,222,239,252,262,271,282,297,309,320,327,335,341,344,353,360,370,375,380,385,388,394,401,406],"text":["date: 2020-02-01<br />value:   0<br />variable: Covid_DE","date: 2020-02-02<br />value:   0<br />variable: Covid_DE","date: 2020-02-03<br />value:   0<br />variable: Covid_DE","date: 2020-02-04<br />value:   0<br />variable: Covid_DE","date: 2020-02-05<br />value:   0<br />variable: Covid_DE","date: 2020-02-06<br />value:   0<br />variable: Covid_DE","date: 2020-02-07<br />value:   0<br />variable: Covid_DE","date: 2020-02-08<br />value:   0<br />variable: Covid_DE","date: 2020-02-09<br />value:   0<br />variable: Covid_DE","date: 2020-02-10<br />value:   0<br />variable: Covid_DE","date: 2020-02-11<br />value:   0<br />variable: Covid_DE","date: 2020-02-12<br />value:   0<br />variable: Covid_DE","date: 2020-02-13<br />value:   0<br />variable: Covid_DE","date: 2020-02-14<br />value:   0<br />variable: Covid_DE","date: 2020-02-15<br />value:   0<br />variable: Covid_DE","date: 2020-02-16<br />value:   0<br />variable: Covid_DE","date: 2020-02-17<br />value:   0<br />variable: Covid_DE","date: 2020-02-18<br />value:   0<br />variable: Covid_DE","date: 2020-02-19<br />value:   0<br />variable: Covid_DE","date: 2020-02-20<br />value:   0<br />variable: Covid_DE","date: 2020-02-21<br />value:   0<br />variable: Covid_DE","date: 2020-02-22<br />value:   0<br />variable: Covid_DE","date: 2020-02-23<br />value:   0<br />variable: Covid_DE","date: 2020-02-24<br />value:   0<br />variable: Covid_DE","date: 2020-02-25<br />value:   0<br />variable: Covid_DE","date: 2020-02-26<br />value:   0<br />variable: Covid_DE","date: 2020-02-27<br />value:   0<br />variable: Covid_DE","date: 2020-02-28<br />value:   0<br />variable: Covid_DE","date: 2020-02-29<br />value:   0<br />variable: Covid_DE","date: 2020-03-01<br />value:   0<br />variable: Covid_DE","date: 2020-03-02<br />value:   0<br />variable: Covid_DE","date: 2020-03-03<br />value:   1<br />variable: Covid_DE","date: 2020-03-04<br />value:   1<br />variable: Covid_DE","date: 2020-03-05<br />value:   1<br />variable: Covid_DE","date: 2020-03-06<br />value:   2<br />variable: Covid_DE","date: 2020-03-07<br />value:   2<br />variable: Covid_DE","date: 2020-03-08<br />value:   3<br />variable: Covid_DE","date: 2020-03-09<br />value:   3<br />variable: Covid_DE","date: 2020-03-10<br />value:   4<br />variable: Covid_DE","date: 2020-03-11<br />value:   5<br />variable: Covid_DE","date: 2020-03-12<br />value:   5<br />variable: Covid_DE","date: 2020-03-13<br />value:  10<br />variable: Covid_DE","date: 2020-03-14<br />value:  12<br />variable: Covid_DE","date: 2020-03-15<br />value:  15<br />variable: Covid_DE","date: 2020-03-16<br />value:  19<br />variable: Covid_DE","date: 2020-03-17<br />value:  24<br />variable: Covid_DE","date: 2020-03-18<br />value:  32<br />variable: Covid_DE","date: 2020-03-19<br />value:  40<br />variable: Covid_DE","date: 2020-03-20<br />value:  52<br />variable: Covid_DE","date: 2020-03-21<br />value:  58<br />variable: Covid_DE","date: 2020-03-22<br />value:  65<br />variable: Covid_DE","date: 2020-03-23<br />value:  76<br />variable: Covid_DE","date: 2020-03-24<br />value:  86<br />variable: Covid_DE","date: 2020-03-25<br />value:  98<br />variable: Covid_DE","date: 2020-03-26<br />value: 115<br />variable: Covid_DE","date: 2020-03-27<br />value: 133<br />variable: Covid_DE","date: 2020-03-28<br />value: 151<br />variable: Covid_DE","date: 2020-03-29<br />value: 163<br />variable: Covid_DE","date: 2020-03-30<br />value: 175<br />variable: Covid_DE","date: 2020-03-31<br />value: 188<br />variable: Covid_DE","date: 2020-04-01<br />value: 204<br />variable: Covid_DE","date: 2020-04-02<br />value: 222<br />variable: Covid_DE","date: 2020-04-03<br />value: 239<br />variable: Covid_DE","date: 2020-04-04<br />value: 252<br />variable: Covid_DE","date: 2020-04-05<br />value: 262<br />variable: Covid_DE","date: 2020-04-06<br />value: 271<br />variable: Covid_DE","date: 2020-04-07<br />value: 282<br />variable: Covid_DE","date: 2020-04-08<br />value: 297<br />variable: Covid_DE","date: 2020-04-09<br />value: 309<br />variable: Covid_DE","date: 2020-04-10<br />value: 320<br />variable: Covid_DE","date: 2020-04-11<br />value: 327<br />variable: Covid_DE","date: 2020-04-12<br />value: 335<br />variable: Covid_DE","date: 2020-04-13<br />value: 341<br />variable: Covid_DE","date: 2020-04-14<br />value: 344<br />variable: Covid_DE","date: 2020-04-15<br />value: 353<br />variable: Covid_DE","date: 2020-04-16<br />value: 360<br />variable: Covid_DE","date: 2020-04-17<br />value: 370<br />variable: Covid_DE","date: 2020-04-18<br />value: 375<br />variable: Covid_DE","date: 2020-04-19<br />value: 380<br />variable: Covid_DE","date: 2020-04-20<br />value: 385<br />variable: Covid_DE","date: 2020-04-21<br />value: 388<br />variable: Covid_DE","date: 2020-04-22<br />value: 394<br />variable: Covid_DE","date: 2020-04-23<br />value: 401<br />variable: Covid_DE","date: 2020-04-24<br />value: 406<br />variable: Covid_DE"],"type":"scatter","mode":"lines","line":{"width":1.8897637795275593,"color":"rgba(248,118,109,1)","dash":"solid"},"hoveron":"points","name":"Covid_DE","legendgroup":"Covid_DE","showlegend":true,"xaxis":"x","yaxis":"y","hoverinfo":"text","frame":null},{"x":[1580515200,1580601600,1580688000,1580774400,1580860800,1580947200,1581033600,1581120000,1581206400,1581292800,1581379200,1581465600,1581552000,1581638400,1581724800,1581811200,1581897600,1581984000,1582070400,1582156800,1582243200,1582329600,1582416000,1582502400,1582588800,1582675200,1582761600,1582848000,1582934400,1583020800,1583107200,1583193600,1583280000,1583366400,1583452800,1583539200,1583625600,1583712000,1583798400,1583884800,1583971200,1584057600,1584144000,1584230400,1584316800,1584403200,1584489600,1584576000,1584662400,1584748800,1584835200,1584921600,1585008000,1585094400,1585180800,1585267200,1585353600,1585440000,1585526400,1585612800,1585699200,1585785600,1585872000,1585958400,1586044800,1586131200,1586217600,1586304000,1586390400,1586476800,1586563200,1586649600,1586736000,1586822400,1586908800,1586995200,1587081600,1587168000,1587254400,1587340800,1587427200,1587513600,1587600000,1587686400],"y":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,2,3,4,5,5,7,9,9,16,19,31,31,38,43,57,75,93,105,124,139,153,166,182,198,209,224,234,250,265,276,289,297,305,313,328,339,346,354,358,362,365,371,377,381,386,391,394,395,398,401,404],"text":["date: 2020-02-01<br />value:   0<br />variable: Covid_CH","date: 2020-02-02<br />value:   0<br />variable: Covid_CH","date: 2020-02-03<br />value:   0<br />variable: Covid_CH","date: 2020-02-04<br />value:   0<br />variable: Covid_CH","date: 2020-02-05<br />value:   0<br />variable: Covid_CH","date: 2020-02-06<br />value:   0<br />variable: Covid_CH","date: 2020-02-07<br />value:   0<br />variable: Covid_CH","date: 2020-02-08<br />value:   0<br />variable: Covid_CH","date: 2020-02-09<br />value:   0<br />variable: Covid_CH","date: 2020-02-10<br />value:   0<br />variable: Covid_CH","date: 2020-02-11<br />value:   0<br />variable: Covid_CH","date: 2020-02-12<br />value:   0<br />variable: Covid_CH","date: 2020-02-13<br />value:   0<br />variable: Covid_CH","date: 2020-02-14<br />value:   0<br />variable: Covid_CH","date: 2020-02-15<br />value:   0<br />variable: Covid_CH","date: 2020-02-16<br />value:   0<br />variable: Covid_CH","date: 2020-02-17<br />value:   0<br />variable: Covid_CH","date: 2020-02-18<br />value:   0<br />variable: Covid_CH","date: 2020-02-19<br />value:   0<br />variable: Covid_CH","date: 2020-02-20<br />value:   0<br />variable: Covid_CH","date: 2020-02-21<br />value:   0<br />variable: Covid_CH","date: 2020-02-22<br />value:   0<br />variable: Covid_CH","date: 2020-02-23<br />value:   0<br />variable: Covid_CH","date: 2020-02-24<br />value:   0<br />variable: Covid_CH","date: 2020-02-25<br />value:   0<br />variable: Covid_CH","date: 2020-02-26<br />value:   0<br />variable: Covid_CH","date: 2020-02-27<br />value:   0<br />variable: Covid_CH","date: 2020-02-28<br />value:   0<br />variable: Covid_CH","date: 2020-02-29<br />value:   0<br />variable: Covid_CH","date: 2020-03-01<br />value:   0<br />variable: Covid_CH","date: 2020-03-02<br />value:   1<br />variable: Covid_CH","date: 2020-03-03<br />value:   1<br />variable: Covid_CH","date: 2020-03-04<br />value:   1<br />variable: Covid_CH","date: 2020-03-05<br />value:   2<br />variable: Covid_CH","date: 2020-03-06<br />value:   3<br />variable: Covid_CH","date: 2020-03-07<br />value:   4<br />variable: Covid_CH","date: 2020-03-08<br />value:   5<br />variable: Covid_CH","date: 2020-03-09<br />value:   5<br />variable: Covid_CH","date: 2020-03-10<br />value:   7<br />variable: Covid_CH","date: 2020-03-11<br />value:   9<br />variable: Covid_CH","date: 2020-03-12<br />value:   9<br />variable: Covid_CH","date: 2020-03-13<br />value:  16<br />variable: Covid_CH","date: 2020-03-14<br />value:  19<br />variable: Covid_CH","date: 2020-03-15<br />value:  31<br />variable: Covid_CH","date: 2020-03-16<br />value:  31<br />variable: Covid_CH","date: 2020-03-17<br />value:  38<br />variable: Covid_CH","date: 2020-03-18<br />value:  43<br />variable: Covid_CH","date: 2020-03-19<br />value:  57<br />variable: Covid_CH","date: 2020-03-20<br />value:  75<br />variable: Covid_CH","date: 2020-03-21<br />value:  93<br />variable: Covid_CH","date: 2020-03-22<br />value: 105<br />variable: Covid_CH","date: 2020-03-23<br />value: 124<br />variable: Covid_CH","date: 2020-03-24<br />value: 139<br />variable: Covid_CH","date: 2020-03-25<br />value: 153<br />variable: Covid_CH","date: 2020-03-26<br />value: 166<br />variable: Covid_CH","date: 2020-03-27<br />value: 182<br />variable: Covid_CH","date: 2020-03-28<br />value: 198<br />variable: Covid_CH","date: 2020-03-29<br />value: 209<br />variable: Covid_CH","date: 2020-03-30<br />value: 224<br />variable: Covid_CH","date: 2020-03-31<br />value: 234<br />variable: Covid_CH","date: 2020-04-01<br />value: 250<br />variable: Covid_CH","date: 2020-04-02<br />value: 265<br />variable: Covid_CH","date: 2020-04-03<br />value: 276<br />variable: Covid_CH","date: 2020-04-04<br />value: 289<br />variable: Covid_CH","date: 2020-04-05<br />value: 297<br />variable: Covid_CH","date: 2020-04-06<br />value: 305<br />variable: Covid_CH","date: 2020-04-07<br />value: 313<br />variable: Covid_CH","date: 2020-04-08<br />value: 328<br />variable: Covid_CH","date: 2020-04-09<br />value: 339<br />variable: Covid_CH","date: 2020-04-10<br />value: 346<br />variable: Covid_CH","date: 2020-04-11<br />value: 354<br />variable: Covid_CH","date: 2020-04-12<br />value: 358<br />variable: Covid_CH","date: 2020-04-13<br />value: 362<br />variable: Covid_CH","date: 2020-04-14<br />value: 365<br />variable: Covid_CH","date: 2020-04-15<br />value: 371<br />variable: Covid_CH","date: 2020-04-16<br />value: 377<br />variable: Covid_CH","date: 2020-04-17<br />value: 381<br />variable: Covid_CH","date: 2020-04-18<br />value: 386<br />variable: Covid_CH","date: 2020-04-19<br />value: 391<br />variable: Covid_CH","date: 2020-04-20<br />value: 394<br />variable: Covid_CH","date: 2020-04-21<br />value: 395<br />variable: Covid_CH","date: 2020-04-22<br />value: 398<br />variable: Covid_CH","date: 2020-04-23<br />value: 401<br />variable: Covid_CH","date: 2020-04-24<br />value: 404<br />variable: Covid_CH"],"type":"scatter","mode":"lines","line":{"width":1.8897637795275593,"color":"rgba(124,174,0,1)","dash":"solid"},"hoveron":"points","name":"Covid_CH","legendgroup":"Covid_CH","showlegend":true,"xaxis":"x","yaxis":"y","hoverinfo":"text","frame":null},{"x":[1580515200,1580601600,1580688000,1580774400,1580860800,1580947200,1581033600,1581120000,1581206400,1581292800,1581379200,1581465600,1581552000,1581638400,1581724800,1581811200,1581897600,1581984000,1582070400,1582156800,1582243200,1582329600,1582416000,1582502400,1582588800,1582675200,1582761600,1582848000,1582934400,1583020800,1583107200,1583193600,1583280000,1583366400,1583452800,1583539200,1583625600,1583712000,1583798400,1583884800,1583971200,1584057600,1584144000,1584230400,1584316800,1584403200,1584489600,1584576000,1584662400,1584748800,1584835200,1584921600,1585008000,1585094400,1585180800,1585267200,1585353600,1585440000,1585526400,1585612800,1585699200,1585785600,1585872000,1585958400,1586044800,1586131200,1586217600,1586304000,1586390400,1586476800,1586563200,1586649600,1586736000,1586822400,1586908800,1586995200,1587081600,1587168000,1587254400,1587340800,1587427200,1587513600,1587600000,1587686400],"y":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,2,3,4,5,7,8,14,18,23,28,36,44,54,65,76,97,121,143,151,187,207,224,238,260,275,289,301,311,318,326,332,342,350,358,366,373,377,379,384,387,391,394,397,399,400,402,403,405,407],"text":["date: 2020-02-01<br />value:   0<br />variable: Covid_AUT","date: 2020-02-02<br />value:   0<br />variable: Covid_AUT","date: 2020-02-03<br />value:   0<br />variable: Covid_AUT","date: 2020-02-04<br />value:   0<br />variable: Covid_AUT","date: 2020-02-05<br />value:   0<br />variable: Covid_AUT","date: 2020-02-06<br />value:   0<br />variable: Covid_AUT","date: 2020-02-07<br />value:   0<br />variable: Covid_AUT","date: 2020-02-08<br />value:   0<br />variable: Covid_AUT","date: 2020-02-09<br />value:   0<br />variable: Covid_AUT","date: 2020-02-10<br />value:   0<br />variable: Covid_AUT","date: 2020-02-11<br />value:   0<br />variable: Covid_AUT","date: 2020-02-12<br />value:   0<br />variable: Covid_AUT","date: 2020-02-13<br />value:   0<br />variable: Covid_AUT","date: 2020-02-14<br />value:   0<br />variable: Covid_AUT","date: 2020-02-15<br />value:   0<br />variable: Covid_AUT","date: 2020-02-16<br />value:   0<br />variable: Covid_AUT","date: 2020-02-17<br />value:   0<br />variable: Covid_AUT","date: 2020-02-18<br />value:   0<br />variable: Covid_AUT","date: 2020-02-19<br />value:   0<br />variable: Covid_AUT","date: 2020-02-20<br />value:   0<br />variable: Covid_AUT","date: 2020-02-21<br />value:   0<br />variable: Covid_AUT","date: 2020-02-22<br />value:   0<br />variable: Covid_AUT","date: 2020-02-23<br />value:   0<br />variable: Covid_AUT","date: 2020-02-24<br />value:   0<br />variable: Covid_AUT","date: 2020-02-25<br />value:   0<br />variable: Covid_AUT","date: 2020-02-26<br />value:   0<br />variable: Covid_AUT","date: 2020-02-27<br />value:   0<br />variable: Covid_AUT","date: 2020-02-28<br />value:   0<br />variable: Covid_AUT","date: 2020-02-29<br />value:   0<br />variable: Covid_AUT","date: 2020-03-01<br />value:   0<br />variable: Covid_AUT","date: 2020-03-02<br />value:   0<br />variable: Covid_AUT","date: 2020-03-03<br />value:   1<br />variable: Covid_AUT","date: 2020-03-04<br />value:   1<br />variable: Covid_AUT","date: 2020-03-05<br />value:   1<br />variable: Covid_AUT","date: 2020-03-06<br />value:   1<br />variable: Covid_AUT","date: 2020-03-07<br />value:   2<br />variable: Covid_AUT","date: 2020-03-08<br />value:   3<br />variable: Covid_AUT","date: 2020-03-09<br />value:   4<br />variable: Covid_AUT","date: 2020-03-10<br />value:   5<br />variable: Covid_AUT","date: 2020-03-11<br />value:   7<br />variable: Covid_AUT","date: 2020-03-12<br />value:   8<br />variable: Covid_AUT","date: 2020-03-13<br />value:  14<br />variable: Covid_AUT","date: 2020-03-14<br />value:  18<br />variable: Covid_AUT","date: 2020-03-15<br />value:  23<br />variable: Covid_AUT","date: 2020-03-16<br />value:  28<br />variable: Covid_AUT","date: 2020-03-17<br />value:  36<br />variable: Covid_AUT","date: 2020-03-18<br />value:  44<br />variable: Covid_AUT","date: 2020-03-19<br />value:  54<br />variable: Covid_AUT","date: 2020-03-20<br />value:  65<br />variable: Covid_AUT","date: 2020-03-21<br />value:  76<br />variable: Covid_AUT","date: 2020-03-22<br />value:  97<br />variable: Covid_AUT","date: 2020-03-23<br />value: 121<br />variable: Covid_AUT","date: 2020-03-24<br />value: 143<br />variable: Covid_AUT","date: 2020-03-25<br />value: 151<br />variable: Covid_AUT","date: 2020-03-26<br />value: 187<br />variable: Covid_AUT","date: 2020-03-27<br />value: 207<br />variable: Covid_AUT","date: 2020-03-28<br />value: 224<br />variable: Covid_AUT","date: 2020-03-29<br />value: 238<br />variable: Covid_AUT","date: 2020-03-30<br />value: 260<br />variable: Covid_AUT","date: 2020-03-31<br />value: 275<br />variable: Covid_AUT","date: 2020-04-01<br />value: 289<br />variable: Covid_AUT","date: 2020-04-02<br />value: 301<br />variable: Covid_AUT","date: 2020-04-03<br />value: 311<br />variable: Covid_AUT","date: 2020-04-04<br />value: 318<br />variable: Covid_AUT","date: 2020-04-05<br />value: 326<br />variable: Covid_AUT","date: 2020-04-06<br />value: 332<br />variable: Covid_AUT","date: 2020-04-07<br />value: 342<br />variable: Covid_AUT","date: 2020-04-08<br />value: 350<br />variable: Covid_AUT","date: 2020-04-09<br />value: 358<br />variable: Covid_AUT","date: 2020-04-10<br />value: 366<br />variable: Covid_AUT","date: 2020-04-11<br />value: 373<br />variable: Covid_AUT","date: 2020-04-12<br />value: 377<br />variable: Covid_AUT","date: 2020-04-13<br />value: 379<br />variable: Covid_AUT","date: 2020-04-14<br />value: 384<br />variable: Covid_AUT","date: 2020-04-15<br />value: 387<br />variable: Covid_AUT","date: 2020-04-16<br />value: 391<br />variable: Covid_AUT","date: 2020-04-17<br />value: 394<br />variable: Covid_AUT","date: 2020-04-18<br />value: 397<br />variable: Covid_AUT","date: 2020-04-19<br />value: 399<br />variable: Covid_AUT","date: 2020-04-20<br />value: 400<br />variable: Covid_AUT","date: 2020-04-21<br />value: 402<br />variable: Covid_AUT","date: 2020-04-22<br />value: 403<br />variable: Covid_AUT","date: 2020-04-23<br />value: 405<br />variable: Covid_AUT","date: 2020-04-24<br />value: 407<br />variable: Covid_AUT"],"type":"scatter","mode":"lines","line":{"width":1.8897637795275593,"color":"rgba(0,191,196,1)","dash":"solid"},"hoveron":"points","name":"Covid_AUT","legendgroup":"Covid_AUT","showlegend":true,"xaxis":"x","yaxis":"y","hoverinfo":"text","frame":null},{"x":[1580515200,1580601600,1580688000,1580774400,1580860800,1580947200,1581033600,1581120000,1581206400,1581292800,1581379200,1581465600,1581552000,1581638400,1581724800,1581811200,1581897600,1581984000,1582070400,1582156800,1582243200,1582329600,1582416000,1582502400,1582588800,1582675200,1582761600,1582848000,1582934400,1583020800,1583107200,1583193600,1583280000,1583366400,1583452800,1583539200,1583625600,1583712000,1583798400,1583884800,1583971200,1584057600,1584144000,1584230400,1584316800,1584403200,1584489600,1584576000,1584662400,1584748800,1584835200,1584921600,1585008000,1585094400,1585180800,1585267200,1585353600,1585440000,1585526400,1585612800,1585699200,1585785600,1585872000,1585958400,1586044800,1586131200,1586217600,1586304000,1586390400,1586476800,1586563200,1586649600,1586736000,1586822400,1586908800,1586995200,1587081600,1587168000,1587254400,1587340800,1587427200,1587513600,1587600000,1587686400],"y":[10,38,34,29,33,58,40,37,43,47,48,55,46,36,51,36,38,43,63,67,107,72,51,67,41,52,47,41,36,25,48,33,42,37,40,42,54,51,73,56,73,73,56,112,91,117,114,176,158,153,132,160,136,127,128,207,121,118,169,156,136,103,214,196,173,168,178,161,209,201,219,284,309,385,283,290,346,381,287,316,274,199,384,319],"text":["date: 2020-02-01<br />value:  10<br />variable: Num_Tweets","date: 2020-02-02<br />value:  38<br />variable: Num_Tweets","date: 2020-02-03<br />value:  34<br />variable: Num_Tweets","date: 2020-02-04<br />value:  29<br />variable: Num_Tweets","date: 2020-02-05<br />value:  33<br />variable: Num_Tweets","date: 2020-02-06<br />value:  58<br />variable: Num_Tweets","date: 2020-02-07<br />value:  40<br />variable: Num_Tweets","date: 2020-02-08<br />value:  37<br />variable: Num_Tweets","date: 2020-02-09<br />value:  43<br />variable: Num_Tweets","date: 2020-02-10<br />value:  47<br />variable: Num_Tweets","date: 2020-02-11<br />value:  48<br />variable: Num_Tweets","date: 2020-02-12<br />value:  55<br />variable: Num_Tweets","date: 2020-02-13<br />value:  46<br />variable: Num_Tweets","date: 2020-02-14<br />value:  36<br />variable: Num_Tweets","date: 2020-02-15<br />value:  51<br />variable: Num_Tweets","date: 2020-02-16<br />value:  36<br />variable: Num_Tweets","date: 2020-02-17<br />value:  38<br />variable: Num_Tweets","date: 2020-02-18<br />value:  43<br />variable: Num_Tweets","date: 2020-02-19<br />value:  63<br />variable: Num_Tweets","date: 2020-02-20<br />value:  67<br />variable: Num_Tweets","date: 2020-02-21<br />value: 107<br />variable: Num_Tweets","date: 2020-02-22<br />value:  72<br />variable: Num_Tweets","date: 2020-02-23<br />value:  51<br />variable: Num_Tweets","date: 2020-02-24<br />value:  67<br />variable: Num_Tweets","date: 2020-02-25<br />value:  41<br />variable: Num_Tweets","date: 2020-02-26<br />value:  52<br />variable: Num_Tweets","date: 2020-02-27<br />value:  47<br />variable: Num_Tweets","date: 2020-02-28<br />value:  41<br />variable: Num_Tweets","date: 2020-02-29<br />value:  36<br />variable: Num_Tweets","date: 2020-03-01<br />value:  25<br />variable: Num_Tweets","date: 2020-03-02<br />value:  48<br />variable: Num_Tweets","date: 2020-03-03<br />value:  33<br />variable: Num_Tweets","date: 2020-03-04<br />value:  42<br />variable: Num_Tweets","date: 2020-03-05<br />value:  37<br />variable: Num_Tweets","date: 2020-03-06<br />value:  40<br />variable: Num_Tweets","date: 2020-03-07<br />value:  42<br />variable: Num_Tweets","date: 2020-03-08<br />value:  54<br />variable: Num_Tweets","date: 2020-03-09<br />value:  51<br />variable: Num_Tweets","date: 2020-03-10<br />value:  73<br />variable: Num_Tweets","date: 2020-03-11<br />value:  56<br />variable: Num_Tweets","date: 2020-03-12<br />value:  73<br />variable: Num_Tweets","date: 2020-03-13<br />value:  73<br />variable: Num_Tweets","date: 2020-03-14<br />value:  56<br />variable: Num_Tweets","date: 2020-03-15<br />value: 112<br />variable: Num_Tweets","date: 2020-03-16<br />value:  91<br />variable: Num_Tweets","date: 2020-03-17<br />value: 117<br />variable: Num_Tweets","date: 2020-03-18<br />value: 114<br />variable: Num_Tweets","date: 2020-03-19<br />value: 176<br />variable: Num_Tweets","date: 2020-03-20<br />value: 158<br />variable: Num_Tweets","date: 2020-03-21<br />value: 153<br />variable: Num_Tweets","date: 2020-03-22<br />value: 132<br />variable: Num_Tweets","date: 2020-03-23<br />value: 160<br />variable: Num_Tweets","date: 2020-03-24<br />value: 136<br />variable: Num_Tweets","date: 2020-03-25<br />value: 127<br />variable: Num_Tweets","date: 2020-03-26<br />value: 128<br />variable: Num_Tweets","date: 2020-03-27<br />value: 207<br />variable: Num_Tweets","date: 2020-03-28<br />value: 121<br />variable: Num_Tweets","date: 2020-03-29<br />value: 118<br />variable: Num_Tweets","date: 2020-03-30<br />value: 169<br />variable: Num_Tweets","date: 2020-03-31<br />value: 156<br />variable: Num_Tweets","date: 2020-04-01<br />value: 136<br />variable: Num_Tweets","date: 2020-04-02<br />value: 103<br />variable: Num_Tweets","date: 2020-04-03<br />value: 214<br />variable: Num_Tweets","date: 2020-04-04<br />value: 196<br />variable: Num_Tweets","date: 2020-04-05<br />value: 173<br />variable: Num_Tweets","date: 2020-04-06<br />value: 168<br />variable: Num_Tweets","date: 2020-04-07<br />value: 178<br />variable: Num_Tweets","date: 2020-04-08<br />value: 161<br />variable: Num_Tweets","date: 2020-04-09<br />value: 209<br />variable: Num_Tweets","date: 2020-04-10<br />value: 201<br />variable: Num_Tweets","date: 2020-04-11<br />value: 219<br />variable: Num_Tweets","date: 2020-04-12<br />value: 284<br />variable: Num_Tweets","date: 2020-04-13<br />value: 309<br />variable: Num_Tweets","date: 2020-04-14<br />value: 385<br />variable: Num_Tweets","date: 2020-04-15<br />value: 283<br />variable: Num_Tweets","date: 2020-04-16<br />value: 290<br />variable: Num_Tweets","date: 2020-04-17<br />value: 346<br />variable: Num_Tweets","date: 2020-04-18<br />value: 381<br />variable: Num_Tweets","date: 2020-04-19<br />value: 287<br />variable: Num_Tweets","date: 2020-04-20<br />value: 316<br />variable: Num_Tweets","date: 2020-04-21<br />value: 274<br />variable: Num_Tweets","date: 2020-04-22<br />value: 199<br />variable: Num_Tweets","date: 2020-04-23<br />value: 384<br />variable: Num_Tweets","date: 2020-04-24<br />value: 319<br />variable: Num_Tweets"],"type":"scatter","mode":"lines","line":{"width":1.8897637795275593,"color":"rgba(199,124,255,1)","dash":"solid"},"hoveron":"points","name":"Num_Tweets","legendgroup":"Num_Tweets","showlegend":true,"xaxis":"x","yaxis":"y","hoverinfo":"text","frame":null}],"layout":{"margin":{"t":43.762557077625573,"r":7.3059360730593621,"b":40.182648401826498,"l":43.105022831050235},"plot_bgcolor":"rgba(235,235,235,1)","paper_bgcolor":"rgba(255,255,255,1)","font":{"color":"rgba(0,0,0,1)","family":"","size":14.611872146118724},"title":{"text":"Anzahl QAnon-Tweets vs. COVID-19-Fälle","font":{"color":"rgba(0,0,0,1)","family":"","size":17.534246575342465},"x":0,"xref":"paper"},"xaxis":{"domain":[0,1],"automargin":true,"type":"linear","autorange":false,"range":[1580156640,1588044960],"tickmode":"array","ticktext":["Feb","Mar","Apr"],"tickvals":[1580515200,1583020800,1585699200],"categoryorder":"array","categoryarray":["Feb","Mar","Apr"],"nticks":null,"ticks":"outside","tickcolor":"rgba(51,51,51,1)","ticklen":3.6529680365296811,"tickwidth":0.66417600664176002,"showticklabels":true,"tickfont":{"color":"rgba(77,77,77,1)","family":"","size":11.68949771689498},"tickangle":-0,"showline":false,"linecolor":null,"linewidth":0,"showgrid":true,"gridcolor":"rgba(255,255,255,1)","gridwidth":0.66417600664176002,"zeroline":false,"anchor":"y","title":{"text":"Datum","font":{"color":"rgba(0,0,0,1)","family":"","size":14.611872146118724}},"hoverformat":".2f"},"yaxis":{"domain":[0,1],"automargin":true,"type":"linear","autorange":false,"range":[-20.350000000000001,427.35000000000002],"tickmode":"array","ticktext":["0","100","200","300","400"],"tickvals":[0,100,200,300,400],"categoryorder":"array","categoryarray":["0","100","200","300","400"],"nticks":null,"ticks":"outside","tickcolor":"rgba(51,51,51,1)","ticklen":3.6529680365296811,"tickwidth":0.66417600664176002,"showticklabels":true,"tickfont":{"color":"rgba(77,77,77,1)","family":"","size":11.68949771689498},"tickangle":-0,"showline":false,"linecolor":null,"linewidth":0,"showgrid":true,"gridcolor":"rgba(255,255,255,1)","gridwidth":0.66417600664176002,"zeroline":false,"anchor":"x","title":{"text":"Anzahl Tweets","font":{"color":"rgba(0,0,0,1)","family":"","size":14.611872146118724}},"hoverformat":".2f"},"shapes":[{"type":"rect","fillcolor":null,"line":{"color":null,"width":0,"linetype":[]},"yref":"paper","xref":"paper","layer":"below","x0":0,"x1":1,"y0":0,"y1":1}],"showlegend":true,"legend":{"bgcolor":"rgba(255,255,255,1)","bordercolor":"transparent","borderwidth":1.8897637795275593,"font":{"color":"rgba(0,0,0,1)","family":"","size":11.68949771689498},"title":{"text":"","font":{"color":"rgba(0,0,0,1)","family":"","size":14.611872146118724}}},"hovermode":"closest","barmode":"relative"},"config":{"doubleClick":"reset","modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"source":"A","attrs":{"fa172f1232b4":{"x":{},"y":{},"colour":{},"type":"scatter"}},"cur_data":"fa172f1232b4","visdat":{"fa172f1232b4":["function (y) ","x"]},"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}</script>

Der Plot zeigt deutlich, wie mit steigenden COVID-19-Fallzahlen auch die Anzahl abgesetzter Tweets zur QAnon-Verschwörungstheorie zunahmen. Lässt sich daraus schliessen, dass QAnon Anhänger\*innen gewonnen hat? Nicht unbedingt. Die Tweets können sich auch kritisch auf QAnon beziehen und zum Beispiel über die Gefahren der Verschwörungstheorie aufklären wollen.

In einem weiteren Schritt soll nun durch maschinelles Lernen eine Schätzung versucht werden, wieviele Tweets sich prozentual entweder positiv auf QAnon beziehen und die Verschwörungstheorie verbreiten oder negativ und kritisch auf QAnon hinweisen.

## Automatische Inhaltsanalyse mit dem R-Package readme2

Für die maschinelle Kategorisierung kommt hier das Package [readme2](https://github.com/iqss-research/readme-software) zum Einsatz, welches einen Machine-Learning-Algorithmus für die automatische Inhaltsanalyse von Texten für die Sozialwissenschaften implementiert.

Wie andere supervised ML-Algorithmen benötigt `readme2` ein Trainingsset von Daten, mit welchen der Algorithmus trainiert wird. Dieses Trainingsset muss manuell erstellt werden, indem zunächst ein Codierschema festgelegt und dann die Tweets mit einem Code der entsprechenden Kategorie zugeordnet werden. Sobald der Algorithmus trainiert ist, kann damit via Spracherkennung eine Schätzung der Verteilung aller Kategorien in den unkategorisierten Tweets gemacht werden.

### Manuelle Codierung der QAnon-Tweets

Da ich zur Erstellung des Testsets eine relativ grosse Anzahl Tweets manuell codieren musste (ca. 10% der 11’363 Tweets) und keine Software fand, mit welcher sich das einfach und schnell bewerkstelligen lässt, habe ich dafür eine kleine Web-App entwickelt ([Github-Link](https://github.com/nomaad/tweet_codes)). Das Tool lädt zufällig einzelne Tweets aus dem gesamten Datenset, welche sich dann codieren lassen. Der Code wird dem Datensatz als Feld hinzugefügt und einer MongoDB Datenbank gespeichert. Damit wurden 904 Tweets jeweils einer von drei Kategorien zugeordnet (0 = nicht zuordenbar, 1 = kritisch-negativer Bezug, 2 = affirmativ-positiver Bezug). Disclaimer: Ich habe die Tweets in relativ schnellem Tempo alleine ohne Validierung codiert, es können also durchaus Fehlcodierungen vorhanden sein.

![](tweetcoder.gif)

### Training des readme2-Algorithmus

Mit den codierten Tweets lässt sich nun der readme2-Algorithmus trainieren. Zur Textanalyse greift `readme2` auf word embeddings zurück, welche mit dem [GloVe-Algorithmus](http://text2vec.org/glove.html) erstellt wurden. `readme2` kommt mit englischen Worteinbettungen, ich habe deshalb für diese Analyse zunächst die deutschen Worteinbettungen von [deepset.ai](https://deepset.ai/german-word-embeddings) heruntergeladen, welche auf der deutschen Wikipedia trainiert wurden.

``` r
# Select the tweets which have a code
tweets_coded <- tweets %>%
  filter(!is.na(code))

# Helper function to load word embeddings
loadVecs <- function(path){
  wordVecs_corpus <- data.table::fread(path)
  wordVecs_keys <- wordVecs_corpus[[1]]## first row is the name of the term
  wordVecs_corpus <- as.matrix (  wordVecs_corpus[,-1] )  #
  row.names(wordVecs_corpus) <- wordVecs_keys
  wordVecs <- wordVecs_corpus
  rm(wordVecs_corpus)
  rm(wordVecs_keys) ## Remove the original loaded table to save space
  saveRDS(wordVecs, file = "wordVecs.rds")

  return(wordVecs)
}

## Generate a word vector summary for each document
# Use the german Wikipedia-trained GloVe word embeddings from https://deepset.ai/german-word-embeddings

# Load word embeddings.. 
# wordVecs <-loadVecs('deepset.ai.german.wikipedia.glove.txt')
# wordVec_summaries = undergrad(documentText = cleanme(tweets_coded$text), wordVecs = wordVecs)
#saveRDS(wordVec_summaries, file = "wordVec_summaries.rds")

# ..or load from cache instead
wordVec_summaries <- readRDS(file = "wordVec_summaries.rds")
```

Mit den deutschen Vektoren können 74% der Wörter in den 904 Tweets zugeordnet werden. Das scheint mir eher wenig, hat aber wohl damit zu tun, dass in den Tweets sehr viele themenspezifische Hashtags zu finden sind. Nun folgt 1) das eigentliche Training, 2) die automatisierte Kategorisierung der Testdaten und 3) der Abgleich zur Überprüfung mit den manuellen Codes der Testdaten. Schritt 1 und 2 werden direkt von der `readme()`-Funktion implementiert. Davor werden die 904 Tweets per Zufall in ein Test- und ein Trainingsset aufgeteilt. Ich mache drei Durchläufe mit jeweils unterschiedlichen Test- und Trainingssets, um einen besseren Eindruck über die Zuverlässigkeit der Schätzungen zu bekommen.

``` r
# Evaluate 3 times, how accurate the estimations are with the coded trainingset
use_virtualenv("r-tensorflow")

foreach(i=1:3) %do% {
  set.seed(i*123)
  
  # 1. Split coded tweets into a test and a training set
  rnd_train <- sample(c(0,1), nrow(tweets_coded), replace = T)
  tweets_coded$trainingset <- c(rnd_train)
  #length(which(tweets_coded$trainingset == 1))
  #length(which(tweets_coded$trainingset == 0))
  
  # 2. Call readme to make an estimation
  readme.estimates <- readme(dfm = wordVec_summaries , labeledIndicator = tweets_coded$trainingset, categoryVec = tweets_coded$code)
  
  # 3. Compare estimates & actual values
  # Output proportions estimate
  estimate <- readme.estimates$point_readme
  
  actual <- table(tweets_coded$code[tweets_coded$trainingset == 0])/sum(table((tweets_coded$code[tweets_coded$trainingset == 0])))
   
  # Calculate deviation of estimation from actual value in percent points
  percentages <- ((actual - estimate)/actual) * 100
}
```

    ## TensorFlow v2.16.2 (~/.virtualenvs/r-tensorflow/lib/python3.10/site-packages/tensorflow)
    ## Python v3.10 (~/.virtualenvs/r-tensorflow/bin/python)
    ## [1] "Performance warning: Rebuilding tensorflow graph..."
    ## [1] "Building master readme graph..."
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.02 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.02 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## TensorFlow v2.16.2 (~/.virtualenvs/r-tensorflow/lib/python3.10/site-packages/tensorflow)
    ## Python v3.10 (~/.virtualenvs/r-tensorflow/bin/python)
    ## [1] "Done with this round of training in 0.02 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## TensorFlow v2.16.2 (~/.virtualenvs/r-tensorflow/lib/python3.10/site-packages/tensorflow)
    ## Python v3.10 (~/.virtualenvs/r-tensorflow/bin/python)
    ## [1] "Done with this round of training in 0.02 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.02 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.02 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"
    ## [1] "Done with this round of training in 0.01 minutes!"

    ## [[1]]
    ## 
    ##          0          1          2 
    ##  -5.994926 -52.033951  10.389316 
    ## 
    ## [[2]]
    ## 
    ##          0          1          2 
    ##  -1.591461 -40.736835   7.467267 
    ## 
    ## [[3]]
    ## 
    ##          0          1          2 
    ##  -1.358362 -30.341873   5.887147

Geschätzte prozentuale Anteile:

``` r
estimate
```

    ##         0         1         2 
    ## 0.2352962 0.1512897 0.6134141

Tatsächliche prozentuale Anteile:

``` r
actual
```

    ## 
    ##         0         1         2 
    ## 0.2321429 0.1160714 0.6517857

Abweichung der Schätzung vom tatsächlichen Anteil in Prozent:

``` r
percentages
```

    ## 
    ##          0          1          2 
    ##  -1.358362 -30.341873   5.887147

Es zeigt sich nach drei Durchgängen, dass mit unseren Trainingsdaten die zweite Kategorie (QAnon verbreitend/affirmativ) unterschätzt, die erste Kategorie (QAnon kritisierend/negativ) jedoch überschätzt wird. Auch die Kategorie null (nicht zuordenbar) wird tendenziell unterschätzt. Für die Interpretation ist dies bei der automatischen Kategorisierung der gesamten 11’363 Tweets zu berücksichtigen.

### Automatisierte Schätzung der Tweet-Kategorien

Nach diesem Training kann nun eine Schätzung über sämtliche Tweets versucht werden. Dazu muss erst sämtlicher Text gegen die GloVe-Embeddings analysiert werden.

``` r
# Apply to whole dataset
tweets_all <- tweets %>%
  mutate(trainingset = ifelse(!is.na(code), 1, ifelse(is.na(code), 0, NA)))

# Auskommentiert, da unten von Cache gelesend wird
#wordVec_summaries_all = undergrad(documentText = cleanme(tweets_all$text), wordVecs = wordVecs)
```

Die unkategorisierten Tweets werden nun in einem Loop für jeden Tag im gesamten Zeitraum aufgesplittet. Für jeden Tag wird dann `readme()` aufgerufen. Schlussendlich kann so visualisiert werden, ob und wie sich die Anteile der einzelnen Kategorien mit fortschreitendem zeitlichen Verlauf verändert haben. Da die Berechnung auf meinem Rechner mehr als 3 Stunden in Anspruch genommen hat, habe ich die Resultate in eine JSON-Datei gespeichert und lese für dieses RMarkdown nur die exportierte Datei, statt nochmals alles durchrechnen zu lassen.

``` r
# Parse datetime
tweets_date_sorted <- tweets_all %>% 
  mutate(
    datetime = datetime %>% 
      parse_date_time(orders = ' %Y-%m-%d %H%M%S') # Parse date.
  ) %>%
  mutate(datetime = datetime + 1*60*60) %>% # Set time from UTC to CET.
  filter(!is.na(datetime)) %>%# Remove messed up dates..
  mutate(datetime = datetime %>% round(units = 'days') %>% as.POSIXct()) # Remove the time
```

    ## Warning: There was 1 warning in `mutate()`.
    ## ℹ In argument: `datetime = datetime %>% parse_date_time(orders = " %Y-%m-%d
    ##   %H%M%S")`.
    ## Caused by warning:
    ## !  412 failed to parse.

``` r
# Update coded tweets with trainingset-field
tweets_coded <- tweets_all %>%
  filter(trainingset == 1)

# Group by day
tweet_groups <- tweets_date_sorted %>% group_by(datetime) %>% tally()

# We will do estimates per day, therefore let's encapsulate the estimation in a function
estimate_categories <- function(i){
  # Get the tweets for this date
  tweets_daily <- tweets_date_sorted %>%
    filter(datetime == tweet_groups[i,]$datetime)
  
  # Merge the daily tweets with the coded tweets from all dates - we need these for training..
  tweet_set <- merge(tweets_daily, tweets_coded, all=TRUE)
  
  # Calculate the wordvecs for the tweets for this date
  wordVec_summaries_set = undergrad(documentText = cleanme(tweet_set$text), wordVecs = wordVecs)
  
  # Make the estimation
  estimate <- readme(dfm = wordVec_summaries_set ,
                             labeledIndicator = tweet_set$trainingset,
                             categoryVec = tweet_set$code,
                             verbose = T,
                             diagnostics = T)
  
  # Return result
  return(estimate)
}

# Create a container for the results per day
estimates <- data.frame(date = tweet_groups[1,]$datetime, estimate = readme.estimates$point_readme[1], code = 1, stringsAsFactors = F)

# Caching the results - The algorithm takes about 3-4 hours, I will not let it run again for the RMarkdown file..
estimate_file <- "qanon_readme_estimates_2020-02-01_2020_04_24.json"

if(!file.exists(estimate_file)){
  # Calculate estimates. careful: takes ages! (+3h)
  foreach(i=2:nrow(tweet_groups)) %do% {
    # Call the function
    estimate <- estimate_categories(i) 
    
    # Add results to container
    estimates <- estimates %>% add_row(date = tweet_groups[i,]$datetime, estimate = estimate$point_readme[1], code = 0)
    estimates <- estimates %>% add_row(date = tweet_groups[i,]$datetime, estimate = estimate$point_readme[2], code = 1)
    estimates <- estimates %>% add_row(date = tweet_groups[i,]$datetime, estimate = estimate$point_readme[3], code = 2)
  }
  
  # Remove the first record that was created just for the initialization
  estimates <- estimates[-1,]
  plotable <- estimates %>% 
    pivot_wider(names_from = code, values_from = estimate) # Use pivot_wider from tidyr-Package to make data tidy
  
  # Export results as JSON file
  jsonlite::stream_out(plotable, file(estimate_file), verbose = F)
} else{
  
  # If file exists, load from file
  plotable <- jsonlite::stream_in(file("qanon_readme_estimates_2020-02-01_2020_04_24.json"), verbose = F)  
  plotable <- plotable %>% 
    mutate(
      date = date %>% 
        # Parse date.
        parse_date_time(orders = ' %Y-%m-%d')
    )
}

plotable %<>%
  select(Datum = "date", N_A = "0", Kritisch = "1", Affirmativ = "2") # rename columns

# "Melt" the dates..
long <- melt(plotable, id="Datum")

# prepare plot
plot <- ggplot(data=long,
  aes(x=Datum, y=value, colour=variable)) +
  geom_line() +
  labs(title = 'Automatische Kategorisierung von QAnon-Tweets',
       y = 'Prozentualer Anteil',
       x = 'Datum',
       subtitle = str_c("Total 11'363 Tweets aus dem Zeitraum 01.02.2020-24.04.2020,",
                          "Schätzung durch readme2-Algorithmus"),
       colour = "Kategorien"
       )

#plot
fig <- ggplotly(plot)
fig
```

<div class="plotly html-widget html-fill-item" id="htmlwidget-2" style="width:672px;height:480px;"></div>
<script type="application/json" data-for="htmlwidget-2">{"x":{"data":[{"x":[1580515200,1580601600,1580688000,1580774400,1580860800,1580947200,1581033600,1581120000,1581206400,1581292800,1581379200,1581465600,1581552000,1581638400,1581724800,1581811200,1581897600,1581984000,1582070400,1582156800,1582243200,1582329600,1582416000,1582502400,1582588800,1582675200,1582761600,1582848000,1582934400,1583020800,1583107200,1583193600,1583280000,1583366400,1583452800,1583539200,1583625600,1583712000,1583798400,1583884800,1583971200,1584057600,1584144000,1584230400,1584316800,1584403200,1584489600,1584576000,1584662400,1584748800,1584835200,1584921600,1585008000,1585094400,1585180800,1585267200,1585353600,1585440000,1585526400,1585612800,1585699200,1585785600,1585872000,1585958400,1586044800,1586131200,1586217600,1586304000,1586390400,1586476800,1586563200,1586649600,1586736000,1586822400,1586908800,1586995200,1587081600,1587168000,1587254400,1587340800,1587427200,1587513600,1587600000,1587686400],"y":[0.18171000000000001,0.16028999999999999,0.15687999999999999,0.22983000000000001,0.23880000000000001,0.16386999999999999,0.042639999999999997,0.21901999999999999,0.18398999999999999,0.2203,0.13868,0.14074,0.20433999999999999,0.27722000000000002,0.32406000000000001,0.19538,0.35500999999999999,0.17041000000000001,0.47221999999999997,0.30586999999999998,0.23352999999999999,0.24199000000000001,0.14299000000000001,0.39023000000000002,0.31341999999999998,0.26028000000000001,0.29819000000000001,0.23494000000000001,0.22899,0.23122000000000001,0.24987000000000001,0.30623,0.25417000000000001,0.23174,0.28700999999999999,0.2591,0.36042000000000002,0.29992999999999997,0.27743000000000001,0.33101999999999998,0.32238,0.27739000000000003,0.25851000000000002,0.30074000000000001,0.32963999999999999,0.27134000000000003,0.21140999999999999,0.29071999999999998,0.23577999999999999,0.24920999999999999,0.19120999999999999,0.2767,0.26383000000000001,0.28219,0.24002999999999999,0.26834999999999998,0.22575000000000001,0.25625999999999999,0.2944,0.26556000000000002,0.24537,0.24309,0.24424999999999999,0.25656000000000001,0.23938999999999999,0.24041000000000001,0.23257,0.20352999999999999,0.23594000000000001,0.20524000000000001,0.2185,0.22756999999999999,0.25195000000000001,0.27959000000000001,0.26790000000000003,0.25198999999999999,0.30492000000000002,0.35471000000000003,0.31931999999999999,0.30034,0.36936000000000002,0.30282999999999999,0.40299000000000001,0.40938999999999998],"text":["Datum: 2020-02-01<br />value: 0.18171<br />variable: N_A","Datum: 2020-02-02<br />value: 0.16029<br />variable: N_A","Datum: 2020-02-03<br />value: 0.15688<br />variable: N_A","Datum: 2020-02-04<br />value: 0.22983<br />variable: N_A","Datum: 2020-02-05<br />value: 0.23880<br />variable: N_A","Datum: 2020-02-06<br />value: 0.16387<br />variable: N_A","Datum: 2020-02-07<br />value: 0.04264<br />variable: N_A","Datum: 2020-02-08<br />value: 0.21902<br />variable: N_A","Datum: 2020-02-09<br />value: 0.18399<br />variable: N_A","Datum: 2020-02-10<br />value: 0.22030<br />variable: N_A","Datum: 2020-02-11<br />value: 0.13868<br />variable: N_A","Datum: 2020-02-12<br />value: 0.14074<br />variable: N_A","Datum: 2020-02-13<br />value: 0.20434<br />variable: N_A","Datum: 2020-02-14<br />value: 0.27722<br />variable: N_A","Datum: 2020-02-15<br />value: 0.32406<br />variable: N_A","Datum: 2020-02-16<br />value: 0.19538<br />variable: N_A","Datum: 2020-02-17<br />value: 0.35501<br />variable: N_A","Datum: 2020-02-18<br />value: 0.17041<br />variable: N_A","Datum: 2020-02-19<br />value: 0.47222<br />variable: N_A","Datum: 2020-02-20<br />value: 0.30587<br />variable: N_A","Datum: 2020-02-21<br />value: 0.23353<br />variable: N_A","Datum: 2020-02-22<br />value: 0.24199<br />variable: N_A","Datum: 2020-02-23<br />value: 0.14299<br />variable: N_A","Datum: 2020-02-24<br />value: 0.39023<br />variable: N_A","Datum: 2020-02-25<br />value: 0.31342<br />variable: N_A","Datum: 2020-02-26<br />value: 0.26028<br />variable: N_A","Datum: 2020-02-27<br />value: 0.29819<br />variable: N_A","Datum: 2020-02-28<br />value: 0.23494<br />variable: N_A","Datum: 2020-02-29<br />value: 0.22899<br />variable: N_A","Datum: 2020-03-01<br />value: 0.23122<br />variable: N_A","Datum: 2020-03-02<br />value: 0.24987<br />variable: N_A","Datum: 2020-03-03<br />value: 0.30623<br />variable: N_A","Datum: 2020-03-04<br />value: 0.25417<br />variable: N_A","Datum: 2020-03-05<br />value: 0.23174<br />variable: N_A","Datum: 2020-03-06<br />value: 0.28701<br />variable: N_A","Datum: 2020-03-07<br />value: 0.25910<br />variable: N_A","Datum: 2020-03-08<br />value: 0.36042<br />variable: N_A","Datum: 2020-03-09<br />value: 0.29993<br />variable: N_A","Datum: 2020-03-10<br />value: 0.27743<br />variable: N_A","Datum: 2020-03-11<br />value: 0.33102<br />variable: N_A","Datum: 2020-03-12<br />value: 0.32238<br />variable: N_A","Datum: 2020-03-13<br />value: 0.27739<br />variable: N_A","Datum: 2020-03-14<br />value: 0.25851<br />variable: N_A","Datum: 2020-03-15<br />value: 0.30074<br />variable: N_A","Datum: 2020-03-16<br />value: 0.32964<br />variable: N_A","Datum: 2020-03-17<br />value: 0.27134<br />variable: N_A","Datum: 2020-03-18<br />value: 0.21141<br />variable: N_A","Datum: 2020-03-19<br />value: 0.29072<br />variable: N_A","Datum: 2020-03-20<br />value: 0.23578<br />variable: N_A","Datum: 2020-03-21<br />value: 0.24921<br />variable: N_A","Datum: 2020-03-22<br />value: 0.19121<br />variable: N_A","Datum: 2020-03-23<br />value: 0.27670<br />variable: N_A","Datum: 2020-03-24<br />value: 0.26383<br />variable: N_A","Datum: 2020-03-25<br />value: 0.28219<br />variable: N_A","Datum: 2020-03-26<br />value: 0.24003<br />variable: N_A","Datum: 2020-03-27<br />value: 0.26835<br />variable: N_A","Datum: 2020-03-28<br />value: 0.22575<br />variable: N_A","Datum: 2020-03-29<br />value: 0.25626<br />variable: N_A","Datum: 2020-03-30<br />value: 0.29440<br />variable: N_A","Datum: 2020-03-31<br />value: 0.26556<br />variable: N_A","Datum: 2020-04-01<br />value: 0.24537<br />variable: N_A","Datum: 2020-04-02<br />value: 0.24309<br />variable: N_A","Datum: 2020-04-03<br />value: 0.24425<br />variable: N_A","Datum: 2020-04-04<br />value: 0.25656<br />variable: N_A","Datum: 2020-04-05<br />value: 0.23939<br />variable: N_A","Datum: 2020-04-06<br />value: 0.24041<br />variable: N_A","Datum: 2020-04-07<br />value: 0.23257<br />variable: N_A","Datum: 2020-04-08<br />value: 0.20353<br />variable: N_A","Datum: 2020-04-09<br />value: 0.23594<br />variable: N_A","Datum: 2020-04-10<br />value: 0.20524<br />variable: N_A","Datum: 2020-04-11<br />value: 0.21850<br />variable: N_A","Datum: 2020-04-12<br />value: 0.22757<br />variable: N_A","Datum: 2020-04-13<br />value: 0.25195<br />variable: N_A","Datum: 2020-04-14<br />value: 0.27959<br />variable: N_A","Datum: 2020-04-15<br />value: 0.26790<br />variable: N_A","Datum: 2020-04-16<br />value: 0.25199<br />variable: N_A","Datum: 2020-04-17<br />value: 0.30492<br />variable: N_A","Datum: 2020-04-18<br />value: 0.35471<br />variable: N_A","Datum: 2020-04-19<br />value: 0.31932<br />variable: N_A","Datum: 2020-04-20<br />value: 0.30034<br />variable: N_A","Datum: 2020-04-21<br />value: 0.36936<br />variable: N_A","Datum: 2020-04-22<br />value: 0.30283<br />variable: N_A","Datum: 2020-04-23<br />value: 0.40299<br />variable: N_A","Datum: 2020-04-24<br />value: 0.40939<br />variable: N_A"],"type":"scatter","mode":"lines","line":{"width":1.8897637795275593,"color":"rgba(248,118,109,1)","dash":"solid"},"hoveron":"points","name":"N_A","legendgroup":"N_A","showlegend":true,"xaxis":"x","yaxis":"y","hoverinfo":"text","frame":null},{"x":[1580515200,1580601600,1580688000,1580774400,1580860800,1580947200,1581033600,1581120000,1581206400,1581292800,1581379200,1581465600,1581552000,1581638400,1581724800,1581811200,1581897600,1581984000,1582070400,1582156800,1582243200,1582329600,1582416000,1582502400,1582588800,1582675200,1582761600,1582848000,1582934400,1583020800,1583107200,1583193600,1583280000,1583366400,1583452800,1583539200,1583625600,1583712000,1583798400,1583884800,1583971200,1584057600,1584144000,1584230400,1584316800,1584403200,1584489600,1584576000,1584662400,1584748800,1584835200,1584921600,1585008000,1585094400,1585180800,1585267200,1585353600,1585440000,1585526400,1585612800,1585699200,1585785600,1585872000,1585958400,1586044800,1586131200,1586217600,1586304000,1586390400,1586476800,1586563200,1586649600,1586736000,1586822400,1586908800,1586995200,1587081600,1587168000,1587254400,1587340800,1587427200,1587513600,1587600000,1587686400],"y":[0.01485,0.16394,0.078229999999999994,0.054089999999999999,0.038260000000000002,0.072069999999999995,0.057529999999999998,0.033390000000000003,0.092740000000000003,0.113,0.089719999999999994,0.13478000000000001,0.13253999999999999,0.071300000000000002,0.043110000000000002,0.047399999999999998,0.068989999999999996,0.033329999999999999,0.069690000000000002,0.20877999999999999,0.30636999999999998,0.22464999999999999,0.11856999999999999,0.15240999999999999,0.097229999999999997,0.10527,0.10826,0.094670000000000004,0.069120000000000001,0.091230000000000006,0.072370000000000004,0.059310000000000002,0.07936,0.1177,0.051229999999999998,0.11902,0.07528,0.070720000000000005,0.10143000000000001,0.097769999999999996,0.11259,0.11545,0.12781000000000001,0.10842,0.11650000000000001,0.16442000000000001,0.15937000000000001,0.16705999999999999,0.18357000000000001,0.11860999999999999,0.12443,0.16472000000000001,0.11459999999999999,0.15039,0.15024999999999999,0.10188,0.11733,0.12572,0.14274999999999999,0.16372,0.15690000000000001,0.14632999999999999,0.28550999999999999,0.23838999999999999,0.24248,0.20977000000000001,0.22472,0.25658999999999998,0.14827000000000001,0.26694000000000001,0.18947,0.19699,0.20416000000000001,0.26501999999999998,0.22644,0.17119000000000001,0.26611000000000001,0.24798000000000001,0.19466,0.30191000000000001,0.21615000000000001,0.23216000000000001,0.31019000000000002,0.28605999999999998],"text":["Datum: 2020-02-01<br />value: 0.01485<br />variable: Kritisch","Datum: 2020-02-02<br />value: 0.16394<br />variable: Kritisch","Datum: 2020-02-03<br />value: 0.07823<br />variable: Kritisch","Datum: 2020-02-04<br />value: 0.05409<br />variable: Kritisch","Datum: 2020-02-05<br />value: 0.03826<br />variable: Kritisch","Datum: 2020-02-06<br />value: 0.07207<br />variable: Kritisch","Datum: 2020-02-07<br />value: 0.05753<br />variable: Kritisch","Datum: 2020-02-08<br />value: 0.03339<br />variable: Kritisch","Datum: 2020-02-09<br />value: 0.09274<br />variable: Kritisch","Datum: 2020-02-10<br />value: 0.11300<br />variable: Kritisch","Datum: 2020-02-11<br />value: 0.08972<br />variable: Kritisch","Datum: 2020-02-12<br />value: 0.13478<br />variable: Kritisch","Datum: 2020-02-13<br />value: 0.13254<br />variable: Kritisch","Datum: 2020-02-14<br />value: 0.07130<br />variable: Kritisch","Datum: 2020-02-15<br />value: 0.04311<br />variable: Kritisch","Datum: 2020-02-16<br />value: 0.04740<br />variable: Kritisch","Datum: 2020-02-17<br />value: 0.06899<br />variable: Kritisch","Datum: 2020-02-18<br />value: 0.03333<br />variable: Kritisch","Datum: 2020-02-19<br />value: 0.06969<br />variable: Kritisch","Datum: 2020-02-20<br />value: 0.20878<br />variable: Kritisch","Datum: 2020-02-21<br />value: 0.30637<br />variable: Kritisch","Datum: 2020-02-22<br />value: 0.22465<br />variable: Kritisch","Datum: 2020-02-23<br />value: 0.11857<br />variable: Kritisch","Datum: 2020-02-24<br />value: 0.15241<br />variable: Kritisch","Datum: 2020-02-25<br />value: 0.09723<br />variable: Kritisch","Datum: 2020-02-26<br />value: 0.10527<br />variable: Kritisch","Datum: 2020-02-27<br />value: 0.10826<br />variable: Kritisch","Datum: 2020-02-28<br />value: 0.09467<br />variable: Kritisch","Datum: 2020-02-29<br />value: 0.06912<br />variable: Kritisch","Datum: 2020-03-01<br />value: 0.09123<br />variable: Kritisch","Datum: 2020-03-02<br />value: 0.07237<br />variable: Kritisch","Datum: 2020-03-03<br />value: 0.05931<br />variable: Kritisch","Datum: 2020-03-04<br />value: 0.07936<br />variable: Kritisch","Datum: 2020-03-05<br />value: 0.11770<br />variable: Kritisch","Datum: 2020-03-06<br />value: 0.05123<br />variable: Kritisch","Datum: 2020-03-07<br />value: 0.11902<br />variable: Kritisch","Datum: 2020-03-08<br />value: 0.07528<br />variable: Kritisch","Datum: 2020-03-09<br />value: 0.07072<br />variable: Kritisch","Datum: 2020-03-10<br />value: 0.10143<br />variable: Kritisch","Datum: 2020-03-11<br />value: 0.09777<br />variable: Kritisch","Datum: 2020-03-12<br />value: 0.11259<br />variable: Kritisch","Datum: 2020-03-13<br />value: 0.11545<br />variable: Kritisch","Datum: 2020-03-14<br />value: 0.12781<br />variable: Kritisch","Datum: 2020-03-15<br />value: 0.10842<br />variable: Kritisch","Datum: 2020-03-16<br />value: 0.11650<br />variable: Kritisch","Datum: 2020-03-17<br />value: 0.16442<br />variable: Kritisch","Datum: 2020-03-18<br />value: 0.15937<br />variable: Kritisch","Datum: 2020-03-19<br />value: 0.16706<br />variable: Kritisch","Datum: 2020-03-20<br />value: 0.18357<br />variable: Kritisch","Datum: 2020-03-21<br />value: 0.11861<br />variable: Kritisch","Datum: 2020-03-22<br />value: 0.12443<br />variable: Kritisch","Datum: 2020-03-23<br />value: 0.16472<br />variable: Kritisch","Datum: 2020-03-24<br />value: 0.11460<br />variable: Kritisch","Datum: 2020-03-25<br />value: 0.15039<br />variable: Kritisch","Datum: 2020-03-26<br />value: 0.15025<br />variable: Kritisch","Datum: 2020-03-27<br />value: 0.10188<br />variable: Kritisch","Datum: 2020-03-28<br />value: 0.11733<br />variable: Kritisch","Datum: 2020-03-29<br />value: 0.12572<br />variable: Kritisch","Datum: 2020-03-30<br />value: 0.14275<br />variable: Kritisch","Datum: 2020-03-31<br />value: 0.16372<br />variable: Kritisch","Datum: 2020-04-01<br />value: 0.15690<br />variable: Kritisch","Datum: 2020-04-02<br />value: 0.14633<br />variable: Kritisch","Datum: 2020-04-03<br />value: 0.28551<br />variable: Kritisch","Datum: 2020-04-04<br />value: 0.23839<br />variable: Kritisch","Datum: 2020-04-05<br />value: 0.24248<br />variable: Kritisch","Datum: 2020-04-06<br />value: 0.20977<br />variable: Kritisch","Datum: 2020-04-07<br />value: 0.22472<br />variable: Kritisch","Datum: 2020-04-08<br />value: 0.25659<br />variable: Kritisch","Datum: 2020-04-09<br />value: 0.14827<br />variable: Kritisch","Datum: 2020-04-10<br />value: 0.26694<br />variable: Kritisch","Datum: 2020-04-11<br />value: 0.18947<br />variable: Kritisch","Datum: 2020-04-12<br />value: 0.19699<br />variable: Kritisch","Datum: 2020-04-13<br />value: 0.20416<br />variable: Kritisch","Datum: 2020-04-14<br />value: 0.26502<br />variable: Kritisch","Datum: 2020-04-15<br />value: 0.22644<br />variable: Kritisch","Datum: 2020-04-16<br />value: 0.17119<br />variable: Kritisch","Datum: 2020-04-17<br />value: 0.26611<br />variable: Kritisch","Datum: 2020-04-18<br />value: 0.24798<br />variable: Kritisch","Datum: 2020-04-19<br />value: 0.19466<br />variable: Kritisch","Datum: 2020-04-20<br />value: 0.30191<br />variable: Kritisch","Datum: 2020-04-21<br />value: 0.21615<br />variable: Kritisch","Datum: 2020-04-22<br />value: 0.23216<br />variable: Kritisch","Datum: 2020-04-23<br />value: 0.31019<br />variable: Kritisch","Datum: 2020-04-24<br />value: 0.28606<br />variable: Kritisch"],"type":"scatter","mode":"lines","line":{"width":1.8897637795275593,"color":"rgba(0,186,56,1)","dash":"solid"},"hoveron":"points","name":"Kritisch","legendgroup":"Kritisch","showlegend":true,"xaxis":"x","yaxis":"y","hoverinfo":"text","frame":null},{"x":[1580515200,1580601600,1580688000,1580774400,1580860800,1580947200,1581033600,1581120000,1581206400,1581292800,1581379200,1581465600,1581552000,1581638400,1581724800,1581811200,1581897600,1581984000,1582070400,1582156800,1582243200,1582329600,1582416000,1582502400,1582588800,1582675200,1582761600,1582848000,1582934400,1583020800,1583107200,1583193600,1583280000,1583366400,1583452800,1583539200,1583625600,1583712000,1583798400,1583884800,1583971200,1584057600,1584144000,1584230400,1584316800,1584403200,1584489600,1584576000,1584662400,1584748800,1584835200,1584921600,1585008000,1585094400,1585180800,1585267200,1585353600,1585440000,1585526400,1585612800,1585699200,1585785600,1585872000,1585958400,1586044800,1586131200,1586217600,1586304000,1586390400,1586476800,1586563200,1586649600,1586736000,1586822400,1586908800,1586995200,1587081600,1587168000,1587254400,1587340800,1587427200,1587513600,1587600000,1587686400],"y":[0.80344000000000004,0.67578000000000005,0.76488999999999996,0.71606999999999998,0.72294000000000003,0.76405999999999996,0.89983000000000002,0.74760000000000004,0.72326999999999997,0.66669999999999996,0.77159999999999995,0.72448000000000001,0.66310999999999998,0.65147999999999995,0.63283,0.75722,0.57599999999999996,0.79625999999999997,0.45807999999999999,0.48535,0.46010000000000001,0.53334999999999999,0.73843999999999999,0.45737,0.58935000000000004,0.63444,0.59355000000000002,0.67039000000000004,0.70189000000000001,0.67754999999999999,0.67776000000000003,0.63446000000000002,0.66647000000000001,0.65056000000000003,0.66174999999999995,0.62189000000000005,0.56430000000000002,0.62934999999999997,0.62114000000000003,0.57120000000000004,0.56503000000000003,0.60716000000000003,0.61368,0.59084000000000003,0.55386000000000002,0.56423000000000001,0.62922999999999996,0.54222000000000004,0.58065,0.63217999999999996,0.68435000000000001,0.55857999999999997,0.62156,0.56742000000000004,0.60972000000000004,0.62977000000000005,0.65691999999999995,0.61802000000000001,0.56284999999999996,0.57071000000000005,0.59772999999999998,0.61058000000000001,0.47023999999999999,0.50505999999999995,0.51812999999999998,0.54981999999999998,0.54271000000000003,0.53988000000000003,0.61578999999999995,0.52781,0.59202999999999995,0.57543999999999995,0.54388999999999998,0.45540000000000003,0.50566,0.57682,0.42897000000000002,0.39731,0.48602000000000001,0.39774999999999999,0.41449000000000003,0.46500999999999998,0.28682000000000002,0.30454999999999999],"text":["Datum: 2020-02-01<br />value: 0.80344<br />variable: Affirmativ","Datum: 2020-02-02<br />value: 0.67578<br />variable: Affirmativ","Datum: 2020-02-03<br />value: 0.76489<br />variable: Affirmativ","Datum: 2020-02-04<br />value: 0.71607<br />variable: Affirmativ","Datum: 2020-02-05<br />value: 0.72294<br />variable: Affirmativ","Datum: 2020-02-06<br />value: 0.76406<br />variable: Affirmativ","Datum: 2020-02-07<br />value: 0.89983<br />variable: Affirmativ","Datum: 2020-02-08<br />value: 0.74760<br />variable: Affirmativ","Datum: 2020-02-09<br />value: 0.72327<br />variable: Affirmativ","Datum: 2020-02-10<br />value: 0.66670<br />variable: Affirmativ","Datum: 2020-02-11<br />value: 0.77160<br />variable: Affirmativ","Datum: 2020-02-12<br />value: 0.72448<br />variable: Affirmativ","Datum: 2020-02-13<br />value: 0.66311<br />variable: Affirmativ","Datum: 2020-02-14<br />value: 0.65148<br />variable: Affirmativ","Datum: 2020-02-15<br />value: 0.63283<br />variable: Affirmativ","Datum: 2020-02-16<br />value: 0.75722<br />variable: Affirmativ","Datum: 2020-02-17<br />value: 0.57600<br />variable: Affirmativ","Datum: 2020-02-18<br />value: 0.79626<br />variable: Affirmativ","Datum: 2020-02-19<br />value: 0.45808<br />variable: Affirmativ","Datum: 2020-02-20<br />value: 0.48535<br />variable: Affirmativ","Datum: 2020-02-21<br />value: 0.46010<br />variable: Affirmativ","Datum: 2020-02-22<br />value: 0.53335<br />variable: Affirmativ","Datum: 2020-02-23<br />value: 0.73844<br />variable: Affirmativ","Datum: 2020-02-24<br />value: 0.45737<br />variable: Affirmativ","Datum: 2020-02-25<br />value: 0.58935<br />variable: Affirmativ","Datum: 2020-02-26<br />value: 0.63444<br />variable: Affirmativ","Datum: 2020-02-27<br />value: 0.59355<br />variable: Affirmativ","Datum: 2020-02-28<br />value: 0.67039<br />variable: Affirmativ","Datum: 2020-02-29<br />value: 0.70189<br />variable: Affirmativ","Datum: 2020-03-01<br />value: 0.67755<br />variable: Affirmativ","Datum: 2020-03-02<br />value: 0.67776<br />variable: Affirmativ","Datum: 2020-03-03<br />value: 0.63446<br />variable: Affirmativ","Datum: 2020-03-04<br />value: 0.66647<br />variable: Affirmativ","Datum: 2020-03-05<br />value: 0.65056<br />variable: Affirmativ","Datum: 2020-03-06<br />value: 0.66175<br />variable: Affirmativ","Datum: 2020-03-07<br />value: 0.62189<br />variable: Affirmativ","Datum: 2020-03-08<br />value: 0.56430<br />variable: Affirmativ","Datum: 2020-03-09<br />value: 0.62935<br />variable: Affirmativ","Datum: 2020-03-10<br />value: 0.62114<br />variable: Affirmativ","Datum: 2020-03-11<br />value: 0.57120<br />variable: Affirmativ","Datum: 2020-03-12<br />value: 0.56503<br />variable: Affirmativ","Datum: 2020-03-13<br />value: 0.60716<br />variable: Affirmativ","Datum: 2020-03-14<br />value: 0.61368<br />variable: Affirmativ","Datum: 2020-03-15<br />value: 0.59084<br />variable: Affirmativ","Datum: 2020-03-16<br />value: 0.55386<br />variable: Affirmativ","Datum: 2020-03-17<br />value: 0.56423<br />variable: Affirmativ","Datum: 2020-03-18<br />value: 0.62923<br />variable: Affirmativ","Datum: 2020-03-19<br />value: 0.54222<br />variable: Affirmativ","Datum: 2020-03-20<br />value: 0.58065<br />variable: Affirmativ","Datum: 2020-03-21<br />value: 0.63218<br />variable: Affirmativ","Datum: 2020-03-22<br />value: 0.68435<br />variable: Affirmativ","Datum: 2020-03-23<br />value: 0.55858<br />variable: Affirmativ","Datum: 2020-03-24<br />value: 0.62156<br />variable: Affirmativ","Datum: 2020-03-25<br />value: 0.56742<br />variable: Affirmativ","Datum: 2020-03-26<br />value: 0.60972<br />variable: Affirmativ","Datum: 2020-03-27<br />value: 0.62977<br />variable: Affirmativ","Datum: 2020-03-28<br />value: 0.65692<br />variable: Affirmativ","Datum: 2020-03-29<br />value: 0.61802<br />variable: Affirmativ","Datum: 2020-03-30<br />value: 0.56285<br />variable: Affirmativ","Datum: 2020-03-31<br />value: 0.57071<br />variable: Affirmativ","Datum: 2020-04-01<br />value: 0.59773<br />variable: Affirmativ","Datum: 2020-04-02<br />value: 0.61058<br />variable: Affirmativ","Datum: 2020-04-03<br />value: 0.47024<br />variable: Affirmativ","Datum: 2020-04-04<br />value: 0.50506<br />variable: Affirmativ","Datum: 2020-04-05<br />value: 0.51813<br />variable: Affirmativ","Datum: 2020-04-06<br />value: 0.54982<br />variable: Affirmativ","Datum: 2020-04-07<br />value: 0.54271<br />variable: Affirmativ","Datum: 2020-04-08<br />value: 0.53988<br />variable: Affirmativ","Datum: 2020-04-09<br />value: 0.61579<br />variable: Affirmativ","Datum: 2020-04-10<br />value: 0.52781<br />variable: Affirmativ","Datum: 2020-04-11<br />value: 0.59203<br />variable: Affirmativ","Datum: 2020-04-12<br />value: 0.57544<br />variable: Affirmativ","Datum: 2020-04-13<br />value: 0.54389<br />variable: Affirmativ","Datum: 2020-04-14<br />value: 0.45540<br />variable: Affirmativ","Datum: 2020-04-15<br />value: 0.50566<br />variable: Affirmativ","Datum: 2020-04-16<br />value: 0.57682<br />variable: Affirmativ","Datum: 2020-04-17<br />value: 0.42897<br />variable: Affirmativ","Datum: 2020-04-18<br />value: 0.39731<br />variable: Affirmativ","Datum: 2020-04-19<br />value: 0.48602<br />variable: Affirmativ","Datum: 2020-04-20<br />value: 0.39775<br />variable: Affirmativ","Datum: 2020-04-21<br />value: 0.41449<br />variable: Affirmativ","Datum: 2020-04-22<br />value: 0.46501<br />variable: Affirmativ","Datum: 2020-04-23<br />value: 0.28682<br />variable: Affirmativ","Datum: 2020-04-24<br />value: 0.30455<br />variable: Affirmativ"],"type":"scatter","mode":"lines","line":{"width":1.8897637795275593,"color":"rgba(97,156,255,1)","dash":"solid"},"hoveron":"points","name":"Affirmativ","legendgroup":"Affirmativ","showlegend":true,"xaxis":"x","yaxis":"y","hoverinfo":"text","frame":null}],"layout":{"margin":{"t":43.762557077625573,"r":7.3059360730593621,"b":40.182648401826498,"l":48.949771689497723},"plot_bgcolor":"rgba(235,235,235,1)","paper_bgcolor":"rgba(255,255,255,1)","font":{"color":"rgba(0,0,0,1)","family":"","size":14.611872146118724},"title":{"text":"Automatische Kategorisierung von QAnon-Tweets","font":{"color":"rgba(0,0,0,1)","family":"","size":17.534246575342465},"x":0,"xref":"paper"},"xaxis":{"domain":[0,1],"automargin":true,"type":"linear","autorange":false,"range":[1580156640,1588044960],"tickmode":"array","ticktext":["Feb","Mar","Apr"],"tickvals":[1580515200,1583020800,1585699200],"categoryorder":"array","categoryarray":["Feb","Mar","Apr"],"nticks":null,"ticks":"outside","tickcolor":"rgba(51,51,51,1)","ticklen":3.6529680365296811,"tickwidth":0.66417600664176002,"showticklabels":true,"tickfont":{"color":"rgba(77,77,77,1)","family":"","size":11.68949771689498},"tickangle":-0,"showline":false,"linecolor":null,"linewidth":0,"showgrid":true,"gridcolor":"rgba(255,255,255,1)","gridwidth":0.66417600664176002,"zeroline":false,"anchor":"y","title":{"text":"Datum","font":{"color":"rgba(0,0,0,1)","family":"","size":14.611872146118724}},"hoverformat":".2f"},"yaxis":{"domain":[0,1],"automargin":true,"type":"linear","autorange":false,"range":[-0.029399000000000002,0.944079],"tickmode":"array","ticktext":["0.00","0.25","0.50","0.75"],"tickvals":[0,0.25,0.49999999999999994,0.75],"categoryorder":"array","categoryarray":["0.00","0.25","0.50","0.75"],"nticks":null,"ticks":"outside","tickcolor":"rgba(51,51,51,1)","ticklen":3.6529680365296811,"tickwidth":0.66417600664176002,"showticklabels":true,"tickfont":{"color":"rgba(77,77,77,1)","family":"","size":11.68949771689498},"tickangle":-0,"showline":false,"linecolor":null,"linewidth":0,"showgrid":true,"gridcolor":"rgba(255,255,255,1)","gridwidth":0.66417600664176002,"zeroline":false,"anchor":"x","title":{"text":"Prozentualer Anteil","font":{"color":"rgba(0,0,0,1)","family":"","size":14.611872146118724}},"hoverformat":".2f"},"shapes":[{"type":"rect","fillcolor":null,"line":{"color":null,"width":0,"linetype":[]},"yref":"paper","xref":"paper","layer":"below","x0":0,"x1":1,"y0":0,"y1":1}],"showlegend":true,"legend":{"bgcolor":"rgba(255,255,255,1)","bordercolor":"transparent","borderwidth":1.8897637795275593,"font":{"color":"rgba(0,0,0,1)","family":"","size":11.68949771689498},"title":{"text":"Kategorien","font":{"color":"rgba(0,0,0,1)","family":"","size":14.611872146118724}}},"hovermode":"closest","barmode":"relative"},"config":{"doubleClick":"reset","modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"source":"A","attrs":{"fa1728a1d5b5":{"x":{},"y":{},"colour":{},"type":"scatter"}},"cur_data":"fa1728a1d5b5","visdat":{"fa1728a1d5b5":["function (y) ","x"]},"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}</script>

Im Plot wird ersichtlich, dass mit der automatischen Schätzung tendenziell eine Abnahme der affirmativen Verbreitung der QAnon-Verschwörungstheorie bei gleichzeitiger Zunahme der kritischen Stimmen festzustellen ist. Gemäss diesen Daten begann eine kritische Auseinandersetzung während der zunehmenden Verbreitung der neuen Verschwörungstheorie erst mit einer gewissen Verzögerung.

## Fazit

Es zeigt sich, dass eine insgesamt quantitative Zunahme eines bestimmten verschwörungstheoretischen Begriffs nicht nur affirmativ bzgl. der Verschwörungstheorie sein muss, sondern immer auch Gegenstimmen beinhaltet. Für fundiertere Aussagen müsste jedoch die Datenbasis genauer überprüft werden. Da die Tweets über die Schlagworte “QAnon” und “wwg1wga” gescraped wurden und zweiterer Begriff wohl vor allem von Befürworter:innen als Codewort verwendet wird, sind die Daten auch möglicherweise in Richtung Affirmation hin verzerrt Auch könnte die Wortzuordnung der word embeddings akkurater sein, vielleicht wäre mit einer Textbereinigung ein besseres Resultat erreichbar. Ausserdem hat sich beim Training gezeigt, dass die affirmative Kategorie systematisch unterschätzt wurde. Da müsste genauer hingeschaut werden. Zu untersuchen wäre auch, wie sich die Verteilung im weiteren Verlauf bis heute entwickelt hat. Dies dürfte sich nun als schwieriger erweisen, da Twitter unterdessen gegen die Verbreitung von QAnon-Inhalten [vorgeht](https://www.tagesschau.de/ausland/twitter-verschwoerungstheorien-101.html).

[^1]: Siehe dazu z.B. [“QAnon” – der Aufstieg einer gefährlichen Verschwörungstheorie](https://www.rnd.de/politik/qanon-der-aufstieg-einer-gefahrlichen-verschworungstheorie-ORTPE4D5YRFRZKVTMJBTFADJTY.html), Redaktionsnetzwerk Deutschland, 1. April 2020, abgerufen am 18. August 2020 oder [Die Verschwörungsfanatiker von QAnon.](https://www.youtube.com/watch?v=9R5TvLCsN-E), Der SPIEGEL, 4. August 2020, abgerufen am 18. August 2020
