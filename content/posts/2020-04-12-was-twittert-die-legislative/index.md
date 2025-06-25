---
title: "Tweets der Legislative zu Corona-Ostern"
author: "Matthias Zaugg"
date: "2020-04-12"
categories: ["Tech"]
tags: ["Quantitative Textanalyse"]
output: html_document
reading_time: FALSE
---










Im Lockdown am Ostersonntag wollte ich wissen, was eigentlich National- und Ständeräte der Schweiz zu dieser Zeit so twittern. Dazu habe ich ein RMarkdown-Skript geschrieben ([Quellcode](https://github.com/nomaad/learnR/blob/master/2020-04-12-was-twittert-die-legislative.Rmd)). Hier die Resultate.

Zuerst ein paar Worte zum Vorgehen. Das [Digital Democracy Lab](https://digdemlab.io/) der Universität Zürich hat für die Wahlen letzten Herbst [zwei Datasets](https://github.com/DigDemLab/chvote19_accounts) mit allen National- und Ständeratskandidat\*innen zusammengetragen. Darin befinden sich auch persönliche Websiten sowie Social-Media-Accounts der Politiker\*innen, sofern sie solche besitzen. Diese Daten habe ich kombiniert mit einer Excel-Datei der aktuellen Ratsmitgliedern von [parlament.ch](https://www.parlament.ch/de/ratsmitglieder). Anschliessend habe ich alle Datensätze ohne Twitter-Account rausgefiltert.

Für jede\*n Politiker\*in mit Twitter-Konto habe ich dann die letzten 10 Tweets über die Twitter-API geladen und mittels Text-Mining die am häufigsten getwitterten Worte in verschiedenen Wordclouds visualisiert. Tweets, welche mehr als 10 Tage alt sind, wurden rausgelöscht. Ausserdem wurden häufige "Stopwords" in Deutsch, Französisch, Italienisch und Englisch rausgefiltert. Und was beschäftigt nun die Legislative auf Bundesebene an Corona-Ostern? Das habe ich mir erst für sämtliche Tweets und dann pro Partei angeschaut. Die Resultate sind selbstverständlich nur eine Momentaufnahme. Nicht nur deshalb, sondern auch wegen der Notwendigkeit der Interpretation (welche bei mir heute zuweilen polemisch ausfiel), könnte das Ergebnis an einem anderen Tag ganz anders aussehen.

# Alle Parteien

Die erste Wordcloud zeigt die häufigsten Worte aus den Tweets sämtlicher Parteien. `COVID` ist mit über 70 Nennungen das am häufigsten erwähnte Wort - welch Wunder. Sowieso erstaunt es wenig, dass das `Coronavirus` und die `Coronakrise` Top-Themen sind. Auch oft erwähnt werden der `Bundesrat` sowie die anlässlich des Coronavirus getroffenen `Massnahmen`.

<img src="{{< blogdown/postref >}}index_files/figure-html/all-1.png" width="672" /><img src="{{< blogdown/postref >}}index_files/figure-html/all-2.png" width="672" />

# Schweizerische Volkspartei (SVP)

Bei der SVP steht in gewohnter Manier die `Schweiz` an erster Stelle. Das `Coronavirus` erscheint hier selbstverständlich auch, aber nicht als Krise. Auch sind die `Massnahmen` des `Bundesrates` und der `Lockdown` ein Thema.

<img src="{{< blogdown/postref >}}index_files/figure-html/svp-1.png" width="672" /><img src="{{< blogdown/postref >}}index_files/figure-html/svp-2.png" width="672" />

# Sozialdemokratische Partei (SP)

Bei der SP `müssen` nun wohl `Massnahmen` ergriffen werden, vermutlich betreffend den `Kitas`. Ganz meine Meinung. Hier wird ausserdem weniger über das Coronavirus getwittert, sondern eher über die davon ausgelöste `Coronakrise` und die Krankheit `COVID`.

<img src="{{< blogdown/postref >}}index_files/figure-html/sp-1.png" width="672" /><img src="{{< blogdown/postref >}}index_files/figure-html/sp-2.png" width="672" />

# Grüne Partei der Schweiz (GPS)

Auch bei den Grünen geht es primär um `COVID`, jedoch kommt zur `Coronakrise` auch noch die `Klimakrise` dazu. Das zeigt sich unter anderem auch an weniger häufig genannten Wörtern wie `savepeoplenotplanes` oder `Luftverkehr`. Spannend finde ich, dass auch bei der zweiten linken Partei der Begriff `müssen` unter den häufigsten Wörtern vorkommt. Ausserdem geht es auch bei den Grünen um `Massnahmen` und den `Bundesrat`.

<img src="{{< blogdown/postref >}}index_files/figure-html/gruene-1.png" width="672" /><img src="{{< blogdown/postref >}}index_files/figure-html/gruene-2.png" width="672" />

# Grüneliberale Partei (glp)

Bei den Grünliberalen geht es anscheinend um Geld, nämlich um `Kredite`. Womöglich braucht es für deren Vergabe `Kriterien` des `Bundesrat` während dieser `Krise`?

<img src="{{< blogdown/postref >}}index_files/figure-html/glp-1.png" width="672" /><img src="{{< blogdown/postref >}}index_files/figure-html/glp-2.png" width="672" />

# FDP.Die Liberalen (FDP)

Die Liberalen erwähnen mit `fdpliberalen` und `fdpag` vor allem sich selber (Will die FDP nun eine AG werden will? Würde mich ja nicht erstaunen. Aber vielleicht geht's dann doch eher nur um den Kanton Aargau.). Ansonsten ist auch hier `COVID` und die `Coronakrise` Top-Thema, wie auch der Bundesrat (hier aber in marktliberaler Effizienz abgekürzt als `br`). Und was ist das denn? Ein Ja zur Sicherheit (`sicherheitja`)? Wie das wohl zu verstehen ist? Egal, der Markt wird es schon regeln.

<img src="{{< blogdown/postref >}}index_files/figure-html/fdp-1.png" width="672" /><img src="{{< blogdown/postref >}}index_files/figure-html/fdp-2.png" width="672" />

# Christlichdemokratische Volkspartei (CVP)

Nicht vergessen gehen sollte bei alledem, dass heute ein Feiertag ist. Die CVP vergisst das nicht. Wie von guten Katholiken nicht anders zu erwarten, steht `Ostern` an erster Stelle. Nicht mal `COVID` ist wichtiger, obwohl die beiden Begriffe Kopf an Kopf an der Spitze liegen. Die `Schweiz` liegt hier zwar nicht ganz so weit vorne wie bei der SVP, aber doch auch auf Rang 3. Ausserdem wird auch hier über den `Bundesrat` und Corona in verschiedenen Varianten gezwitschert. Des weiteren taucht ein neuer Akteur auf: die `Armee`. Militärhelme eignen sich bestimmt hervorragend zum "Eiertütschen" in Selbstisolation. Frohe Ostern! 

<img src="{{< blogdown/postref >}}index_files/figure-html/cvp-1.png" width="672" /><img src="{{< blogdown/postref >}}index_files/figure-html/cvp-2.png" width="672" />



