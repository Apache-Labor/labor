##Title: OWASP ModSecurity Core Rules Tunen

###Was machen wir?

Wir reduzieren die False Positives einer ModSecurity Core Rules Installation und setzen danach die Anomalie-Limite tief an, um Angreifer erfolgreich abzuwehren.

###Warum tun wir das?

Eine frische ModSecurity Installation
   * False Positives reduzieren
      * Um die Limite soweit reduzieren zu können, dass die Regeln einen wirklichen Schutz bieten
      * Klaren Blick auf die relevanten Angriffe zu erhalten

###Schritt 1: Die False Positives quantifizieren

Anomalie Score von sämtlichen Requests abbilden
Hohe Scores in Beziehung zu niedrigen Scores setzen
Quantitative Aussage wie viele Requests eine bestimmte Limite blockieren würde.

###Schritt 2: Die False Positives visualisieren

Abbilden der Scores in einem Graphen.
   x: score
   y: Anzahl Requests mit diesem Score

###Schritt 3: Wesentliche False Positives identifizieren

Qualitativ wichtig: Cluster mit erhöhten Anomaly Scores
Quantitativ wichtig: Die versperren den Blick

###Schritt 4: Auf verletzte ModSec Core Rules zurückschliessen

Relevante Request-IDs extrahieren
alid

###Schritt 5: Verletzte Core Rules punktuell unterdrücken: Für bestimmte Pfade

###Schritt 5: Verletzte Core Rules punktuell unterdrücken: Für bestimmte Parameter

###Schritt 5: Verletzte Core Rules punktuell unterdrücken: Für bestimmte Pfad-Parameter Kombinationen

###Schritt 6: Repetieren

Wiederholen für nächste Gruppe von relevanten false Positives

###Schritt 7: Anomalie-Limite tiefer setzen

Die getunten Regeln einige Tage beobachten
Wenn die Scores sich wie gewünscht bewegen, dann Limite reduzieren

Faustregel: Maximal einer von 10'000 Requests darf als false positive blockiert werden.

###Schritt 8: Repetieren

Tuning-Prozess in meheren Iterationen durchführen.
Limite Schritt um Schritt reduzieren.
10 scheint für einen Standard-Service eine gute Limite
Wenn sensible Daten mit besonderem Schutzbedarf betroffen sind, dann sollte die Limite maximal 5 betragen

Normalerweise kann man einen Service in 3-4 Iterationen auf eine Limite von 10 und mit zwei weiteren Iterationen recht bequem auf eine Limite von 5 bringen.

Für eine mittelgrosse Applikation werden typischerweise 20-30 Ignore-Rules nötig.

###Bonus: Rascher einen Überblick gewinnen

Extraction loop über modsec-positive-rulereport.txt

###Verweise
- <a href="http://blog.spiderlabs.com/2011/08/modsecurity-advanced-topic-of-the-week-exception-handling.html">Spider Labs Blog Post: Exception Handling
