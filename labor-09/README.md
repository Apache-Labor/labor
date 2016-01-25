##Title: Apache und ModSec effizient in der Shell konfigurieren und debuggen

###Was machen wir?

Wir legen uns Shell-Werkzeuge und eine Arbeitsweise zurecht, welche es erlaubt, Apache-Konfigurationen effizient zu bearbeiten und in wenigen Sekunden zu testen, ohne den Browser zu benützen oder ständig Files suchen zu müssen.

###Warum tun wir das?

Den Apache Webserver erfolgreich zu konfigurieren setzt viel Wissen und Erfahrung voraus. Wenn ModSecurity hinzukommt und in die Verarbeitung eingreifen sollen, dann wird die Konfiguration noch komplizierter. Es ist deshalb nötig, sich die richtigen Werkzeuge zurechtzulegen und einen systematischen Arbeitsablauf einzurichten. Dies ist das Ziel dieses Tutorials.

Die Anleitung hat etwas pedantisches an sich, denn es geht darin mit vollem Ernst um die Optimierung von einzelnen Tastendrucken. Da diese Aktionen bei der Entwicklung der Konfiguration eines Webservers dutzende, wenn nicht hunderte Male nacheinander ausgelöst werden müssen, hat eine Optimierung, wie lächerlich sie auch scheinen mag, ein grosses Potential. Dazu kommt der Vorteil, dass wir damit unnötigen Ballast entfernen können, was den Blick auf das eigentliche Konfigurationsproblem freimacht. Zu diesem Zweck präsentiert diese Anleitung ein, zwei interessante Tricks, die einen ansprechenden Gewinn bringen.


