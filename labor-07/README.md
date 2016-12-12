##Fehlalarme im OWASP ModSecurity Core Rule Set behandeln

###Was machen wir?

Wir reduzieren die *False Positives* einer frischen *OWASP ModSecurity Core Rules* Installation und setzen dabei die Anomalie-Limite Schritt um Schritt tiefer, um Angreifer erfolgreich abzuwehren.

###Warum tun wir das?

Eine frische *Core Rule Set* Installation weist typischerweise einige Fehlalarme auf. In speziellen Fällen, namentlich auf höheren Paranoia Stufen, geht das bisweilen in die Tausende. Wir haben in der letzten Lektion verschiedene Techniken gesehen, wie man einzelne Fehlalarme zukünftig unterdrücken kann. Aber aller Anfang ist schwer und was fehlt ist eine Strategie, mit der schieren Menge der Fehlalarme fertig zu werden. Die Reduktion der Fehlalarme ist die Voraussetzung für die Reduktion der Anomalie-Limite der *Core Rules* und dies wiederum ist nötig, um Angreifer mittels *ModSecurity* tatsächlich abzuwehren. Und nur wenn die Fehlalarme wirklich ausgeschaltet oder zumindest sehr weit zurückgedrängt sind, erhalten wir einen Blick auf die tatsächlichen Angreifer.

