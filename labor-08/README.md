##Title: Einen Reverse Proxy Server aufsetzen

###Was machen wir?

Wir konfigurieren einen Reverse Proxy oder Gateway Server, der den Zugriff zur Applikation schützt und den Applikationsserver vom Internet abschirmt.

###Warum tun wir das?

Eine moderne Applikationsarchitektur weist mehrere Schichten auf. Gegenüber dem Internet wird nur der Reverse Proxy exponiert. Er führt eine Sicherheitsprüfung auf der Applikationsebene durch und leitet die von ihm für gut befundenen Requests an den Applikationsserver in der zweiten Schicht weiter. Dieser wiederum ist an einen Datenbankserver angebunden, der in einer weiteren Schicht steht. Man spricht von einem Drei-Schichtenmodell (engl. *Three-Tier-Model*). In einer gestaffelten Verteidigung über die drei Schichten hinweg bietet der Reverse Proxy oder technisch korrekt der Gateway Server einen ersten Einblick in die verschlüsselten Anfragen. Auf dem Rückweg ist er wiederum die letzte Instanz, welche die Antworten noch ein letztes Mal überprüfen kann.

Es gibt verschiedene Arten, Apache zu einem Reverse Proxy umzubauen. Vor allem gibt es mehrere Methoden mit den Applikationsservern zu kommunizieren. Wir beschränken und in dieser Anleitung auf das normale, auf *HTTP* basierende *mod_proxy_http*. Weitere Kommunikationsarten wie *FastCGI-Proxy* oder *AJP* behandeln wir hier nicht. Auch auf Apache gibt es mehrere Arten, wie der Proxy-Vorgang angestossen werden kann. Wir betrachten zunächst die normale Konstruktion via *ProxyPass*, besprechen, danach aber auch mehrere Varianten mit Hilfe von *mod_rewrite*.

###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](https://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/) erstellt.
* Verständnis der minimalen Konfiguration in [Anleitung 2 (Apache minimal konfigurieren)](https://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/).
* Ein Apache Webserver mit SSL-/TLS-Unterstützung wie in [Anleitung 4 (Konfigurieren eines SSL Servers)](https://www.netnea.com/cms/apache-tutorial-4-ssl-server-konfigurieren)
* Ein Apache Webserver mit erweitertem Zugriffslog wie in [Anleitung 5 (Das Zugriffslog Ausbauen und Auswerten)](https://www.netnea.com/cms/apache-tutorial-5-zugriffslog-ausbauen/)
* Ein Apache Webserver mit ModSecurity wie in [Anleitung 6 (ModSecurity einbinden)](https://www.netnea.com/cms/apache-tutorial-6-modsecurity-einbinden/)
* Ein Apache Webserver mit einer Core Rules Installation wie in [Anleitung 7 (Core Rules einbinden)](http://www.netnea.com/cms/modsecurity-core-rules-einbinden/)

###Schritt 1: Backend bereitstellen

Der Zweck eines Reverse Proxies ist es, einen Applikationsserver vor direkten Zugriffen aus dem Internet abzuschirmen. Quasi als Voraussetzung für eine diesbezügliche Anleitung benötigen wir also einen solchen Backend-Server.
Prinzipiell bietet sich eine beliebige HTTP Applikation für so eine Installation an und wir könnten gut den Applikationserver aus der dritten Anleitung anwenden. Allerdings scheint es mir gelegen, einen ganz simplen Ansatz zu demonstrieren. Dabei benützen wir das Hilfsmittel *socat*: kurz für *SOcket CAt*. 

```bash
$> sudo socat TCP-LISTEN:8000,bind=127.0.0.1,fork,reuseaddr,crlf EXEC:"/tmp/sender.sh",pty,stderr
``` 

Mit diesem Befehl instruieren wir *socat*, einen *Listener* auf Port 8000 zu installieren und bei einer Verbindung das Skript `/tmp/simpleserver.sh` zu forken. Die weiteren Parameter sorgen dafür, dass der Listener dauerhaft erhalten bleibt, die Errorausgabe funktioniert. Was noch fehlt ist das auszuführende Skript `/tmp/simpleserver.sh`:

```bash
#!/bin/sh
#
# Simple script which prints a http response to stdout.
#

echo "HTTP/1.0 200"
echo "Content-Type: text/txt"
echo "Content-Length: 13"
echo
echo "Hello world!"
```

Vergessen Sie nicht, das die *Permissions* auf *Execute* zu stellen. Probieren wir das mal aus:


```bash
$> ./tmp/simpleserver.sh
HTTP/1.0 200
Content-Type: text/txt
Content-Length: 13

Hello world!
$> curl http://localhost:8000
* Rebuilt URL to: http://localhost:8000/
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 8000 (#0)
> GET / HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost:8000
> Accept: */*
> 
GET / HTTP/1.1
User-Agent: curl/7.35.0
Host: localhost:8000
Accept: */*

HTTP/1.0 200
Content-Type: text/txt
Content-Length: 13

Hello world!
* Connection #0 to host localhost left intact
```


FIXME: Das funktioniert noch nicht so ganz.


###Schritt 2: Das Proxy-Modul laden

LoadModule und FwdProxy Off

### Schritt 3: ProxyPass

Symmetrisch proxen!!!

### Schritt 4: Proxy Stanza

### Schritt 5: Proxy Request verstehen

### Schritt 6: ModRewrite [proxy]

### Schritt 7: RewriteMap [proxy]

### Schritt 8: Balancer [proxy]

### Schritt 9: Blabla

mod_sed