###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](https://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/)
* Verständnis der minimalen Konfiguration in [Anleitung 2 (Apache minimal konfigurieren)](https://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/)
* Ein Apache Webserver mit SSL-/TLS-Unterstützung wie in [Anleitung 4 (Konfigurieren eines SSL Servers)](https://www.netnea.com/cms/apache-tutorial-4-ssl-server-konfigurieren)
* Ein Apache Webserver mit erweitertem Zugriffslog wie in [Anleitung 5 (Das Zugriffslog Ausbauen und Auswerten)](https://www.netnea.com/cms/apache-tutorial-5-zugriffslog-ausbauen/)
* Ein Apache Webserver mit ModSecurity wie in [Anleitung 6 (ModSecurity einbinden)](https://www.netnea.com/cms/apache-tutorial-6-modsecurity-einbinden/)
* Ein Apache Webserver mit einer Core Rules Installation wie in [Anleitung 7 (Core Rules einbinden)](http://www.netnea.com/cms/modsecurity-core-rules-einbinden/)


###Schritt 1: Curl

Curl ist das richtige Werkzeug um HTTP Anfragen auszulösen. Natürlich muss HTTP primär im Browser oder der Applikation funktionieren. Aber bei der Fehlersuche oder der Konfiguration von neuen Features erweist sich der Browser in aller Regel als zu schwerfällig. Cookie-Handling, Grösse des Fensters, automatisches Folgen von Redirects etc. tragen alle dazu bei, dass man bei der Arbeit im Browser viel Zeit verbraucht. Besser von der Hand läuft es deshalb, wenn man ein Problem im Browser identifiziert, es dann mittels `curl` reproduziert, den Fehler sucht, ihn in der Konfiguration des Servers behebt und schliesslich die Lösung im Browser verifiziert.

Wir haben `curl` in den vorangegangenen Anleitungen verschiedentlich angewendet. Wir sind damit bereits sehr gut aufgestellt, es lohnt sich aber, noch ein, zwei Features in den eigenen Werkzeugkasten mitaufzunehmen.

FIXME: Apache example config returning a cookie, a redirect and a 403 if cookie is not sent on 2nd request.
FIXME: cookie-jar
FIXME: --next


###Schritt 2: Single File Apache Konfiguration

Die in dieser Artikelserie verwendete Apache-Konfiguration ist für das Labor gedacht. Damit meine ich eine Test-Umgebung, in der Konfigurationen rasch ausprobiert oder Fehler ohne Rücksicht auf produktiven HTTP-Verkehr gesucht werden können. Ein wesentliches Merkmal der verwendeten Apache-Konfiguration war die Technik, die gesamte Konfiguration mit Ausnahme der OWASP ModSecurity Core Rules in einer einzigen Datei unterzubringen. Dies bringt den Vorteil, im File sehr rasch navigieren und einzelne Passagen mittels Standard-Suchbefehlen erreichen zu können. Dieses Prinzip ist aber nicht nur im Labor ein Gewinn, auch in einer Produktionsumgebung macht es Sinn so zu arbeiten und Widersprüche und Redundanzen weitgehend auszuschliessen. Die heute verbreitete Modularisierung der Webserver Konfiguration in verschiedene Dateien steht dem allerdings im Wege und provoziert Fehler. Tatsächlich wurde ich schon mehrfach mit Setups konfrontiert, die Virtualhosts mehrfach konfigurierten, widersprüchliche Zugriffsbeschränkungen einrichteten und deren Administratoren sich überrascht zeigten, dass die konfigurierten Direktiven andernorts übersteuert wurden. Aus diesem Grund versuche ich wenn immer möglich mit einer Konfiguration in einem einzigen File zu arbeiten.

Wichtig ist auf jeden Fall eine klare Struktur und ein stringentes Vorgehen. Bei jeder Direktive muss klar sein, an welcher Stelle in der Konfiguration sie zu liegen kommen muss. Ausreichend Kommentare müssen die markanten Teile dokumentieren (ohne die Direktiven in einem Dschungel von Dokumentation zu verstecken, wie in der Apache Default-Konfiguration). Die Beispiel-Konfigurationen der vorangegangenen Anleitungen versuchten genau dies umzusetzen.

Im Labor bietet es sich an, sich ein Template zurecht zu legen. Für meine eigenen Arbeiten habe ich ein Konfiguration namens `httpd.conf_template` zurechtgelegt. Dabei handelt es sich um eine lauffähige Konfiguration Reverse Proxy Konfiguration, den Core Rules, dem durch ModSecurity unterstützten Performance Log etc. Zu Beginn der Arbeit an einem neuen Problem kopiere ich dieses Template-File und justiere dann diese Konfiguration noch leicht, um sie auf das richtige Szenario umzubiegen:

```bash
$> cp httpd.conf_template httpd.conf_problem-of-the-day
$> vim httpd.conf_problem-of-the-day
```

`Vim` eignet sich gut, um Apache Konfigurationen zu bearbeiten, aber letztlich spielt der Editor keine entscheidende Rolle solange er Syntax-Highlighting unterstützt, was beim Editieren wirklich einen Mehrwert bringt.

###Schritt 3: Apachex

Mit `curl` und einem Single-File-Apache haben wir bereits gute Voraussetzungen, um rasch Konfigurationen schreiben und sie ebenso rasch testen zu können. Ein etwas nerviger Schritt steht meistens zwischen diesen ersten beiden Schritten: Der Neustart des Webservers. In den ersten beiden Anleitungen haben wir den Server jeweils mit dem Kommandozeilen Flag `-X` gestartet. Ich arbeite oft mit `-X`, da es ja den Server nicht in den Daemon-Moder versetzt und ihn stattdessen im Vordergrund als Single-Prozess laufen lässt. Ein Absturz des Servers ist damit unmittelbar in der Shell sichtbar. Wenn wir den Webserver standardgemäss starten und ihn als Daemon betreiben, müssen wir das Error-Log beobachten und sicherstellen, dass wir einen Absturz nicht verpassen, was allerlei merkwürdige Effekte nach sich ziehen kann. Diese Überwachung ist zwar machbar, in meiner Erfahrung aber ein überraschend gravierender Nachteil. Ich arbeite also mit `-X`. 

Der normale Arbeitsablauf mit einem Single-Prozess-Apache ist ein abwechselndes Starten des Binaries mit dem oben konfigurierten Konfigurationsfile und Stoppen mittels `CTRL-C`. Das bringt zwei Nachteile mit sich. Zum einen müssen wir den Namen des Konfigurationsfiles eingeben, respektive ab der zweiten Runde aus der History der Shell abrufen. Unangenehmer noch ist der Verlust von Semaphoren durch den Abbruch des Webservers mittels `CTRL-C`. Bei den Semaphoren handelt es sich um eine durch den Webserver benutzte Kommunikationsstruktur des Linux-Betriebsystems. Die Anzahl der Semaphoren ist endlich und wenn wir den Webserver abbrechen gibt er eine reservierte Semaphore oftmals nicht mehr frei. Irgendwann ist der Vorrat an Semaphoren aufgebraucht und der Server kann nicht mehr länger gestartet werden. Stattdessen wird folgende Fehlermeldung ausgegeben, die nicht ohne weiteres auf das Sempahoren-Problem schliessen lässt:

```bash
[emerg] (28)No space left on device: Couldn't create accept lock
```

Das Problem ist aber nicht die fehlende Reserve an Speicherplatz, sondern der Mangel an freien Semaphoren. Diese müssen vor einem Neustart zurückgewonnen werden. Dazu hat sich folgende Konstrukstion bewährt:

```bash
$> sudo ipcs -s | grep www-data | awk '{ print $2 }' | xargs -n 1 sudo ipcrm sem
```

Mittels `ipcs -s` lesen wir die Liste von Semaphoren aus, selektieren die richtige Zeile über den Usernamen des Webservers, und benützen dann `awk` um die zweite Spalte des Outputs zu selektieren. Dieser Spalte entnehmen wir die Identifikation der Semaphore, welche wir darauf mittels xargs und `ipcrm sem` löschen. Damit ist dieses Problem in den Griff zu kriegen, aber die Fehlermeldung ist doch ein Ärgernis und das wiederholte Suchen in der History unnötig. Besser ist es da, beides durch ein Skript erledigen zu lassen:

```bash
$> cat bin/apachex

#!/bin/bash
#
# Skript to launch apache repeatedly via httpd -X
#

AP_CONFS_PATTERN="/etc/apache2/apache2.conf /apache/conf/httpd.conf_* /opt/apache*/conf/httpd.conf_*"

AP_CONF_FILE=$(ls -tr $AP_CONFS_PATTERN 2>/dev/null | tail -1)

AP_BIN=$(echo $AP_CONF_FILE | sed -e "s/\/conf.*//")
AP_BIN="$AP_BIN/bin/httpd"

while [ 1 ]; do
        echo
        if [ "$(whoami)" == "root" ]; then
                kill -KILL $(cat /apache/logs/httpd.pid)
                sleep 1

                # clean up semaphores
                ipcs -s | grep www-data | awk '{ print $2 }' | xargs -n 1 ipcrm sem 2>/dev/null >/dev/null

                echo "Launching apache on config file $AP_CONF_FILE as root"
                $AP_BIN -X -f $AP_CONF_FILE &
        else
                sudo kill -KILL $(cat /apache/logs/httpd.pid)
                sleep 1

                # clean up semaphores
                sudo ipcs -s | grep www-data | awk '{ print $2 }' | xargs -n 1 sudo ipcrm sem 2>/dev/null >/dev/null

                echo "Launching apache on config file $AP_CONF_FILE via sudo"
                sudo $AP_BIN -X -f $AP_CONF_FILE &
        fi

        echo
        read -r -p 'Press enter to restart apache, enter q to stop apache and exit: ' var

        if [ "$var" == "q" ]; then
                sudo kill -KILL $(cat /apache/logs/httpd.pid)
                exit
        fi
done
```

FIXME: Link auf github

Das Skript versucht zunächst die zuletzt bearbeitete lokale Apache Konfigurationsdatei zu identifizieren. Mit sehr hoher Warscheinlichkeit handelt es sich dabei auch um diejenige Konfiguration, welche wir testen möchten. Ist die getroffene Annahme inkorrekt, so empfiehlt sich ein Abbruch des Skriptes und ein `touch` auf die gewünschte Date. Das Skript kennt verschiedene Standorte der Konfigurationsfiles und selektiert jeweils eine Datei. Von dieser Datei leitet es das httpd-Binary ab. Mit diesen Informationen startet es dann eine Schleife. Die Schleife unterscheidet zwischen Aufrufen als `root`-User und als Aufrufen als normaler User. In beiden Varianten bleiben die Aufrufe dieselben, in der zweiten Ausprägung wird den Befehlen einfach das übliche `sudo` vorangestellt. In der Schleife wird dann ein gegebenenfalls laufender Webserver-Prozess gestoppt, dann werden die Semaphoren zurückgeholt und der Server neu gestartet. Als Konfigurationsfile benützt das Skript das zu Beginn erruierte Konfigurationsfile. Wir schicken den Single-Prozess Apache in den Hintergrund, halten ihn aber aktiv in der aktuellen Shell. Er läuft also noch nicht entkoppelt im Hintergrund als Daemon, sondern wird seine Ausgaben weiterhin in unsere Shell-Fenster ausgeben. Wir werden also weiterhin über den Absturz des Prozesses informiert werden.

Bevor wir nun in eine neue Schleifenrunde starten, halten wir aber inne und geben dem Benutzer die Möglichkeit, das Skript entweder mittels der Taste `q` abzubrechen, oder aber eine neue Schleifenrunde mit Hilfe der Enter-Taste zu initiieren. 

Das Skript bringt also eine dreifache Funktionalität:
* Es identifiziert dasjenige Apache Konfigurationsfile, das wir testen möchten.
* Es stoppt und startet auf Tastendruck einen Webserverprozess
* Es sorgt dafür, dass die Semaphoren nicht ausgehen.

Zusammengefasst: Ein Druck auf die Entertaste und Apache wird mit der zuletzt bearbeiteten Konfiguration neu gestartet:

```bash
$> apachex

[sudo] password for folinic: 
Launching apache on config file /apache/conf/httpd.conf_loglevel_test via sudo

Press enter to restart apache, enter q to stop apache and exit: 

Launching apache on config file /apache/conf/httpd.conf_loglevel_test via sudo

Press enter to restart apache, enter q to stop apache and exit: 

Launching apache on config file /apache/conf/httpd.conf_loglevel_test via sudo

Press enter to restart apache, enter q to stop apache and exit: 
``` 

###Schritt 4: watchmelsummary

Nun fehlt uns noch ein gescheiter Zugang zu den Logfiles. Zwar gibt uns `curl -v` bereits Feedback, über die Resultate eines Requests. Aber gerade bei ModSecurity Regeln ist es wichtig, der Verarbeitung auch serverseitig folgen zu können. Und genau ModSecurity ist mit seinem gesprächigen und unübersichtlichen Logfile Format eine Herausforderungen, zumal ein einzelner Aufruf rasch mehr Logeinträge generiert als in einem Fenster platz findet; zumal uns die meisten Informationen nicht interessieren. Was uns fehlt ist eine Zusammenfassung eines Requests über das `Access-Log` und das `Error-Log` hinweg. Das folgende Skript bringt so eine Auswertung:

```bash
$> cat bin/watchmelsummary-script
#!/bin/bash
#
# Watch melsummary of the latest request and enrich output
#  Script meant to be called regularly via watch.
#

if [ -f ${1}/port443-access.log ]; then
        FILE_A=$(echo "${1}/port443-access.log" | sed -e "s:\/\/:/:")
        FILE_E="${1}/port443-error.log"
elif [ -f ${1}/access.log ]; then
        FILE_A=$(echo "${1}/access.log" | sed -e "s:\/\/:/:")
        FILE_E="${1}/error.log"
else
        echo "Accesslog under ${1} not found. This is fatal. Aborting."
        exit 2
fi

LINE=$(tail -200 $FILE_A | grep -v heartbeat | tail -1)
ID=$(echo "$LINE" | egrep -o " [a-zA-Z0-9@-]{24} " | tr -d " ")
METHOD_PATH=$(echo "$LINE" | cut -d\  -f6,7 | cut -b2-)
STATUS=$(echo "$LINE" | cut -d\  -f9)
SCORES=$(echo "$LINE" | egrep -o "[0-9-]+ [0-9-]+$")
TIME=$(echo "$LINE" | cut -d\  -f5 | cut -d. -f1)
echo "$(date +"%H:%M:%S") (now) watching: $FILE_A"
echo
echo "$TIME $STATUS $SCORES $METHOD_PATH ($ID)"
echo
echo "ModSecurity Rules Triggered:"
MODSEC=$(tail -500 $FILE_E | grep $ID | grep -o -E " (at|against) .*\[file.*\[id \"[0-9]+.*\[msg \"[^\"]+" | tr -d \" | sed -e "s/ at the end of input at/ at/" -e "s/ required. /. /" -e "s/\[rev .*\[msg/[msg/" -e "s/\. / /" -e "s/(Total .*/(Total ...) .../" | tr -d \] | cut -d\  -f3,9,11- |
sed -e "s/^\([^ ]*\) \([^ ]*\)/\2 \1/" | awk "{ printf \"%+6s %-35s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s\n\", \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10, \$11, \$12, \$13, \$14, \$15, \$16, \$17, \$18, \$19, \$20 }" | sed -e "s/\ *$//")
if [ -z "$MODSEC" ]; then
        MODSEC="***NONE***"
fi
echo "$MODSEC"
echo
echo "Apache Error Log:"
ERRORLOG=$(tail -500 $FILE_E | grep $ID | grep -v ModSecurity)
if [ -z "$ERRORLOG" ]; then
        ERRORLOG="***NONE***"
fi
echo "$ERRORLOG"
```

FIXME: github Link

Das Skript ist keine sehr elegante Umsetzung der Idee. Vielmehr hat es einen etwas brachialen Charakter, der aber den Vorteil hat, dass die Ausgabe leicht verändert werden kann. Das sie hier auch ausdrücklich empfohlen, denn das Skript dient lediglich als Beispiel, das sich für mich bewährt hat. Schauen wir uns das Skript kurz an. Es erwartet einen Aufruf mit dem Logverzeichnis als Parameter. In diesem Verzeichnis sucht es dann nach einem Access- und einem Error-Log. Kann es diese nicht identifizieren, bricht es ab. Sind sie aber identifiziert, dann wird der letzte Request bestimmt, wobei Heartbeat-Anfragen (etwas von einem Monitoring-Service) ignoriert werden. Aus dieser Anfrage wird die eindeutige Request-Identifikation extrahiert. Dann werden Kernwerte wie Methode, Pfad, Status, ModSecurity Anomaly Scores extrahiert. Diese Daten werden dann ausgegeben.

Als nächstes folgt eine Zusammenfassung der zum Request gehörigen ModSecurity Meldungen. Die sehr undurchsichtige Konstruktion orientiert sich am früher eingeführten Alias `melsummary` das hier in seiner ganzen Komplexität angewendet wird. Zu guter Letzte gibt das Skript noch diejenigen Meldungen des Error-Logs aus, welche nicht durch ModSecurity Alerts darstellen.

Eine typische Ausgabe des Skript sieht wie folgt aus:

```bash
15:48:39 (now) watching: /apache/logs/access.log

15:48:38 404 5 0 POST / (VqY1xn8AAQEAAPhlAk8AAAAF)

ModSecurity Rules Triggered:
950005 ARGS:a                              Remote File Access Attempt
981203 TX:inbound_anomaly_score            Inbound Anomaly Score (Total ...) ...

Apache Error Log:
[2016-01-25 15:48:38.495159] [core:info] 127.0.0.1:37032 VqY1xn8AAQEAAPhlAk8AAAAF AH00129: Attempt to serve directory: /apache/htdocs/
```

Auf der dritten Zeile sehen wir das Timestamp des Requests, den HTTP Status, den ModSecurity Core Rules Incoming Anomaly Score, den Outgoing Anomaly Score, Method, Pfad und schliesslich in Klammern die eindeutige Request-Identifikation. Die übrigen Zeilen erklären sich von selbst.

Der Clou besteht nun darin, dieses Skript mittels `watch` in kurzen Abständen regelmässig aufzurufen. Dazu dient ein eigenes Shortcut-Skript:

```bash
$>cat bin/watchmelsummary
#!/bin/bash
#
# Watch mellidmsg every second
#

watch --interval 1 --no-title "$HOME/bin/watchmelsummary-script /apache/logs/"
```  




###Schritt 5: Aufteilen des Bildschirms in 4 Teile

In den vorangegangenen vier Schritten haben wir gesehen wie wir Apache konfigurieren, ihn einfach starten, ihn möglichst effizient ansprechen und schliesslich das Verhalten in den Logfiles überprüfen. Es bietet sich an, jeden dieser Schritte einem eigenen Shell-Fenster zuzuweisen. Damit kommen wir zu einem klassischen Vier-Fenster-Setup, der sich in der Praxis als sehr effizient erwiesen hat. Eine genügende Anzahl Bildschirme vorausgesetzt spricht nichts dagegen, es mit einem 6 oder 9-Bildschirm-Setup zu probieren, es sei denn man verliere darüber den Überblick.

Für mich hat sich der 4-Bildschirm-Setup bewährt und ich empfehle ihn zur Anwendung bei der Arbeit mit einem Apache Webserver. Ich verwende einen Tiling Windowmanager, aber dies ist natürliche keine Voraussetzung für die Umsetzung dieses Layouts. Wichtig ist allein die Anordnung der Fenster in der richtigen Reihenfolge des Arbeitsablaufes. Mein Auge folgt dabei einem Kreis im Gegenuhrzeigersinn:

* Apache Konfiguration (oben links, Fenster vertikal gestreckt)
* apachex (unten links, Fenster vertikal verkürzt)
* curl (unten rechts)
* watchmelsummary (oben rechts)

Der Ablauf ist damit wie folgt: Die Konfiguration wird oben links angepasst, mit einem Druck auf die Entertaste wird sie unten links neu gestartet. Unten rechts wird der Webserver mit dem gewünschten Curl-Request angesprochen und oben der Inhalt der Logfiles ohne weitere Interaktion über die Tastatur automatisch ausgegeben und von Auge überprüft. Dann der nächste Schritt in er Konfiguration, Neustart, curl, Blick in die Logfiles; und wieder Konfiguration, Neustart, curl, Blick in die Logfiles... 

Dieser zyklische Arbeitsablauf ist sehr schlank gehalten. Er erlaubt mir, in einer Minute, zwei, drei Anpassungszyklen durchzuspielen. So entsteht Schritt um Schritt eine neue Konfiguration. Der schlanke Prozess erlaubt es, auch sehr komplizierte ModSecurity Rezepte zu entwickeln, ohne auf dem Weg den Überblick zu verlieren, weil man sich beim Aufrufen von Curl mit verschiedensten Parametern, dem Editieren der Konfiguration oder dem Lesen der Logfiles verheddert.

Hier ein Bildschirmschnappschuss von meinem Desktop:

FIXME: Screenshot


###Verweise

FIXME: Links







### Lizenz / Kopieren / Weiterverwenden

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />Diese Arbeit ist wie folgt lizenziert / This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