###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](https://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/) erstellt.
* Verständnis der minimalen Konfiguration in [Anleitung 2 (Apache minimal konfigurieren)](https://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/).
* Ein Apache Webserver mit SSL-/TLS-Unterstützung wie in [Anleitung 4 (Konfigurieren eines SSL Servers)](https://www.netnea.com/cms/apache-tutorial-4-ssl-server-konfigurieren/)
* Ein Apache Webserver mit erweitertem Zugriffslog wie in [Anleitung 5 (Das Zugriffslog Ausbauen und Auswerten)](https://www.netnea.com/cms/apache-tutorial-5-zugriffslog-ausbauen/)
* Ein Apache Webserver mit ModSecurity wie in [Anleitung 6 (ModSecurity einbinden)](https://www.netnea.com/cms/apache-tutorial-6-modsecurity-einbinden/)
* Ein Apache Webserver mit einer Core Rules Installation wie in [Anleitung 7 (Core Rules einbinden)](https://www.netnea.com/cms/apache-tutorial-7-modsecurity-core-rules-einbinden/)

Es macht keinen Sinn, False Positives auf einem Labor Server ohne jeglichen Verkehr zu bekämpfen. Was wir brauchen, ist ein echter Satz von Fehlalarmen. Damit können wir das Schreiben von Rule Exclusions einüben und die Meldungen nach und nach verschwinden lassen. Ich habe zwei solche Dateien vorbereitet:

* [labor-07-example-access.log](https://www.netnea.com/files/labor-07-example-access.log)
* [labor-07-example-error.log](https://www.netnea.com/files/labor-07-example-error.log)

Es ist schwierig, reale Logfiles von einem Produktionsserver für eine Übung zu verwenden. Die Menge an sensitiven Daten in den Logs ist einfach zu gross. Deshalb habe ich frische False Positives produziert. Mit dem Core Rule Set 2.2.x wäre das einfach gewesen, aber mit dem Release 3.0 (CRS3) sind die meisten Fehlalarme in der Standardinstallation ausgemerzt. Ich habe deshalb das CRS auf Paranoia Level 4 gesetzt und eine lokale Drupal-Website installiert. Ich habe auf dieser Installation ein paar Artikel publiziert und sie im Browser gelesen. Diesen Vorgang habe ich mehrere Male wiederholt, bis ich 10'000 Requests im Access Log beisammen hatte.

Drupal und CRS stehen nicht wirklich in einer liebevollen Beziehung. Immer wenn die beiden Software-Pakete aufeinander treffen, neigen sie dazu, aggressiv aufeinander loszugehen: Das CRS ist so pedantisch und Drupal hat unter anderem die Gewohnheit, Parameternamen in eckige Klammern zu setzen, was das CRS wiederum verrückt macht. Allerdings hat die Sache sich mit CRS3 merklich entspannt und namentlich die neuen, optionalen Ausschlussregeln für Drupal (siehe die Datei "crs-setup.conf" für Details und [diesen Blogpost](/cms/2016/11/22/securing-drupal-with-modsecurity-and-the-core-rule-set-crs3/) als Einführung) lassen die verbleibenden Fehlalarme einer Drupal Core Installation fast alle verschwinden.

Aber die Lage sieht gänzlich anders aus, wenn wir diese Rule Exclusions nicht verwenden und wenn wir den Paranoia Level auf 4 erhöhen: Für die 10.000 Anfragen in meinem Testlauf erhielt ich über 27'000 falsche Alarme. Das sollte erst mal reichen für eine Trainingseinheit.

###Schritt 1: Eine Strategie zur Behandlung der Fehlalarme festlegen

Das Problem mit den False Positives ist, dass sie einen im schlimmsten Fall wie eine Lawine überschwemmen und man nicht weiss, wo man mit dem Aufräumen beginnen soll. Was uns fehlt, ist ein Plan und es gibt keine offizielle Dokumentation, welche einem in diesem Punkt weiterhilft. Hier deshalb ein empfohlenes Vorgehen zur Bekämpfung von Fehlalarmen:

* Von Beginn weg im Blocking Mode arbeiten
* Die Anfragen mit den höchsten Anomalie-Werten kommen zuerst
* Wir Tunen in mehreren Durchgängen

Was bedeutet das? Die CRS Default-Installation erfolgt bereits im Blocking Mode und mit einem Anomalie Grenzwert von 5 für die ankommenden Anfragen. Das ist in der Tat ein sehr gutes Ziel für unsere Arbeit, aber es ist ein allzu steiler Einstieg auf einem bestehenden Produktionsserver. Das Risiko ist, dass ein False Positive einen Alarm auslöst, der Browser des falschen Kunden gesperrt wird, ein Telefonanruf an den Applikationsverantwortlichen erfolgt und der Administrator gezwungen wird, die Web Application Firewall auszuschalten. In zahlreichen Installationen, die ich gesehen habe, war dies das Ende der Geschichte.

Das muss nicht sein! Stattdessen starten wir mit einer hohen Anomalie-Limite. Sagen wir 1000 für die Anfragen und aus Symmetrie-Gründen auch 1000 für die Antworten (in der Praxis gehen die Responses nicht sehr hoch). Auf diese Weise wissen wir, dass kein Kunde jemals durch die Limiten blockiert wird, wir erhalten die Meldungen betreffend der Fehlalarme und wir gewinnen Zeit, sie auszumerzen.

Wenn man ein geeignetes Sicherheitsprogramm haben, lässt sich das alles in einer umfangreichen Testphase durchführen, so dass der Service nie ohne strikte Konfiguration in der Produktion eingesetzt wird. Aber wenn man mit ModSecurity auf einem bestehenden Produktions-Service beginnt, dann ist der Start mit einem hohen Schwellenwert in der Produktion die bevorzugte Methode mit minimalen Auswirkungen für bestehende Kunden zu einem sauberen Setup zu kommen (null Auswirkungen, wenn wir sauber arbeiten).

Das Problem bei der Integration von ModSecurity in die Produktion ist die Tatsache, dass False Positives und reale Alarme miteinander vermischt werden. Um die Installation zu säubern, müssen die beiden Gruppen getrennt werden, damit wir wirklich mit den False Positives arbeiten können. Das ist nicht immer einfach. Manuelle Überprüfung hilft, eine Beschränkung auf bekannte IP-Adressen, Pre-Authentifizierung, Test / Tuning auf einem vom Internet getrennten Test-System, Filterung des Access-Protokolls mittels GeoIP, etc ... Es ist ein weites Feld und allgemeine Empfehlungen zu machen ist schwierig. Aber die Frage ist wirklich sehr wichtig. Vor Jahren etwa habe ich das Schreiben einer Rule Exclusion in einem Workshop demonstriert. Und wie sich zeigte, war der vermeintliche Fehlalarm, den ich als Beispiel benützte, ein richtiger Angriff. Ich habe meine Lektion gelernt.

Dann gibt es noch eine zweite Frage, die wir aus dem Weg räumen müssen: Führt das Umgehen von Regeln nicht eigentlich zur einer Verminderung der Sicherheit einer online Applikation? Ja das tut es tatsächlich. Aber wir müssen die Sache in der richtigen Perspektive betrachten. In einem idealen Setup sind alle Regeln voll intakt, der Paranoia Level steht auf der höchsten Stufe (es sind also total knapp 200 zum Teil sehr aggressive Regeln aktiv) und die Anomalie-Limiten wären sehr niedrig. Und dennoch würde die Anwendung ohne jegliche Probleme laufen. Aber in der Praxis funktioniert das nur in den seltensten Fälle. Wenn wir die Anomalies Limiten erhöhen, dann sind die Alarme noch da, aber die Angreifer sind nicht mehr betroffen. Wenn wir den Paranoia Level reduzieren, deaktivieren wir Dutzende von Regeln mit dieser Einstellung. Wenn wir mit den Entwicklern über die Änderung ihrer Software sprechen, so dass die False Positives weggehen, verbringen wir viel Zeit, ohne grosse Chancen auf Erfolg (zumindest in meiner Erfahrung). Die Deaktivierung einer einzigen Regel aus einem Satz von 200 Regeln ist die beste aller schlechten Lösungen. Die schlechteste aller schlechten Lösungen wäre es hingegen, ModSecurity insgesamt zu deaktivieren. Und da dies in vielen Organisationen die Realität ist, deaktiviere ich lieber einzelne Regeln aufgrund von Fehlalarmen, als ich das Risiko eingehe, die WAF ganz rausnehmen zu müssen.

###Schritt 2: Einen Überblick erhalten

Der Charakter der Anwendung, der Paranoia Level und die Menge des Verkehrs alle beeinflussen die Menge an False Positives, die wir in den Logfiles erhalten. Im ersten Durchlauf reichen ein paar tausend oder maximal hunderttausend Anfragen. Sobald das im Access Log zusammengekommen ist, ist es Zeit, die Einträge zu inspizieren. Verschaffen wir uns also einen Überblick über die Lage: Schauen wir uns die Beispiel-Logs einmal an!

Man könnte nun meinen, dass das Error Log mit den Alarmen der richtige Ort für den Start sei. Aber wir schauen uns zuerst das Access Log an. Wir haben das Format dieser Datei so definiert, dass sie uns die Anomalie Werte für jede Anfrage liefert. Dies hilft uns mit diesem Schritt.

In der vorherigen Anleitung verwendeten wir das Skript [modsec-positive-stats.rb](https://www.netnea.com/files/modsec-positive-stats.rb). Wir kehren zu diesem Skript mit dem Beispiel Access Log als Parameter zurück:

```bash
$> cat tutorial-8-example-access.log | alscores | modsec-positive-stats.rb
INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with incoming score of   0 |   5583 |  55.8300% |  55.8300% |  44.1700%
Reqs with incoming score of   1 |      0 |   0.0000% |  55.8300% |  44.1700%
Reqs with incoming score of   2 |      0 |   0.0000% |  55.8300% |  44.1700%
Reqs with incoming score of   3 |      0 |   0.0000% |  55.8300% |  44.1700%
Reqs with incoming score of   4 |      0 |   0.0000% |  55.8300% |  44.1700%
Reqs with incoming score of   5 |     30 |   0.3000% |  56.1300% |  43.8700%
Reqs with incoming score of   6 |      0 |   0.0000% |  56.1300% |  43.8700%
Reqs with incoming score of   7 |      0 |   0.0000% |  56.1300% |  43.8700%
Reqs with incoming score of   8 |      1 |   0.0100% |  56.1399% |  43.8601%
Reqs with incoming score of   9 |      0 |   0.0000% |  56.1399% |  43.8601%
Reqs with incoming score of  10 |   3194 |  31.9400% |  88.0800% |  11.9200%
Reqs with incoming score of  11 |      0 |   0.0000% |  88.0800% |  11.9200%
Reqs with incoming score of  12 |      0 |   0.0000% |  88.0800% |  11.9200%
Reqs with incoming score of  13 |      0 |   0.0000% |  88.0800% |  11.9200%
Reqs with incoming score of  14 |      0 |   0.0000% |  88.0800% |  11.9200%
Reqs with incoming score of  15 |      0 |   0.0000% |  88.0800% |  11.9200%
Reqs with incoming score of  16 |      0 |   0.0000% |  88.0800% |  11.9200%
Reqs with incoming score of  17 |      0 |   0.0000% |  88.0800% |  11.9200%
Reqs with incoming score of  18 |      0 |   0.0000% |  88.0800% |  11.9200%
Reqs with incoming score of  19 |      0 |   0.0000% |  88.0800% |  11.9200%
Reqs with incoming score of  20 |     56 |   0.5599% |  88.6400% |  11.3600%
Reqs with incoming score of  21 |      0 |   0.0000% |  88.6400% |  11.3600%
Reqs with incoming score of  22 |      0 |   0.0000% |  88.6400% |  11.3600%
Reqs with incoming score of  23 |      0 |   0.0000% |  88.6400% |  11.3600%
Reqs with incoming score of  24 |      0 |   0.0000% |  88.6400% |  11.3600%
Reqs with incoming score of  25 |      0 |   0.0000% |  88.6400% |  11.3600%
Reqs with incoming score of  26 |      0 |   0.0000% |  88.6400% |  11.3600%
Reqs with incoming score of  27 |      0 |   0.0000% |  88.6400% |  11.3600%
Reqs with incoming score of  28 |      0 |   0.0000% |  88.6400% |  11.3600%
Reqs with incoming score of  29 |      0 |   0.0000% |  88.6400% |  11.3600%
Reqs with incoming score of  30 |     77 |   0.7700% |  89.4100% |  10.5900%
Reqs with incoming score of  31 |      0 |   0.0000% |  89.4100% |  10.5900%
Reqs with incoming score of  32 |      0 |   0.0000% |  89.4100% |  10.5900%
Reqs with incoming score of  33 |      0 |   0.0000% |  89.4100% |  10.5900%
Reqs with incoming score of  34 |      0 |   0.0000% |  89.4100% |  10.5900%
Reqs with incoming score of  35 |     77 |   0.7700% |  90.1799% |   9.8201%
Reqs with incoming score of  36 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  37 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  38 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  39 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  40 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  41 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  42 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  43 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  44 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  45 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  46 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  47 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  48 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  49 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  50 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  51 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  52 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  53 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  54 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  55 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  56 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  57 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  58 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  59 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  60 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  61 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  62 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  63 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  64 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  65 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  66 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  67 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  68 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  69 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  70 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  71 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  72 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  73 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  74 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  75 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  76 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  77 |      0 |   0.0000% |  90.1799% |   9.8201%
Reqs with incoming score of  78 |     77 |   0.7700% |  90.9499% |   9.0501%
Reqs with incoming score of  79 |    449 |   4.4900% |  95.4399% |   4.5601%
Reqs with incoming score of  80 |      0 |   0.0000% |  95.4399% |   4.5601%
Reqs with incoming score of  81 |      0 |   0.0000% |  95.4399% |   4.5601%
Reqs with incoming score of  82 |      0 |   0.0000% |  95.4399% |   4.5601%
Reqs with incoming score of  83 |      0 |   0.0000% |  95.4399% |   4.5601%
Reqs with incoming score of  84 |      0 |   0.0000% |  95.4399% |   4.5601%
Reqs with incoming score of  85 |      0 |   0.0000% |  95.4399% |   4.5601%
Reqs with incoming score of  86 |      0 |   0.0000% |  95.4399% |   4.5601%
Reqs with incoming score of  87 |      0 |   0.0000% |  95.4399% |   4.5601%
Reqs with incoming score of  88 |      0 |   0.0000% |  95.4399% |   4.5601%
Reqs with incoming score of  89 |      0 |   0.0000% |  95.4399% |   4.5601%
Reqs with incoming score of  90 |      0 |   0.0000% |  95.4399% |   4.5601%
Reqs with incoming score of  91 |      0 |   0.0000% |  95.4399% |   4.5601%
Reqs with incoming score of  92 |      0 |   0.0000% |  95.4399% |   4.5601%
Reqs with incoming score of  93 |      1 |   0.0100% |  95.4499% |   4.5501%
Reqs with incoming score of  94 |      0 |   0.0000% |  95.4499% |   4.5501%
Reqs with incoming score of  95 |      0 |   0.0000% |  95.4499% |   4.5501%
Reqs with incoming score of  96 |      0 |   0.0000% |  95.4499% |   4.5501%
Reqs with incoming score of  97 |      0 |   0.0000% |  95.4499% |   4.5501%
Reqs with incoming score of  98 |    448 |   4.4799% |  99.9299% |   0.0701%
Reqs with incoming score of  99 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 100 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 101 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 102 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 103 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 104 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 105 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 106 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 107 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 108 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 109 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 110 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 111 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 112 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 113 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 114 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 115 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 116 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 117 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 118 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 119 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 120 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 121 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 122 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 123 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 124 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 125 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 126 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 127 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 128 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 129 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 130 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 131 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 132 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 133 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 134 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 135 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 136 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 137 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 138 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 139 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 140 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 141 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 142 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 143 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 144 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 145 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 146 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 147 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 148 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 149 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 150 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 151 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 152 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 153 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 154 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 155 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 156 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 157 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 158 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 159 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 160 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 161 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 162 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 163 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 164 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 165 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 166 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 167 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 168 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 169 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 170 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 171 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 172 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 173 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 174 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 175 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 176 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 177 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 178 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 179 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 180 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 181 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 182 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 183 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 184 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 185 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 186 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 187 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 188 |      0 |   0.0000% |  99.9299% |   0.0701%
Reqs with incoming score of 189 |      1 |   0.0100% |  99.9400% |   0.0600%
Reqs with incoming score of 190 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 191 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 192 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 193 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 194 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 195 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 196 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 197 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 198 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 199 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 200 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 201 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 202 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 203 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 204 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 205 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 206 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 207 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 208 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 209 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 210 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 211 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 212 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 213 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 214 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 215 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 216 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 217 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 218 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 219 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 220 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 221 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 222 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 223 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 224 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 225 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 226 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 227 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 228 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 229 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 230 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 231 |      6 |   0.0600% | 100.0000% |   0.0000%

Incoming average:  12.5272    Median   0.0000    Standard deviation  26.2197


OUTGOING                     Num of req. | % of req. |  Sum of % | Missing %
Number of outgoing req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. outgoing score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with outgoing score of   0 |  10000 | 100.0000% | 100.0000% |   0.0000%

Outgoing average:   0.0000    Median   0.0000    Standard deviation   0.0000
```

So haben wir 10'000 Requests und ungefähr Hälfte von ihnen passieren das Regelwerk, ohne irgendeinen Alarm auszulösen. Über 3.000 Anfragen kommen mit einem Anomalie Score von 10 daher. Die restlichen Anfragen formen zwei deutliche Cluster um 79 und 98 Punkte. Dann gibt es einen sehr langen Schwanz mit einigen wenigen Anfragen die einen Höchstwert von 231 notierten. Das sind mehr als 40 kritische Alarme auf einen einzigen Request (eine kritische Warnung gibt 5 Punkte, 40 kritische Alerts geben somit 200 Punkte). Beeindruckend.

Visualisieren wir das:

<img src="/files/tutorial-8-distribution-untuned.png" alt="Untuned Distribution" width="950" height="550" />

_Ein rascher Überblick über die eben generierten Statistiken_

Dieses ist nur ein rasch zusammengeschustertes Diagramm. Aber es zeigt, dass die meisten Anfragen in der Nähe der linken Seite befinden. Sie erzielten keine Treffer, oder sie erzielten genau 10 Punkte. Aber es gibt einige Anfragen mit höheren Punktzahlen und eine Handvoll Ausreisser sehr weit rechts aussen. Wo fangen wir also an?

Wir beginnen bei denjenigen Requests, welche die höchsten Punkte erzielten. Wir beginnen auf der rechten Seite des Graphen! Das macht Sinn, weil wir bereits im Blocking Mode arbeiten und wir die Anomalie Limite reduzieren möchten. Die Gruppe von Anfragen, die uns dabei zuerst im Weg stehen, sind die sechs Anfragen mit einer Punktzahl von 231 und der Einzelrequest mit einer Punktzahl von 189. Schreiben wir also Rule Exclusions, um die Alarme, die zu diesen Werten führen, zu unterdrücken.


###Schritt 3: Die erste Gruppe von Regelausschlüssen

Um herauszufinden, welche Regeln hinter den Anomaliescores 231 und 189 stehen, müssen wir das Access Log mit dem Error Log verknüpfen. Die Unique ID ist der Link, der uns dabei hilft:

```bash
$> egrep " (231|189) [0-9-]+$" tutorial-8-example-access.log | alreqid | tee ids
WBuxz38AAQEAAEdWQ5UAAACH
WBux0H8AAQEAAEdWQ7QAAACT
WBux0H8AAQEAAEdS9vYAAAAW
WBux0H8AAQEAAEdWQ7kAAACE
WBux0H8AAQEAAEdTojoAAABW
WBux0H8AAQEAAEdS9v4AAAAA
WBux0H8AAQEAAEdTokEAAABL
```

Auf diesem Einzeiler greppen wir nach den Anfragen mit der Punktzahl 231 oder 189 in den Requests. Wir wissen, dass dieser Wert von hinten gezählt der zweite Wert des Access Logs ist. Der letzte Wert ist der Anomalie Score der Antwort. In unserem Fall erzielten alle Antworten 0, aber theoretisch könnte dieser Wert eine beliebige Zahl oder undefiniert (-> `-`) annehmen, so dass es im Allgemeinen eine gute Praxis ist, das Muster auf diese Weise zu schreiben. Der Alias *alreqid* extrahiert die eindeutige ID und *tee* zeigt uns die IDs und schreibt sie gleichzeitig in die Datei *ids*.

Wir können dann die IDs aus dieser Datei verwenden, um diejenigen Alarme zu extrahieren, die zu diesen Requests gehören. Wir verwenden `grep -f`, um diesen Schritt auszuführen. Das `-F`-Flag sagt *grep*, dass unsere Musterdatei tatsächlich eine Liste von festen Zeichenketten ist, die durch Zeilenumbrüche getrennt sind. Solchermassen instruiert arbeitet *grep* viel schneller als ohne das Flag. Der *melidmsg*-Alias extrahiert die ID und die Meldung, die den Alert erklärt. Die Kombination von beiden ist sehr hilfreich. Der bereits bekannte *sucs* alias wird dann verwendet, um die einzelnen Meldungen aufzusummieren.

```bash
$> grep -F -f ids tutorial-8-example-error.log  | melidmsg | sucs
      7 921180 HTTP Parameter Pollution (ARGS_NAMES:ids[])
     12 942450 SQL Hex Encoding Identified
     35 942431 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (6)
     75 942130 SQL Injection Attack: SQL Tautology Detected.
    110 920273 Invalid character in request (outside of very strict set)
    150 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)
```

Das sind also die Bösewichte. Schauen wir sie uns der Reihe nach an. Die Regel 921180 sucht Parameter, die innerhalb eines Requests mehr als einmal übergeben werden (hier *ids[]*). Es ist eine erweiterte Regel, die im CRS3 zum ersten Mal erschien (basierend auf einer Mechanik, die ich selbst entwickelte). Drupal scheint sich so zu verhalten und wir können es nicht ohne weiteres anweisen, dieses Verhalten zu ändern. 942450 sucht nach Zeichenketten des Musters `0x` mit zwei zusätzlichen Hexadezimalziffern. Dies ist eine hexadezimale Kodierung, die auf einen möglichen Exploit hinweisen kann. Das Problem mit dieser Codierung ist, dass Session-Cookies manchmal dieses Muster enthalten können. Session-Cookies sind zufällig generierte Strings und manchmal enthalten sie genau dieses Muster. In diesem Fall gibt es eine Paranoia Level 2-Regel, die nach Requests Ausschau hält, welche versuchen mittels Hexadezimal-Codierung an unserem Regelwerk vorbei zu schleichen. Wir stehen also vor einem geradezu klassischen False Positive.

Die Regeln 942431 und 942432 sind eng miteinander verwandt. Wir nennen dies Geschwister. Sie bilden eine Familie mit 942430, der Basisregel, die nach 12 Sonderzeichen wie eckigen Klammern, Doppelpunkten, Semikolons, Sternchen usw. Ausschau hält (Paranoia Level 2). 942431 ist eine strengeres Geschwister, die das gleiche tut, aber mit einem Limit von 6 Zeichen auf Paranoia Level 3 und schließlich das neurotische Mitglied der Familie, 942432, die bereits nach dem 2. Sonderzeichen austickt (Paranoia Level 4).

942130 ist eine Regel aus der großen Gruppen von SQL-Injection Regeln (dies ist ein Feld, in dem das CRS sehr stark ist) und schliesslich 920273 eine weitere paranoide Regel aus Paranoia-Ebene 4, die den Bereich der erlaubten ASCII-Zeichen definiert (konkret: `38,44-46,48-58,61,65-90,95,97-122`).

Für jede Warnung müssen wir nun eine Rule Exclusion schreiben. Und wie wir in der vorangegangenen Anleitung gesehen haben, gibt es mehrere Optionen. Es braucht ein bisschen Erfahrung, um die richtige Wahl zu treffen und sehr oft können mehrere Ansätze geeignet sein. Betrachten wir noch einmal den Spickzettel:

<a href="https://www.netnea.com/cms/rule-exclusion-cheatsheet-download/"><img src="/files/tutorial-7-rule-exclusion-cheatsheet_small.png" alt="Rule Exclusion CheatSheet" width="476" height="673" /></a>

_Klicken zum Vergrössern_

Beginnen wir mit einem einfachen Fall: 920273. Wir könnten diesen nun sehr genau untersuchen und alle verschiedenen Parameter auswerten, die diese Regel auslösen. Abhängig von der Sicherheitsstufe, die wir für unsere Anwendung erreichen möchten, wäre dies der richtige Ansatz. Aber auf der anderen Seite ist das hier nur eine Übung, so dass wir es uns einfach machen: Werfen wir die Regel komplett raus. Wir entscheiden uns dabei für eine Rule Exclusion zur Startup Time des Servers (die wir nach dem CRS-Include platzieren müssen).

```bash
# === ModSec Core Rules: Startup Time Rules Exclusions

# ModSec Rule Exclusion: 920273 : Invalid character in request (outside of very strict set)
SecRuleRemoveById 920273
```

Als nächstes die Alarme für 942432:

```bash
$> grep -F -f ids tutorial-8-example-error.log  | grep 942432 | melmatch | sucs
     75 ARGS:ids[]
     75 ARGS_NAMES:ids[]
```

Drupal verwendet offensichtlich eckige Klammern innerhalb des Parameternamens. Dies ist nicht auf IDs beschränkt. Vielmehr handelt es sich um ein allgemeines Muster. Zwei eckige Klammern reichen aus, um die Regel auszulösen, so dass dies viele Fehlalarme auslöst. All den verschiedenen Situationen mit diesem Muster nachzurennen wäre sehr langweilig, so dass wir diese Regel auch komplett ausschalten (Wie vorhin bemerkt handelt sich um eine Regel auf Paranoia Level 4. Eine etwas entspanntere Variante dieser Regel gibt es bei PL3. Sie bleibt bestehen).

```bash
# ModSec Rule Exclusion: 942432 : Restricted SQL Character Anomaly Detection (args): 
# number of special characters exceeded (2)
SecRuleRemoveById 942432
```

Die nächste ist 942450. Dies ist die Regel, welche sich um die Hex-Codierung kümmert. Dies ist ein merkwürdiger Fall, wie wir leicht sehen können:

```bash
$> grep -F -f ids tutorial-8-example-error.log  | grep 942450 | melmatch | sucs
      6 REQUEST_COOKIES:98febd3dhf84de73ab2e32889dc5f0x032a9
      6 REQUEST_COOKIES_NAMES:SESS29af1facda0a866a687d5055f0x034ca
```

Wie erwartet, ist es ein Session-Cookie, aber unerwarteter Weise hat das Session-Cookie einen dynamischen Namen! Das bedeutet, dass wir das Session-Cookie nicht einfach via seinen Namen ignorieren können, wir müssen sämtliche Cookies ignorieren, deren Name einem bestimmten Muster entspricht und das ist für eine Konfiguration in ModSecurity sehr, sehr kompliziert. Und es ist wahrscheinlich nicht der Mühe wert. Der einfachere Ansatz ist, diese Regel für sämtliche Cookies zu ignorieren. Auf diese Weise bleibt die Regel für Post-und Query-String-Parameter intakt, aber sie wird keine Alarme für Cookies mehr auslösen.

```bash
# ModSec Rule Exclusion: 942450 : SQL Hex Encoding Identified (severity: 5 CRITICAL)
SecRuleUpdateTargetById 942450 "!REQUEST_COOKIES"
SecRuleUpdateTargetById 942450 "!REQUEST_COOKIES_NAMES"
```

Noch drei weitere: 921180, 942431 und 943130. Wir starten mit der letzten:

```bash
$> grep -F -f ids tutorial-8-example-error.log | grep 942130 | melmatch | sucs
     75 ARGS:ids[]
```

Es ist also immer derselbe Parameter *ids[]*, den wir bereits kennengelernt haben. Vielleicht lohnt es sich die URI anzuschauen, um herauszufinden, was genau passiert:

```bash
$> grep -F -f ids tutorial-8-example-error.log  | grep 942130 | meluri | sucs
     75 /drupal/index.php/contextual/render
```

Das ist also immer derselbe Pfad. Schliessen wir doch einfach den Parameter *ids[]* von der Behandlung aus, wenn er mit diesem Pfad zusammen auftritt. Dies läuft auf eine Runtime Rule Exclusion hinaus. In der vorangegangenen Anleitung haben wir gesehen, dass das Schreiben dieser Art von Regeln anstrengend und kompliziert ist. Es wäre schön, wenn ein Skript die Arbeit für uns machen würde. Ich habe ein solches Skript geschrieben: [modsec-rulereport.rb](https://www.netnea.com/files/modsec-rulereport.rb). Es erwartet eine oder mehrere Alarme (oder das ganze Error Log wenn es sein muss) auf STDIN entgegen und schlägt eine von mehreren möglichen Typen von Rule Exclusions vor (`modsec-rulereport.rb -h` bringt eine Übersicht).

```bash
$> grep -F -f ids tutorial-8-example-error.log  | grep 942130 | modsec-rulereport.rb --mode combined

75 x 942130 SQL Injection Attack: SQL Tautology Detected.
--------------------------------------------------------------------------------
      # ModSec Rule Exclusion: 942130 : SQL Injection Attack: SQL Tautology Detected.
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/contextual/render" \
          "phase:2,nolog,pass,id:10000,ctl:ruleRemoveTargetById=942130;ARGS:ids[]"
```

Der Modus _combined_ weist das Skript an, eine Regel zu schreiben, die eine Pfadbedingung mit einer Regel-ID und einem bestimmten Parameter kombiniert. Als erstes rapportiert das Skript die Anzahl der Meldungen mit diesem Muster, dann schlägt sie eine Ausschlussregel vor, die wir zusammen mit dem Kommentar eins zu eins in unsere Apache-Konfigurationsdatei kopieren können. Die vorgeschlagene Regel hat eine ID von 10'000. Bei einem nächsten Aufruf des Skripts müssen wir diese ID selbst neu setzen, um ID-Kollisionen bei 10'000 zu vermeiden, aber das ist eine einfache Aufgabe.

Hier steht nun, wie die Konfiguration nach dem Einfügen dieses Konstrukts aussieht (Zeilenumbruch aus Anzeigegründen):

```bash
# === ModSec Core Rules: Runtime Exclusion Rules (ids: 10000-49999)

# ModSec Rule Exclusion: 942130 : SQL Injection Attack: SQL Tautology Detected.
SecRule REQUEST_URI "@beginsWith /drupal/index.php/contextual/render" \
    "phase:2,nolog,pass,id:10000,ctl:ruleRemoveTargetById=942130;ARGS:ids[]"
```

Dieses Skript ist sehr praktisch. Werfen wir mal 942431 hinein und schauen, was passiert:

```bash
$> grep -F -f ids tutorial-8-example-error.log  | grep 942431 | modsec-rulereport.rb --mode combined
35 x 942431 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded…
---------------------------------------------------------------------------------------------------------
      # ModSec Rule Exclusion: 942431 : Restricted SQL Character Anomaly Detection (args): # of …
        special characters exceeded (6)
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/contextual/render" …
        "phase:2,nolog,pass,id:10000,ctl:ruleRemoveTargetById=942431;ARGS:ids[]"
```

Das ist fast dasselbe. Wir können also die ctl-Action (den Teil der Anweisung, welche mit `ctl` beginnt) herausnehmen und an die vorherige Anweisung anhängen:

```bash
# === ModSec Core Rules: Runtime Exclusion Rules (ids: 10000-49999)

# ModSec Rule Exclusion: 942130 : SQL Injection Attack: SQL Tautology Detected.
# ModSec Rule Exclusion: 942431 : Restricted SQL Character Anomaly Detection (args): # of …
SecRule REQUEST_URI "@beginsWith /drupal/index.php/contextual/render" \
    "phase:2,nolog,pass,id:10000,ctl:ruleRemoveTargetById=942130;ARGS:ids[],\
                                 ctl:ruleRemoveTargetById=942431;ARGS:ids[]"

```

Und jetzt 921180:

```bash
$> grep -F -f ids tutorial-8-example-error.log  | grep 921180 | modsec-rulereport.rb --mode combined

7 x 921180 HTTP Parameter Pollution (ARGS_NAMES:ids[])
------------------------------------------------------
      # ModSec Rule Exclusion: 921180 : HTTP Parameter Pollution (ARGS_NAMES:ids[])
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/contextual/render" …
          "phase:2,nolog,pass,id:10000, …
	  ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:ids[]"
```

Dies ist nun ein Sonderfall. Er passiert so, dass ein einzelner Parameter mehrmals übermittelt wird. Die Regel arbeitet mit einem separaten Zähler, der für jeden Parameter mitgeführt wird. In einer zweiten Regel, 921180, überprüft die Regel den Zähler und schlägt gegebenenfalls Alarm. Wenn wir den Alarm verhindern wollen, sollten wir am besten die Prüfung dieses Zählers unterdrücken, so wie das Skript es vorschlägt. Wir stehen wieder vor derselben URI, aber ich habe das Gefühl, dass diese Regel auch noch durch weitere Parameter ausgelöst wird. Wir werden sehen.

Das bringt uns zu einem organisatorischen Problem. Wie können wir die Regelausschlüsse am besten organisieren? Vor allem die komplizierten Exclusions zur Laufzeit. Wir können nach Regel-ID, nach URI oder nach Parameter sortieren. Es gibt keine einfache Antwort. Für grosse Webseiten mit mehreren Diensten oder vielen verschiedenen Anwendungspfaden verwende ich den URI, um die Ausschlussregeln nach Zweigen des Dienstes zu gruppieren. Aber mit kleinen Services hat sich die Sortierung nach Regel-ID bewährt.

Wir nehmen jetzt also die vorgeschlagene Regel auf, bereiten den Kommentar für zukünftige Variablen vor, erhöhen die Regel ID um 1 (das verhindert Rule ID Kollisionen) und fügen das alles der Konfiguration hinzu:

```bash
# ModSec Rule Exclusion: 921180 : HTTP Parameter Pollution (multiple variables)
SecRule REQUEST_URI "@beginsWith /drupal/index.php/contextual/render" \
    "phase:2,nolog,pass,id:10001,\
    ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:ids[]"
```

Damit haben wir die sieben Highscore-Anfragen (189 und 231) abgedeckt. Das Schreiben dieser sechs Regel Ausschlüsse war ein wenig umständlich, aber das Skript scheint eine wirkliche Verbesserung für den Prozess darzustellen. Nun geht es schneller. Versprochen.

###Schritt 4: Verringerung der Anomaly Score Limite

Wir haben die Regeln, die zu den höchsten Anomalie Werten führen, unterdrückt.  Eigentlich ist jetzt alles jenseits von 100 Punkten weg.  In einem Produktions-Setup würde ich die aktualisierte Konfiguration installieren und das Verhalten ein wenig beobachten.  Wenn die hohen Werte wirklich weg sind, dann ist es Zeit, die Anomalie Limite zu reduzieren.  Ein typischer erster Schritt ist von 1000 bis 100. Dann setzen wir das Schreiben der Rule Exclusions fort, reduzieren dann auf 50 oder so, dann auf 20, 10 und 5. Tatsächlich ist eine Grenze von 5 wirklich streng (die erste kritische Warnung blockiert damit eine Anfrage),  Aber für Websites mit weniger Sicherheitsbedürfnissen kann eine Grenze von 10 bereits gut genug sein. Alle Werte darüber behindern Angreifer nicht wirklich.

Aber bevor wir dort ankommen, müssen wir noch einige Regelausschlüsse hinzufügen.

###Schritt 5: Die zweite Runde von Rule Exclusions

Nach dem ersten Satz von Regelausschlüssen würden wir den Dienst etwas beobachten. Das bringt uns einen neuen Satz von Logfiles.

* [tutorial-8-example-access-round-2.log](https://www.netnea.com/files/tutorial-8-example-access-round-2.log)
* [tutorial-8-example-error-round-2.log](https://www.netnea.com/files/tutorial-8-example-error-round-2.log)

Wir beginnen erneut mit einem Blick auf die Verteilung der Anomalie Werte:

```bash
$> cat tutorial-8-example-access-round-2.log | alscores | modsec-positive-stats.rb

INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with incoming score of   0 |   8944 |  89.4400% |  89.4400% |  10.5600%
Reqs with incoming score of   1 |      0 |   0.0000% |  89.4400% |  10.5600%
Reqs with incoming score of   2 |      0 |   0.0000% |  89.4400% |  10.5600%
Reqs with incoming score of   3 |      0 |   0.0000% |  89.4400% |  10.5600%
Reqs with incoming score of   4 |     20 |   0.2000% |  89.6400% |  10.3600%
Reqs with incoming score of   5 |    439 |   4.3900% |  94.0300% |   5.9700%
Reqs with incoming score of   6 |      0 |   0.0000% |  94.0300% |   5.9700%
Reqs with incoming score of   7 |      0 |   0.0000% |  94.0300% |   5.9700%
Reqs with incoming score of   8 |    368 |   3.6800% |  97.7100% |   2.2900%
Reqs with incoming score of   9 |      0 |   0.0000% |  97.7100% |   2.2900%
Reqs with incoming score of  10 |      1 |   0.0100% |  97.7200% |   2.2800%
Reqs with incoming score of  11 |      0 |   0.0000% |  97.7200% |   2.2800%
Reqs with incoming score of  12 |      0 |   0.0000% |  97.7200% |   2.2800%
Reqs with incoming score of  13 |      0 |   0.0000% |  97.7200% |   2.2800%
Reqs with incoming score of  14 |      0 |   0.0000% |  97.7200% |   2.2800%
Reqs with incoming score of  15 |      0 |   0.0000% |  97.7200% |   2.2800%
Reqs with incoming score of  16 |      0 |   0.0000% |  97.7200% |   2.2800%
Reqs with incoming score of  17 |      0 |   0.0000% |  97.7200% |   2.2800%
Reqs with incoming score of  18 |      0 |   0.0000% |  97.7200% |   2.2800%
Reqs with incoming score of  19 |      0 |   0.0000% |  97.7200% |   2.2800%
Reqs with incoming score of  20 |      0 |   0.0000% |  97.7200% |   2.2800%
Reqs with incoming score of  21 |      0 |   0.0000% |  97.7200% |   2.2800%
Reqs with incoming score of  22 |      0 |   0.0000% |  97.7200% |   2.2800%
Reqs with incoming score of  23 |      0 |   0.0000% |  97.7200% |   2.2800%
Reqs with incoming score of  24 |      0 |   0.0000% |  97.7200% |   2.2800%
Reqs with incoming score of  25 |     76 |   0.7600% |  98.4800% |   1.5200%
Reqs with incoming score of  26 |      0 |   0.0000% |  98.4800% |   1.5200%
Reqs with incoming score of  27 |      0 |   0.0000% |  98.4800% |   1.5200%
Reqs with incoming score of  28 |      0 |   0.0000% |  98.4800% |   1.5200%
Reqs with incoming score of  29 |      0 |   0.0000% |  98.4800% |   1.5200%
Reqs with incoming score of  30 |     76 |   0.7600% |  99.2400% |   0.7600%
Reqs with incoming score of  31 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  32 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  33 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  34 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  35 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  36 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  37 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  38 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  39 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  40 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  41 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  42 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  43 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  44 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  45 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  46 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  47 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  48 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  49 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  50 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  51 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  52 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  53 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  54 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  55 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  56 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  57 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  58 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  59 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  60 |     76 |   0.7600% | 100.0000% |   0.0000%

Incoming average:   1.3969    Median   0.0000    Standard deviation   6.3634


OUTGOING                     Num of req. | % of req. |  Sum of % | Missing %
Number of outgoing req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. outgoing score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with outgoing score of   0 |   9980 |  99.8000% |  99.8000% |   0.2000%
Reqs with outgoing score of   1 |      0 |   0.0000% |  99.8000% |   0.2000%
Reqs with outgoing score of   2 |      0 |   0.0000% |  99.8000% |   0.2000%
Reqs with outgoing score of   3 |      0 |   0.0000% |  99.8000% |   0.2000%
Reqs with outgoing score of   4 |     20 |   0.2000% | 100.0000% |   0.0000%

Outgoing average:   0.0080    Median   0.0000    Standard deviation   0.1787
```

Wenn wir dies mit dem ersten Lauf des statistischen Skripts vergleichen, dann haben wir die durchschnittliche Punktzahl von 12,5 auf 1,4 reduziert. Das ist sehr beeindruckend. Denn es bedeutet ja, dass wir trotz der Konzentration auf einige wenige Requests mit hohen Scores den gesamten Service deutlich verbesserten.

Wir konnten erwarten, dass die hohen Scoring-Anfragen von 231 und 189 weg sind, aber interessanterweise ist der Cluster bei 98 und derjenigen bei 10 auch verschwunden. Wir haben in der ersten Tuning Runde nur 7 Anfragen abgedeckt, aber zwei Cluster mit Alerts aus 400, respektive 3000 Anfragen sind ebenfalls weg. Und das ist keine Ausnahmeerscheinung. Es ist das Standardverhalten, wenn wir mit dieser Tuning-Methode arbeiten: Einige wenige von den höchsten Werten abgeleitete Rule Exceptions lassen die allermeisten Fehlalarme verschwinden.

Unser nächstes Ziel ist die Gruppe von Anfragen mit einer Punktzahl von 60. Extrahieren wir zum Beginn die Regel-IDs und untersuchen wir die Warnungen ein wenig:

```bash
$> egrep " 60 [0-9-]+$" tutorial-8-example-access-round-2.log | alreqid > ids
$> grep -F -f ids tutorial-8-example-error-round-2.log | melidmsg | sucs
     76 921180 HTTP Parameter Pollution (ARGS_NAMES:keys)
     76 942100 SQL Injection Attack Detected via libinjection
    152 942190 Detects MSSQL code execution and information gathering attempts
    152 942200 Detects MySQL comment-/space-obfuscated injections and backtick termination
    152 942260 Detects basic SQL authentication bypass attempts 2/3
    152 942270 Looking for basic sql injection. Common attack string for mysql, oracle and others.
    152 942410 SQL Injection Attack
$> grep -F -f ids tutorial-8-example-error-round-2.log | meluri | sucs
    912 /drupal/index.php/search/node
```

Dies deutet auf ein Suchformular und verschiedene Payloads hin, die SQL Injection ähneln (ausserhalb der ersten Regel 921180, die wir vorher bereits gesehen haben). Wie wir alle wissen zieht ein Suchformular SQL-Injection-Angriffe geradezu an. Hier war dies aber legitimer Verkehr (ich schickte die Suchanfragen schliesslich persönlich los, als ich nach SQL-Anweisungen in den veröffentlichten Drupal-Artikeln suchte) und nun stehen wir vor einem Dilemma: Wenn wir die Regeln unterdrücken, öffnen wir eine Tür für SQL-Injections.  Wenn wir die Regeln intakt lassen und die Grenze reduzieren werden wir einen Teil des legitimen Verkehrs blockieren.  Es ist eine vertretbare Meinung, niemand solle mit dem Suchformular nach SQL-Anweisungen in unseren Artikeln zu suchen. Es wäre aber auch vertretbar zu sagen, Drupal sei klug genug, um SQL-Angriffe über das Suchformular selbst abzuwehren. Da dies eine Übung zum Schreiben von Rule Exclusions ist, werden wir uns diese Position zu eigen machen. Lassen Sie uns diese Regeln ausschliessen. Wir nehmen das Helfer-Script zu Hilfe:

```bash
$> grep -F -f ids tutorial-8-example-error-round-2.log | modsec-rulereport.rb -m combined

76 x 921180 HTTP Parameter Pollution (ARGS_NAMES:keys)
------------------------------------------------------
      # ModSec Rule Exclusion: 921180 : HTTP Parameter Pollution (ARGS_NAMES:keys)
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" …
      "phase:2,nolog,pass,id:10000, …
      ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:keys"

76 x 942100 SQL Injection Attack Detected via libinjection
----------------------------------------------------------
      # ModSec Rule Exclusion: 942100 : SQL Injection Attack Detected via libinjection
  No parameter available to create ignore-rule proposal. Please try and use different mode.

152 x 942190 Detects MSSQL code execution and information gathering attempts
----------------------------------------------------------------------------
      # ModSec Rule Exclusion: 942190 : Detects MSSQL code execution and information gathering attempts
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" …
      "phase:2,nolog,pass,id:10001,ctl:ruleRemoveTargetById=942190;ARGS:keys"

152 x 942200 Detects MySQL comment-/space-obfuscated injections and backtick termination
----------------------------------------------------------------------------------------
      # ModSec Rule Exclusion: 942200 : Detects MySQL comment-/space-obfuscated  …
        injections and backtick termination
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" …
      "phase:2,nolog,pass,id:10002,ctl:ruleRemoveTargetById=942200;ARGS:keys"

152 x 942260 Detects basic SQL authentication bypass attempts 2/3
-----------------------------------------------------------------
      # ModSec Rule Exclusion: 942260 : Detects basic SQL authentication …
        bypass attempts 2/3
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" …
      "phase:2,nolog,pass,id:10003,ctl:ruleRemoveTargetById=942260;ARGS:keys"

152 x 942270 Looking for basic sql injection. Common attack string for mysql, oracle and others.
------------------------------------------------------------------------------------------------
      # ModSec Rule Exclusion: 942270 : Looking for basic sql injection. …
        Common attack string for mysql, oracle and others.
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" …
      "phase:2,nolog,pass,id:10004,ctl:ruleRemoveTargetById=942270;ARGS:keys"

152 x 942410 SQL Injection Attack
---------------------------------
      # ModSec Rule Exclusion: 942410 : SQL Injection Attack
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" …
      "phase:2,nolog,pass,id:10005,ctl:ruleRemoveTargetById=942410;ARGS:keys"
```

Wir hatten vorher bereits einen Platz für weitere 921180 Ausschlüsse vorbereitet. Wir setzen die erste Regel in diese Position und erhalten damit Folgendes:

```bash
# ModSec Rule Exclusion: 921180 : HTTP Parameter Pollution (multiple variables)
SecRule REQUEST_URI "@beginsWith /drupal/index.php/contextual/render" \
    "phase:2,nolog,pass,id:10001,ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:ids[]"
SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" \
    "phase:2,nolog,pass,id:10002,ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:keys"
```

Bei der Regel 942100 bringt das Skript keinen vernünftigen Vorschlag.  Dies liegt daran, dass die Alarmmeldung ein leicht anderes Format aufweist und das Skript noch nicht schlau genug ist, um es korrekt zu analysieren.  Untersuchen wir die Warnmeldung, um den Pfad und den betreffenden Parameter zu finden.  Leider kann *melmatch* auch nicht damit fertig werden.  Also müssen wir dieses Mal von Hand arbeiten:


```bash
$> grep -F -f ids tutorial-8-example-error-round-2.log | grep 942100 | head -1
[2016-11-05 09:47:18.423889] [-:error] - - [client 127.0.0.1] ModSecurity: Warning. detected SQLi using …
libinjection with fingerprint 'UEkn' …
[file "/apache/conf/owasp-modsecurity-crs-3.0.0-rc1/rules/REQUEST-942-APPLICATION-ATTACK-SQLI.conf"] …
[line "67"] [id "942100"] [rev "1"] [msg "SQL Injection Attack Detected via libinjection"] …
[data "Matched Data: UEkn found within ARGS:keys: union select from users"] [ver "OWASP_CRS/3.0.0"] …
[maturity "1"] [accuracy "8"] [tag "application-multi"] [tag "language-multi"] [tag "platform-multi"] …
[tag "attack-sqli"] [tag "OWASP_CRS/WEB_ATTACK/SQL_INJECTION"] [tag "WASCTC/WASC-19"] …
[tag "OWASP_TOP_10/A1"] [tag "OWASP_AppSensor/CIE1"] [tag "PCI/6.5.2"] [hostname "localhost"] …
[uri "/drupal/index.php/search/node"] [unique_id "WB2cln8AAQEAAAehPc8AAADK"]
```

Daraus können wir die folgende Rule Exclusion ableiten:

```bash
# ModSec Rule Exclusion: 942100 : SQL Injection Attack Detected via libinjection
SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" \
    "phase:2,nolog,pass,id:10003,ctl:ruleRemoveTargetById=942100;ARGS:keys"
```

Bei den verbleibenden Vorschlägen benützen wir diesen Shortcut:

```bash
$> grep -F -f ids tutorial-8-example-error-round-2.log | grep -v "942100\|921180" | \
   modsec-rulereport.rb -m combined | sort
...
      # ModSec Rule Exclusion: 942190 : Detects MSSQL code execution and information gathering attempts
      # ModSec Rule Exclusion: 942200 : Detects MySQL comment-/space-obfuscated injections and backtick …
      # ModSec Rule Exclusion: 942260 : Detects basic SQL authentication bypass attempts 2/3
      # ModSec Rule Exclusion: 942270 : Looking for basic sql injection. Common attack string for mysql …
      # ModSec Rule Exclusion: 942410 : SQL Injection Attack
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" …
      "phase:2,nolog,pass,id:10000,ctl:ruleRemoveTargetById=942190;ARGS:keys"
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" …
      "phase:2,nolog,pass,id:10001,ctl:ruleRemoveTargetById=942200;ARGS:keys"
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" …
      "phase:2,nolog,pass,id:10002,ctl:ruleRemoveTargetById=942260;ARGS:keys"
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" …
      "phase:2,nolog,pass,id:10003,ctl:ruleRemoveTargetById=942270;ARGS:keys"
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" …
      "phase:2,nolog,pass,id:10004,ctl:ruleRemoveTargetById=942410;ARGS:keys"

```

Wir können dies in die folgende Regel vereinfachen, die dann an die vorherige Exclusion für 942100 angehängt wird:


```bash
# ModSec Rule Exclusion: 942100 : SQL Injection Attack Detected via libinjection
# ModSec Rule Exclusion: 942190 : Detects MSSQL code execution and information gathering attempts
# ModSec Rule Exclusion: 942200 : Detects MySQL comment-/space-obfuscated injections and backtick …
# ModSec Rule Exclusion: 942260 : Detects basic SQL authentication bypass attempts 2/3
# ModSec Rule Exclusion: 942270 : Looking for basic sql injection. Common attack string for mysql …
# ModSec Rule Exclusion: 942410 : SQL Injection Attack
SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" "phase:2,nolog,pass,id:10004,\
    ctl:ruleRemoveTargetById=942100;ARGS:keys,\
    ctl:ruleRemoveTargetById=942190;ARGS:keys,\
    ctl:ruleRemoveTargetById=942200;ARGS:keys,\
    ctl:ruleRemoveTargetById=942260;ARGS:keys,\
    ctl:ruleRemoveTargetById=942270;ARGS:keys,\
    ctl:ruleRemoveTargetById=942410;ARGS:keys"
```

Und fertig. Dieses Mal haben wir alle Anfragen mit einem Score von über 50 eliminiert. Zeit, die Anomalieschwelle auf 50 zu reduzieren. Lassen wir es ein wenig so laufen und prüfen wir dann die Logfiles für die dritte Charge.

###Schritt 6: Die dritte Runde mit Rule Exclusions

Hier sind dieselben Übungsfiles. Es ist immer noch derselbe Verkehr, aber dank den oben stehenden Rule Exclusions mit weniger Alarmen.

* [tutorial-8-example-access-round-3.log](https://www.netnea.com/files/tutorial-8-example-access-round-3.log)
* [tutorial-8-example-error-round-3.log](https://www.netnea.com/files/tutorial-8-example-error-round-3.log)


Dies führt zu folgenden Statistiken (diesmal nur für die eingehenden Anfragen):

```bash
$> cat tutorial-8-example-access-round-3.log | alscores | modsec-positive-stats.rb --incoming
INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with incoming score of   0 |   9192 |  91.9200% |  91.9200% |   8.0800%
Reqs with incoming score of   1 |      0 |   0.0000% |  91.9200% |   8.0800%
Reqs with incoming score of   2 |      0 |   0.0000% |  91.9200% |   8.0800%
Reqs with incoming score of   3 |      0 |   0.0000% |  91.9200% |   8.0800%
Reqs with incoming score of   4 |      0 |   0.0000% |  91.9200% |   8.0800%
Reqs with incoming score of   5 |    439 |   4.3900% |  96.3100% |   3.6900%
Reqs with incoming score of   6 |      0 |   0.0000% |  96.3100% |   3.6900%
Reqs with incoming score of   7 |      0 |   0.0000% |  96.3100% |   3.6900%
Reqs with incoming score of   8 |    368 |   3.6800% |  99.9900% |   0.0100%
Reqs with incoming score of   9 |      0 |   0.0000% |  99.9900% |   0.0100%
Reqs with incoming score of  10 |      1 |   0.0100% | 100.0000% |   0.0000%

Incoming average:   0.5149    Median   0.0000    Standard deviation   1.7882
```

Erneut sind zahlreiche False Positives verschwunden, obschon wir nur eine kleine Reihe von Ausschlüssen für eine Punktzahl von 60 durchgeführt haben. Für diese Tuning-Runde knüpfen wir uns einsame Anfrage bei 10 und den Cluster bei 8 vor, damit wir die die Anomalie Schwelle auf 10 reduzieren können, was schon recht niedrig ist.

```bash
$> egrep " (10|8) [0-9-]+$" tutorial-8-example-access-round-3.log | alreqid > ids
$> grep -F -f ids tutorial-8-example-error-round-3.log | melidmsg | sucs
      2 932160 Remote Command Execution: Unix Shell Code Found
    368 921180 HTTP Parameter Pollution (ARGS_NAMES:editors[])
    368 942431 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (6)
```

Der erste Alarm ist merkwürdig: *Remote command execution*. Was hat es damit auf sich?


```bash
$> grep -F -f ids tutorial-8-example-error-round-3.log | grep 932160 | melmatch
ARGS:account[pass][pass1]
ARGS:account[pass][pass2]
$> grep -F -f ids tutorial-8-example-error-round-3.log | grep 932160 | meldata
Matched Data: /bin/bash found within ARGS:account[pass
Matched Data: /bin/bash found within ARGS:account[pass
```

Aha, es scheint sich um ein Passwort namens `/bin/bash` zu handeln. Das ist wahrscheinlich nicht die klügste Wahl, aber nichts, was uns schaden sollte. Wir können diese Regel für diesen Parameter leicht unterdrücken. Wenn wir aber etwas nach vorne schauen, dann müssen wir damit rechnen, dass andere merkwürdige Passwörter eine ganze Reihe andere Regeln verletzen werden. Tatsächlich ist das Passwort-Feld nicht unbedingt ein typisches Ziel eines Angriffs. Es könnte also eine Situation sein, in der es sinnvoll ist, eine ganze Klasse von Regeln zu deaktivieren.  Wir haben dazu mehrere Möglichkeiten. Wir können durch ein Tag deaktivieren, oder wir können einen ganzen Regel ID Bereich deaktivieren.  Schauen wir uns die verschiedenen Regel-Dateien an:

```bash
REQUEST-901-INITIALIZATION.conf
REQUEST-903.9001-DRUPAL-EXCLUSION-RULES.conf
REQUEST-903.9002-WORDPRESS-EXCLUSION-RULES.conf
REQUEST-905-COMMON-EXCEPTIONS.conf
REQUEST-910-IP-REPUTATION.conf
REQUEST-911-METHOD-ENFORCEMENT.conf
REQUEST-912-DOS-PROTECTION.conf
REQUEST-913-SCANNER-DETECTION.conf
REQUEST-920-PROTOCOL-ENFORCEMENT.conf
REQUEST-921-PROTOCOL-ATTACK.conf
REQUEST-930-APPLICATION-ATTACK-LFI.conf
REQUEST-931-APPLICATION-ATTACK-RFI.conf
REQUEST-932-APPLICATION-ATTACK-RCE.conf
REQUEST-933-APPLICATION-ATTACK-PHP.conf
REQUEST-941-APPLICATION-ATTACK-XSS.conf
REQUEST-942-APPLICATION-ATTACK-SQLI.conf
REQUEST-943-APPLICATION-ATTACK-SESSION-FIXATION.conf
REQUEST-949-BLOCKING-EVALUATION.conf
RESPONSE-950-DATA-LEAKAGES.conf
RESPONSE-951-DATA-LEAKAGES-SQL.conf
RESPONSE-952-DATA-LEAKAGES-JAVA.conf
RESPONSE-953-DATA-LEAKAGES-PHP.conf
RESPONSE-954-DATA-LEAKAGES-IIS.conf
RESPONSE-959-BLOCKING-EVALUATION.conf
RESPONSE-980-CORRELATION.conf
```

Wir wollen nicht, dass die Protokoll-Angriffe ignoriert werden. Aber die Angriffe auf die verschiedenen Anwendungen werden wir ausgeschalten. Wir werfen also die Regeln von `REQUEST-930-APPLICATION-ATTACK-LFI.conf` bis `REQUEST-943-APPLICATION-ATTACK-SESSION-FIXATION.conf` raus.  Dies ist effektiv der Regelbereich von 930'000 bis 943'999.  Wir können die beiden Passwort Parameter für alle diese Regeln mit den folgenden Startup Time Ausschlüssen unterdrücken:

```bash
# ModSec Rule Exclusion: 930000 - 943999 : All application rules for password parameters
SecRuleUpdateTargetById 930000-943999 "!ARGS:account[pass][pass1]"
SecRuleUpdateTargetById 930000-943999 "!ARGS:account[pass][pass2]"
```

Es bleibt eine weitere Instanz von 921180, plus die 942431, die wir schon einmal gesehen haben.  Hier ist das, was das Skript vorschlägt:

```bash
$> grep -F -f ids tutorial-8-example-error-round-3.log | grep "921180\|942431" | \
   modsec-rulereport.rb -m combined 

448 x 921180 HTTP Parameter Pollution (ARGS_NAMES:editors[])
------------------------------------------------------------
      # ModSec Rule Exclusion: 921180 : HTTP Parameter Pollution (ARGS_NAMES:editors[])
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/quickedit/attachments" …
      "phase:2,nolog,pass,id:10000,ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:editors[]"

448 x 942431 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (6)
----------------------------------------------------------------------------------------------------
      # ModSec Rule Exclusion: 942431 : Restricted SQL Character Anomaly Detection (args): # of
        special characters exceeded (6)
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/quickedit/attachments" …
      "phase:2,nolog,pass,id:10001,ctl:ruleRemoveTargetById=942431;ARGS:ajax_page_state[libraries]"
```

Nun wissen wir schon recht genau, wie das geht: Der erste Vorschlag wird mit den anderen Direktiven zum Ausschluss von 921180 zusammengelegt (vergessen Sie nicht, eine neue Regel-ID auszuwählen) und der zweite Vorschlag wird als neuer Eintrag hinzugefügt:


```bash
# ModSec Rule Exclusion: 942431 : Restricted SQL Character Anomaly Detection (args): 
# # of special characters exceeded (6)
SecRule REQUEST_URI "@beginsWith /drupal/index.php/quickedit/attachments" \
    "phase:2,nolog,pass,id:10005,ctl:ruleRemoveTargetById=942431;ARGS:ajax_page_state[libraries]"
```

Zeit, die Limite ein weiteres Mal zu reduzieren (dieses Mal bis auf 10) und zu sehen, was passiert.


###Schritt 7: Die vierte Runde mit Regel-Tunins

Wir haben ein neues Paar Logfiles:

* [tutorial-8-example-access-round-4.log](https://www.netnea.com/files/tutorial-8-example-access-round-4.log)
* [tutorial-8-example-error-round-4.log](https://www.netnea.com/files/tutorial-8-example-error-round-4.log)

Hier die Statistik hierzu:

```bash
$> cat tutorial-8-example-access-round-4.log | alscores | modsec-positive-stats.rb --incoming
INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with incoming score of   0 |   9561 |  95.6100% |  95.6100% |   4.3900%
Reqs with incoming score of   1 |      0 |   0.0000% |  95.6100% |   4.3900%
Reqs with incoming score of   2 |      0 |   0.0000% |  95.6100% |   4.3900%
Reqs with incoming score of   3 |      0 |   0.0000% |  95.6100% |   4.3900%
Reqs with incoming score of   4 |      0 |   0.0000% |  95.6100% |   4.3900%
Reqs with incoming score of   5 |    439 |   4.3900% | 100.0000% |   0.0000%

Incoming average:   0.2195    Median   0.0000    Standard deviation   1.0244
```

Es scheint, wir seien beinahe fertig. Welche Regeln bleiben noch zurück?


```bash
$> cat tutorial-8-example-access-round-4.log | egrep " 5 [0-9-]+$"  | alreqid > ids
$> grep -F -f ids tutorial-8-example-error-round-4.log  | melidmsg | sucs
     30 921180 HTTP Parameter Pollution (ARGS_NAMES:op)
     41 932160 Remote Command Execution: Unix Shell Code Found
    368 921180 HTTP Parameter Pollution (ARGS_NAMES:fields[])
```

Unser Freund 921180 ist betreffend zwei anderer Parameter zurück und dazu ein weiteres Shell-Problem.  Möglicherweise ein weiteres Vorkommen des Passwort Parameters. Überprüfen wir das alles mal:

```bash
$> grep -F -f ids tutorial-8-example-error-round-4.log  | grep 921180 | \
modsec-rulereport.rb -m combined

398 x 921180 HTTP Parameter Pollution (ARGS_NAMES:op)
-----------------------------------------------------
      # ModSec Rule Exclusion: 921180 : HTTP Parameter Pollution (ARGS_NAMES:op)
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/quickedit/metadata" …
      "phase:2,nolog,pass,id:10000,ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:fields[]"
      SecRule REQUEST_URI "@beginsWith /drupal/core/install.php" …
      "phase:2,nolog,pass,id:10001,ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:op"
```

Es ist einfach, dies an der üblichen Stelle mit einer neuen Regel ID hinzuzufügen. Und dann noch der letzte Fehlalarm:

```bash
$> grep -F -f ids tutorial-8-example-error-round-4.log  | grep 932160 | \
modsec-rulereport.rb -m combined

41 x 932160 Remote Command Execution: Unix Shell Code Found
-----------------------------------------------------------
      # ModSec Rule Exclusion: 932160 : Remote Command Execution: Unix Shell Code Found
      SecRule REQUEST_URI "@beginsWith /drupal/index.php/user/login" \
      "phase:2,nolog,pass,id:10000,ctl:ruleRemoveTargetById=932160;ARGS:pass"
```

Also ja, wieder das Passwort-Feld.  Ich denke, es ist am besten, den gleichen Prozess ausführen, den wir mit den anderen Vorkommen des Kennworts durchgeführt. Damals war es wohl die Registrierung, diesmal ist es das Login-Formular.

```bash
SecRuleUpdateTargetById 930000-943999 "!ARGS:pass"
```

Und damit sind wir fertig. Wir haben erfolgreich alle falschen Positiven eines Content-Management-Systems mit eigenartigen Parameterformaten und einem ModSecurity-Regelsatz, der auf einen wahnsinnig paranoiden Level gehoben wurde, bekämpft.

###Schritt 8: Alle Regel Ausschlüsse nochmals zusammenfassen

Zeit zum Zurückschauen und die Konfigurationsdatei mit allen Regelausschlüssen nochmals sauber zu formatieren. Ich habe alles ein wenig umgruppiert. Dazu habe ich einige Anmerkungen angebracht und die Regel IDs neu vergeben.  Wie bereits erwähnt, ist es nicht offensichtlich, wie die Regeln zu ordnen sind. Hier habe ich sie per ID gruppiert, aber auch einen Block eingefügt, in dem das Suchformular separat abdeckt wird.

```bash
# === ModSec Core Rules: Runtime Exclusion Rules (ids: 10000-49999)

# ModSec Rule Exclusion: 921180 : HTTP Parameter Pollution (multiple variables)
SecRule REQUEST_URI "@beginsWith /drupal/index.php/contextual/render" \
    "phase:2,nolog,pass,id:10001,ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:ids[]"
SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" \
    "phase:2,nolog,pass,id:10002,ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:keys"
SecRule REQUEST_URI "@beginsWith /drupal/index.php/quickedit/attachments" \
    "phase:2,nolog,pass,id:10003,ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:editors[]"
SecRule REQUEST_URI "@beginsWith /drupal/index.php/quickedit/metadata" \
    "phase:2,nolog,pass,id:10004,ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:fields[]"
SecRule REQUEST_URI "@beginsWith /drupal/core/install.php" \
    "phase:2,nolog,pass,id:10005,ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:op"

# ModSec Rule Exclusion: 942130 : SQL Injection Attack: SQL Tautology Detected
# ModSec Rule Exclusion: 942431 : Restricted SQL Character Anomaly Detection (args)
SecRule REQUEST_URI "@beginsWith /drupal/index.php/contextual/render" \
    "phase:2,nolog,pass,id:10006,ctl:ruleRemoveTargetById=942130;ARGS:ids[],\
                                 ctl:ruleRemoveTargetById=942431;ARGS:ids[]"

# ModSec Rule Exclusion: 942431 : Restricted SQL Character Anomaly Detection (args)
SecRule REQUEST_URI "@beginsWith /drupal/index.php/quickedit/attachments" \
    "phase:2,nolog,pass,id:10007,ctl:ruleRemoveTargetById=942431;ARGS:ajax_page_state[libraries]"


# Handling alerts for the search form:
# ModSec Rule Exclusion: 942100 : SQL Injection Attack Detected via libinjection
# ModSec Rule Exclusion: 942190 : Detects MSSQL code execution and information gathering attempts
# ModSec Rule Exclusion: 942200 : Detects MySQL comment-/space-obfuscated injections and backtick ...
# ModSec Rule Exclusion: 942260 : Detects basic SQL authentication bypass attempts 2/3
# ModSec Rule Exclusion: 942270 : Looking for basic sql injection. Common attack string for mysql, ...
# ModSec Rule Exclusion: 942410 : SQL Injection Attack
SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" "phase:2,nolog,pass,id:10100,\
   ctl:ruleRemoveTargetById=942100;ARGS:keys,\
   ctl:ruleRemoveTargetById=942190;ARGS:keys,\
   ctl:ruleRemoveTargetById=942200;ARGS:keys,\
   ctl:ruleRemoveTargetById=942260;ARGS:keys,\
   ctl:ruleRemoveTargetById=942270;ARGS:keys,\
   ctl:ruleRemoveTargetById=942410;ARGS:keys"


# === ModSecurity Core Rules Inclusion

Include    /apache/conf/crs/rules/*.conf


# === ModSecurity Ignore Rules After Core Rules Inclusion; order by id of ignored rule (ids: 50000-79999)

# ModSec Rule Exclusion: 942450 : SQL Hex Encoding Identified
SecRuleUpdateTargetById 942450 "!REQUEST_COOKIES
SecRuleUpdateTargetById 942450 "!REQUEST_COOKIES_NAMES


# ModSec Rule Exclusion: 942432 : Restricted SQL Character Anomaly Detection (args): 
# number of special characters exceeded (2) (severity:  NONE/UNKOWN)
SecRuleRemoveById 942432
SecRuleRemoveById 920273

# ModSec Rule Exclusion: 930000 - 943999 : All application rules for password parameters
SecRuleUpdateTargetById 930000-943999 "!ARGS:account[pass][pass1]"
SecRuleUpdateTargetById 930000-943999 "!ARGS:account[pass][pass2]"
SecRuleUpdateTargetById 930000-943999 "!ARGS:pass"

```

###Bonus: Rascher einen Überblick gewinnen

Wenn man das alles zum ersten Mal tut, dann sind all diese vielen Regeln recht einschüchternd. Aber letztlich war es zusammengenommen auch nur eine Stunde Arbeit, was wiederum vernünftig erscheint. Zudem erstreckt sich das alles ja über mehrere Iterationen. Es würde aber nicht schaden, etwas Hilfe zu erhalten, um sich schneller einen Überblick über all die Warnungen zu verschaffen. Deshalb ist es eine gute Idee, einen Bericht darüber zu erzeugen, wie genau die *Anomaly Scores* aufgetreten sind. Zum Beispiel eine Übersicht der Regelverletzungen für jeden Anomalie Wert.  Das folgende Konstrukt generiert einen solchen Bericht.  In der ersten Zeile extrahieren wir eine Liste der Anomaliescores aus den eingehenden Anfragen, die tatsächlich in der Protokolldatei erscheinen.  Wir erstellen dann eine Schleife um diese *Scores*, lesen die *request ID* für jeden Wert ein, speichern sie in der Datei `ids` ab und führen eine kurze Analyse für diese *IDs* im Error Log durch.

```bash
$> cat tutorial-8-example-access.log | alscorein | sort -n | uniq | egrep -v -E "^0" > scores
$> cat scores | while read S; do echo "INCOMING SCORE $S";\
grep -E " $S [0-9-]+$" tutorial-8-example-access.log \
| alreqid > ids; grep -F -f ids tutorial-8-example-error.log | melidmsg | sucs; echo ; done 
INCOMING SCORE 5
     30 921180 HTTP Parameter Pollution (ARGS_NAMES:op)

INCOMING SCORE 8
      1 920273 Invalid character in request (outside of very strict set)
      1 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)

INCOMING SCORE 10
      4 920273 Invalid character in request (outside of very strict set)
   6384 942450 SQL Hex Encoding Identified

INCOMING SCORE 20
     56 932160 Remote Command Execution: Unix Shell Code Found
    168 920273 Invalid character in request (outside of very strict set)

INCOMING SCORE 30
     77 920273 Invalid character in request (outside of very strict set)
     77 942190 Detects MSSQL code execution and information gathering attempts
     77 942200 Detects MySQL comment-/space-obfuscated injections and backtick termination
     77 942260 Detects basic SQL authentication bypass attempts 2/3
     77 942270 Looking for basic sql injection. Common attack string for mysql, oracle and others.
     77 942410 SQL Injection Attack

INCOMING SCORE 35
     77 920273 Invalid character in request (outside of very strict set)
     77 942100 SQL Injection Attack Detected via libinjection
     77 942190 Detects MSSQL code execution and information gathering attempts
     77 942200 Detects MySQL comment-/space-obfuscated injections and backtick termination
     77 942260 Detects basic SQL authentication bypass attempts 2/3
     77 942270 Looking for basic sql injection. Common attack string for mysql, oracle and others.
     77 942410 SQL Injection Attack

INCOMING SCORE 78
     77 921180 HTTP Parameter Pollution (ARGS_NAMES:keys)
     77 942100 SQL Injection Attack Detected via libinjection
     77 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)
    154 942190 Detects MSSQL code execution and information gathering attempts
    154 942200 Detects MySQL comment-/space-obfuscated injections and backtick termination
    154 942260 Detects basic SQL authentication bypass attempts 2/3
    154 942270 Looking for basic sql injection. Common attack string for mysql, oracle and others.
    154 942410 SQL Injection Attack
    231 920273 Invalid character in request (outside of very strict set)

INCOMING SCORE 79
    448 921180 HTTP Parameter Pollution (ARGS_NAMES:editors[])
    448 942431 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (6)
    896 942450 SQL Hex Encoding Identified
   3144 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)
   3595 920273 Invalid character in request (outside of very strict set)

INCOMING SCORE 93
      2 932160 Remote Command Execution: Unix Shell Code Found
      6 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)
     13 920273 Invalid character in request (outside of very strict set)

INCOMING SCORE 98
    448 921180 HTTP Parameter Pollution (ARGS_NAMES:fields[])
    896 942450 SQL Hex Encoding Identified
   2688 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)
   5824 920273 Invalid character in request (outside of very strict set)

INCOMING SCORE 189
      1 921180 HTTP Parameter Pollution (ARGS_NAMES:ids[])
      5 942431 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (6)
      9 942130 SQL Injection Attack: SQL Tautology Detected.
     14 920273 Invalid character in request (outside of very strict set)
     18 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)

INCOMING SCORE 231
      6 921180 HTTP Parameter Pollution (ARGS_NAMES:ids[])
     12 942450 SQL Hex Encoding Identified
     30 942431 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (6)
     66 942130 SQL Injection Attack: SQL Tautology Detected.
     96 920273 Invalid character in request (outside of very strict set)
    132 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)
```

Ein ähnliches Skript, das etwas erweitert wurde, ist Teil meiner privaten Toolbox.

Bevor wir mit dieser Anleitung fertig sind, beschreibe ich die hier angewandte Tuning Policy nochmals kurz:


* Von Beginn weg im Blocking Mode arbeiten
* Die Anfragen mit den höchsten Anomalie-Werten kommen zuerst
* Wir Tunen in mehreren Durchgängen

Mit grösserer Erfahrung kommt man natürlich rascher voran und es lohnt sich, die Anzahl der Iterationen zu reduzieren und mehr Fehlalarme in einem einzigen Durchlauf anzupacken. Oder man konzentriert sich neu auf diejenigen Regeln, die am häufigsten ausgelöst werden. Das kann auch funktionieren und am Ende, wenn alle Regel Ausschlüsse abgearbeitet sind, sollten Sie mit derselben Konfiguration dastehen. Aber nach meiner Erfahrung ist diese beschriebene Technik mit den drei einfachen Leitlinien die Vorgehensweise mit der höchsten Chance auf Erfolg. Dazu kommt auch die niedrigste Abbrecherquote. Denn das Ziel ist es ja, am Ende mit einem strikten ModSecurity CRS-Setup im Blocking-Modus mit einer niedrigen Anomalie Scoring Limite in der Produktion zu stehen.

Damit haben wir das Ende einer Gruppe von drei Anleitungen erreicht. Das Thema war ModSecurity und seine Konfiguration. Als nächstes wenden wir uns der Einrichtung eines Reverse Proxies zu.

###Verweise
- [Spider Labs Blog Post: Behandlung von Ausnahmen](http://blog.spiderlabs.com/2011/08/modsecurity-advanced-topic-of-the-week-exception-handling.html)
- [ModSecurity Reference Manual](https://github.com/SpiderLabs/ModSecurity/wiki/Reference-Manual)

### Lizenz / Kopieren / Weiterverwenden

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />Diese Arbeit ist wie folgt lizenziert / This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

