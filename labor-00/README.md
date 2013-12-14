##Kompilieren eines Apache Webservers

###Was machen wir?

Wir kompilieren einen Apache Webservers für ein Testsystem

###Warum tun wir das?

Im professionellen Einsatz des Webservers geschieht es regelmässig, dass besondere Bedürfnisse (Security, zusätzliche Debug-Messages, spezielle Funktionalität dank eines neuen Patches etc.) einen zwingen, sich von den Distributionspaketen zu verabschieden und rasch eigene Binaries herzustellen.In diesem Fall ist es wichtig, dass die Infrastruktur bereit steht und man erste Erfahrungen mit dem Kompilieren und Produktivschalten der eigenen Binaries mitbringt. Zudem lässt sich in einem Laborsetup leichter mit einem selbst kompilierten Apache arbeiten, was auch beim Debuggen von Vorteil ist.

###Schritt 1: Bereitmachen des Verzeichnisbaumes für den Sourcecode

Prinzipiell spielt es keine grosse Rolle, wo der Sourcecode liegt. Das Folgende ist ein Vorschlag, der sich am [File Hierarchy Standard](http://www.pathname.com/fhs/) orientiert. Der FHS definiert den Pfadbaum eines Unix-Systems; also die Ablagestruktur für sämtliche Dateien.

```bash
$> sudo mkdir /usr/src/apache
$> sudo chown `whoami` /usr/src/apache
```

###Schritt 2: Herunterladen des Sourcecodes

Jetzt laden wir den Programmcode vom Netz herunter. Man kann das mit dem Browser direkt von [Apache](https://httpd.apache.org/) tun, oder man schont die Bandbreite des Apache Projektes und zieht ihn mittels wget von einem Mirror.

```bash
$> cd /usr/src/apache
$> wget http://apache.mirror.clusters.cc/httpd/httpd-2.2.25.tar.gz
```

Der gepackte Sourcecode hat etwa eine Grösse von 7MB.

###Schritt 3: Überprüfen der Checksumme

Normalerweise geht nichts schief. Aber es ist eine gute Angewohnheit, Sourcecode auf seine Integrität hin zu prüfen. Dazu laden wir die Checksumme der Sourcecodedatei direkt von Apache herunter. Sicherheitshalber verwenden wir dazu eine gesicherte Verbindung. Ohne https macht das keinen grossen Sinn.

```bash
$> wget https://www.apache.org/dist/httpd/httpd-2.2.25.tar.gz.sha1
```

Beide Files, der Sourcecode und die kleine Prüfsummendatei sollten nebeneinander in `/usr/src/apache liegen. Zeit die Prüfsumme zu testen:

```bash
$> sha1sum --check httpd-2.2.25.tar.gz.sha1
```

Wir erwarten Folgendes als Antwort:

```bash
httpd-2.2.25.tar.gz: OK
```

###Schritt 4: Entpacken und Compiler Konfigurieren

Nach der Überprüfung können wir das Paket entpacken.

```bash
$> tar xvzf httpd-2.2.25.tar.gz
```

Das ergibt nun etwa 38MB.

Wir gehen nun in das Verzeichnis und konfigurieren den Compiler mit unseren Eingaben und mit Informationen zu unserem System. Neben den Optionen der Kommando-Zeile sucht sich das Configure-Skript selbst sehr viele Informationen zu unserem System zusammen. Dies Infos werden dann für den Compiler bereit gestellt.

```bash
$> cd httpd-2.2.25
$> ./configure --prefix=/opt/apache-2.2.25 --with-mpm=worker --enable-mods-shared=all --with-included-apr
```

Hier bestimmen wir das Zielverzeichnis für den zukünftigen Apache Webserver; wieder konform mit dem FHS. Wichtig ist die nächste Option with-mpm. Damit bestimmen wir das sogenannte Prozessmodell des Servers. Das ist – vereinfacht gesagt – so etwas wie der Motorentyp der Maschine: Benzin oder Diesel. In unserem Fall stehen worker, prefork und ein paar experimentelle Motoren zur Verfügung. Wir nehmen hier den worker, der etwas schneller ist und sich neben einigen Nachteilen vor allem für das Bereitstellen statischer Files und als Secure Reverse Proxy eignet. Mehr Infos zur bisweilen komplizierten Wahl des richtigen Motors liefert das Apache Projekt.

Dann bestimmen wir noch, dass wie alle (all) Module mitkompilieren möchten. Dabei ist zu wissen, dass all hier nicht wirklich alle bedeutet. Aus historischen Gründen meint all nur sämtliche Kern-Module Und nn definieren wir, dass wir die dem Programmcode beiliegende APR benutzen möchten. Wenn das MPM der Motor war, dann ist das APR sowas wie das Chassis der Maschine.

Der Configure-Befehl beschwert sich oft über fehlende Komponenten. Ist klar: Ohne funktionierenden Compiler können wir nicht kompilieren und das Configure hat die Aufgabe nachzusehen, ob alles gut beisammen ist.

Sachen, die typischerweise fehlen, sind Folgende:

- binutils
- gcc
- zlibc
- zlib1g-dev

(je nach Distribution mag dieses Paket anders heissen)

Das lässt sich leicht beheben, indem man sie mit den Hilfsmitteln der eigenen Distribution nachinstalliert. Danach configure neu ausführen, eventuell nochmals zwei, drei Mal etwas nachinstallieren und irgendwann läuft das Skript dann erfolgreich durch.

###Schritt 5: Kompilieren
Nun sind wir bereit für den Compiler. Hier sollte nun nichts mehr schief gehen.

```bash
$> make
```

Das dauert einen Moment und aus den 38MB werden gut 70MB.

###Schritt 7: Installieren
Wenn das geklappt hat, dann installieren wir den selbst gebauten Apache Webserver. Wir müssen das Installieren durch den Superuser vornehmen lassen. Aber danach schauen wir gleich zu, dass wir wieder in Besitz des Webservers kommen. Für ein Testsystem ist das viel praktischer.

```bash
$> sudo make install
```

Auch die Installation dauert eine Weile.

```bash
$> sudo chown -R `whoami` /opt/apache-2.2.25
```

Und jetzt noch ein Kniff: Wenn man professionell mit Apache arbeitet, dann hat man oft mehrere verschiedene Versionen nebeneinander auf der Testmaschine. Verschiedene Versionen, verschiedene Patches, andere Module etc. führen zu recht mühsamen und langsamen Pfaden mit Versionsnummern und weiteren Beschreibungen. Ich mache es dann jeweils so, dass ich einen Softlink von /apache auf den aktuellen Apache Webserver lege. Dabei ist darauf zu achten, dass auch der Softlink uns und nicht dem root-User gehört (Dies wird bei der Konfiguration des Servers wichtig).

```bash
$> sudo ln -s /opt/apache-2.2.25 /apache
$> sudo chown `whoami` --no-dereference /apache
$> cd /apache
```

Unser Webserver hat nun also einen klaren Pfad, der ihn mit der Versionsnummer eindeutig beschreibt. Im Alltag verwenden wir aber einfach /apache für den Zugriff. Das erleichtert die Arbeit.

###Schritt 8: Starten

Dann wollen wir mal sehen, ob die Maschine anspringt. Das müssen wir für den Moment wieder durch den Superuser erledigen lassen:

```bash
$> sudo ./bin/httpd -X
```

Das ist wieder ein Kniff für den Testbetrieb: Apache ist eigentlich ein Daemon der im Hintergrund läuft. Für einfache Tests ist das aber eher nervig, da wir den Daemon andauernd starten, stoppen, neu laden und sonstwie manipulieren müssen. Mit der Option -X teilen wir Apache mit, dass er sich das mit dem Daemon erst mal sparen und dass er schön im Vordergrund als Single-Prozess/-Thread bleiben soll. Auch das hilft bei der Arbeit.

Vermutlich gibt es nun beim Start eine Warnung:

```bash
httpd: Could not reliably determine the server's fully qualified domain name, using 127.0.0.1 for ServerName
```

Das ist nicht weiter schlimm und wir können sie für den Moment ignorieren.

###Schritt 9: Ausprobieren

Die Maschine läuft nun also. Aber funktioniert sie auch? Zeit für den Funktionstest: Wir sprechen den Apache mit dem Browser unter folgendem Link an:

http://127.0.0.1

Da erwarten wir dann Folgendes:

(Link zu Bild)

Im Browser zeigt der Apache ein erstes Lebenszeichen.

Super! Ziel erreicht: Der selbst kompilierte Apache läuft.

Zurück in die Shell und Abschalten des Servers mit STRG-C oder für uns Schweizer mit CTRL-C.

###Schritt 10 (Bonus): Ansehen des Binaries und der Module

Der Webserver läuft nun also. Aber vielleicht möchten wir ihn noch etwas genauer ansehen und mit den Fingern über die Karosserie streichen. Informationen zu unserem Binary erhalten wir wie folgt:

```bash
$> ./bin/httpd -V
```

```bash
Server version: Apache/2.2.25 (Unix)
Server built:   Jul  9 2013 09:49:05
Server's Module Magic Number: 20051115:33
Server loaded:  APR 1.4.9-dev, APR-Util 1.4.3-dev
Compiled using: APR 1.4.9-dev, APR-Util 1.4.3-dev
Architecture:   64-bit
Server MPM:     Worker
  threaded:     yes (fixed thread count)
    forked:     yes (variable process count)
Server compiled with....
 -D APACHE_MPM_DIR="server/mpm/worker"
 -D APR_HAS_SENDFILE
 -D APR_HAS_MMAP
 -D APR_HAVE_IPV6 (IPv4-mapped addresses enabled)
 -D APR_USE_SYSVSEM_SERIALIZE
 -D APR_USE_PTHREAD_SERIALIZE
 -D SINGLE_LISTEN_UNSERIALIZED_ACCEPT
 -D APR_HAS_OTHER_CHILD
 -D AP_HAVE_RELIABLE_PIPED_LOGS
 -D DYNAMIC_MODULE_LIMIT=128
 -D HTTPD_ROOT="/opt/apache-2.2.25"
 -D SUEXEC_BIN="/opt/apache-2.2.25/bin/suexec"
 -D DEFAULT_SCOREBOARD="logs/apache_runtime_status"
 -D DEFAULT_ERRORLOG="logs/error_log"
 -D AP_TYPES_CONFIG_FILE="conf/mime.types"
 -D SERVER_CONFIG_FILE="conf/httpd.conf"
```

Da wird die Version angegeben, wann wir kompiliert haben, das APR kommt wieder zur Sprache und weiter unten das MPM. Ganz unten finden wir übrigens den Hinweis auf das Standard-Konfigurationsfile des Webservers und etwas darüber den Pfad, unter dem wir das Errorlog finden können.

Man kann aber noch etwas mehr aus dem System rausholen und ihn etwa nach den Modulen fragen, welche fix in den Server hineinkompiliert sind:

```bash
$> ./bin/httpd -l
```

```bash
Compiled in modules:
  core.c
  worker.c
  http_core.c
  mod_so.c
```

Diese und die obenstehenden Informationen helfen bei der Fehlersuche und wenn man einen Bugreport einsenden will. Dies sind typischerweise auch die ersten Fragen, welche gestellt werden.

Das Binary selbst (/apache/bin/httpd) ist übrigens ungefähr 1.2MB gross und die Liste der Module sieht folgendermassen aus:

```bash
$> ls -lh modules
```

```bash
total 3.4M
-rw-r--r-- 1 myuser myuser 9.0K Jul  9 07:49 httpd.exp
-rwxr-xr-x 1 myuser root    32K Jul  9 09:30 mod_actions.so
-rwxr-xr-x 1 myuser root    45K Jul  9 09:30 mod_alias.so
-rwxr-xr-x 1 myuser root    29K Jul  9 09:30 mod_asis.so
-rwxr-xr-x 1 myuser root    33K Jul  9 09:30 mod_auth_basic.so
-rwxr-xr-x 1 myuser root    81K Jul  9 09:30 mod_auth_digest.so
-rwxr-xr-x 1 myuser root    30K Jul  9 09:30 mod_authn_anon.so
-rwxr-xr-x 1 myuser root    33K Jul  9 09:30 mod_authn_dbd.so
-rwxr-xr-x 1 myuser root    31K Jul  9 09:30 mod_authn_dbm.so
-rwxr-xr-x 1 myuser root    24K Jul  9 09:30 mod_authn_default.so
-rwxr-xr-x 1 myuser root    32K Jul  9 09:30 mod_authn_file.so
-rwxr-xr-x 1 myuser root    33K Jul  9 09:30 mod_authz_dbm.so
-rwxr-xr-x 1 myuser root    24K Jul  9 09:30 mod_authz_default.so
-rwxr-xr-x 1 myuser root    33K Jul  9 09:30 mod_authz_groupfile.so
-rwxr-xr-x 1 myuser root    34K Jul  9 09:30 mod_authz_host.so
-rwxr-xr-x 1 myuser root    30K Jul  9 09:30 mod_authz_owner.so
-rwxr-xr-x 1 myuser root    29K Jul  9 09:30 mod_authz_user.so
-rwxr-xr-x 1 myuser root    97K Jul  9 09:30 mod_autoindex.so
-rwxr-xr-x 1 myuser root    32K Jul  9 09:30 mod_cern_meta.so
-rwxr-xr-x 1 myuser root    93K Jul  9 09:30 mod_cgid.so
-rwxr-xr-x 1 myuser root   191K Jul  9 09:30 mod_dav_fs.so
-rwxr-xr-x 1 myuser root   351K Jul  9 09:30 mod_dav.so
-rwxr-xr-x 1 myuser root    58K Jul  9 09:30 mod_dbd.so
-rwxr-xr-x 1 myuser root    63K Jul  9 09:30 mod_deflate.so
-rwxr-xr-x 1 myuser root    32K Jul  9 09:30 mod_dir.so
-rwxr-xr-x 1 myuser root    33K Jul  9 09:30 mod_dumpio.so
-rwxr-xr-x 1 myuser root    31K Jul  9 09:30 mod_env.so
-rwxr-xr-x 1 myuser root    41K Jul  9 09:30 mod_expires.so
-rwxr-xr-x 1 myuser root    64K Jul  9 09:30 mod_ext_filter.so
-rwxr-xr-x 1 myuser root   347K Jul  2 11:12 mod_fcgid.so
-rwxr-xr-x 1 myuser root    53K Jul  9 09:30 mod_filter.so
-rwxr-xr-x 1 myuser root    58K Jul  9 09:30 mod_headers.so
-rwxr-xr-x 1 myuser root    35K Jul  9 09:30 mod_ident.so
-rwxr-xr-x 1 myuser root    50K Jul  9 09:30 mod_imagemap.so
-rwxr-xr-x 1 myuser root   133K Jul  9 09:30 mod_include.so
-rwxr-xr-x 1 myuser root    50K Jul  9 09:30 mod_info.so
-rwxr-xr-x 1 myuser root    86K Jul  9 09:30 mod_log_config.so
-rwxr-xr-x 1 myuser root    36K Jul  9 09:30 mod_log_forensic.so
-rwxr-xr-x 1 myuser root    31K Jul  9 09:30 mod_logio.so
-rwxr-xr-x 1 myuser root    80K Jul  9 09:30 mod_mime_magic.so
-rwxr-xr-x 1 myuser root    54K Jul  9 09:30 mod_mime.so
-rwxr-xr-x 1 myuser root   106K Jul  9 09:30 mod_negotiation.so
-rwxr-xr-x 1 myuser root    44K Jul  9 09:30 mod_reqtimeout.so
-rwxr-xr-x 1 myuser root   175K Jul  9 09:30 mod_rewrite.so
-rwxr-xr-x 1 myuser root    42K Jul  9 09:30 mod_setenvif.so
-rwxr-xr-x 1 myuser root    40K Jul  9 09:30 mod_speling.so
-rwxr-xr-x 1 myuser root    56K Jul  9 09:30 mod_status.so
-rwxr-xr-x 1 myuser root    43K Jul  9 09:30 mod_substitute.so
-rwxr-xr-x 1 myuser root    31K Jul  2 10:44 mod_suexec.so
-rwxr-xr-x 1 myuser root    32K Jul  9 09:30 mod_unique_id.so
-rwxr-xr-x 1 myuser root    33K Jul  9 09:30 mod_userdir.so
-rwxr-xr-x 1 myuser root    42K Jul  9 09:30 mod_usertrack.so
-rwxr-xr-x 1 myuser root    26K Jul  9 09:30 mod_version.so
-rwxr-xr-x 1 myuser root    40K Jul  9 09:30 mod_vhost_alias.so
```

Das sind nun alle Module, welche von Apache zusammen mit dem Server verteilt werden. Weitere Module gibt es von Drittanbietern. Alle brauchen wir kaum, aber einige will man fast immer dabei haben: Sie sind nun schon vorkonfiguriert.

#####Verweise
- [Frühere Versionen] (http://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/)
- Apache [http://httpd.apache.org] (http://httpd.apache.org)
- File Hierarchy Standard: [http://www.pathname.com/fhs/](http://www.pathname.com/fhs/)
- Apache ./configure documenation: [http://httpd.apache.org/docs/trunk/programs/configure.html](http://httpd.apache.org/docs/trunk/programs/configure.html)