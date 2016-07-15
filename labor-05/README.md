##Title: ModSecurity einbinden 

###Was machen wir?
Wir kompilieren das Sicherheits-Modul ModSecurity, binden es in den Apache Webserver ein, erstellen eine Basis-Konfiguration und setzen uns erstmals mit _False Positives_ auseinander.

###Warum tun wir das?

ModSecurity ist ein Sicherheitsmodul für den Webserver. Das Hilfsmittel ermöglicht die Überprüfung sowohl der Anfrage als auch der Antwort nach vordefinierten Regeln. Man nennt das auch _Web Application Firewall_. Der Administrator erhält also eine direkte Kontrolle über die Requests und die Responses, welche das System durchlaufen. Das Modul gibt einem aber auch neue Möglichkeiten zum Monitoring in die Hand, denn der gesamte Verkehr zwischen Client und Server lässt sich 1:1 auf die Festplatte schreiben. Dies hilft bei der Fehlersuche.
Eine _WAF_ greift in den HTTP Verkehr ein. Das führt zu Fehlern, wenn sie eine legitime Anfrage blockiert. Man nennt dies _False Positive_. Da die Behandlung dieser Fehler ein wichtiger Teil der Arbeit mit _ModSecurity_ ist, versuchen wir uns von Beginn weg in dieser Disziplin.

###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](https://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/) erstellt.
* Verständnis der minimalen Konfiguration in [Anleitung 2 (Apache minimal konfigurieren)](https://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/).
* Ein Apache Webserver mit SSL-/TLS-Unterstützung wie in [Anleitung 4 (Konfigurieren eines SSL Servers)](https://www.netnea.com/cms/apache-tutorial-4-ssl-server-konfigurieren)
* Ein ausgebautes Zugriffslog und einen Satz von Shell-Aliasen wie in [Anleitung 5 (Das Zugriffslog Ausbauen und Auswerten)](https://www.netnea.com/cms/apache-tutorials/apache-tutorial-5-zugriffslog-ausbauen)

###Schritt 1: Sourcecode herunterladen und Checksum prüfen

Den Sourcecode für den Webserver haben wir nach `/usr/src/apache` heruntergeladen. Desgleichen verfahren wir nun mit ModSecurity. Dazu legen wir als Root das Verzeichnis `/usr/src/modsecurity/` an, übergeben es uns selbst und laden dann den Code herunter. 

```bash
$> sudo mkdir /usr/src/modsecurity
$> sudo chown `whoami` /usr/src/modsecurity
$> cd /usr/src/modsecurity
$> wget https://www.modsecurity.org/tarball/2.9.0/modsecurity-2.9.0.tar.gz
```

Der gepackte Sourcecode ist gut vier Megabyte gross. Nun bleibt noch das überprüfen der Checksum. Sie wird im Format SHA256 angeboten.

```bash
$> wget https://www.modsecurity.org/tarball/2.9.0/modsecurity-2.9.0.tar.gz.sha256
$> sha256sum --check modsecurity-2.9.0.tar.gz.sha256
```

Darauf erwarten wir folgende Antwort:

```bash
modsecurity-2.9.0.tar.gz: OK
```

###Schritt 2: Entpacken und Compiler konfigurieren

Wir entpacken nun den Sourcecode und leiten die Konfiguration ein. Noch vorher gilt es aber drei Pakete zu installieren, die eine Voraussetzung für das Kompilieren von _ModSecurity_ bilden. Eine Library zum Parsen von XML-Strukturen und die Grundlagen-/Header-Dateien der systemeigenen Regular Expression Library: _libxml2-dev_, _libexpat1-dev_ und _libpcre3-dev_.

Damit sind die Voraussetzungen geschaffen und wir sind bereit für ModSecurity.

```bash
$> tar xvzf modsecurity-2.9.0.tar.gz
$> cd modsecurity-2.9.0
$> ./configure --with-apxs=/apache/bin/apxs \
--with-apr=/usr/local/apr/bin/apr-1-config \
--with-pcre=/usr/bin/pcre-config \
--enable-request-early
```

Wir haben im Tutorial zur Kompilierung von Apache den Symlink `/apache` angelegt. Das kommt uns nun erneut zu Hilfe, denn unabhängig von der verwendeten Apache-Version können wir die ModSecurity Konfiguration nun immer mit denselben Parametern arbeiten lassen und erhalten immer Zugriff auf den aktuellen Apache Webserver. Die ersten beiden Optionen stellen die Verbindung zum Apache Binary her, denn wir müssen dafür sorgen, dass ModSecurity mit der richtigen API-Version arbeitet. Die Option _with-pcre_ legt fest, dass wir die systemeigene _PCRE-Library_, also Regular Expression Bibliothek, verwenden, und nicht die von Apache zur Verfügung gestellte. Dies gibt uns eine gewisse Flexibilität bei den Updates, da wir damit in diesem Bereich unabhängig von Apache werden, was sich in der Praxis bewährt hat. Voraussetzung ist das eben erst installierte Paket _libpcre3-dev_ Die letzte Option _enable-request-early_ greift in das Verhalten von ModSecurity ein. Sie führt dazu, dass unser Sicherheitssystem die erste Verarbeitungsphase nach Erhalt der Request Header in Angriff nimmt. Wir warten also nicht den fertigen Request inklusive der Body-Daten ab, sondern können sofort eingreifen. Das ist zwar nur ein Detail, gibt in der Praxis aber etwas stärkere Kontrolle.

###Schritt 3: Kompilieren

Nach dieser Vorbereitung sollte das Kompilieren keine Probleme mehr bereiten.

```bash
$> make
```


###Schritt 4: Installieren

Und auch die Installation geht leicht vonstatten. Weil wir uns nach wie vor auf einem Testsystem befinden, übergeben wir das installierte Modul vom Root-Benutzer uns selbst, denn auch bei den ganzen Apache Binaries haben wir dafür gesorgt, selbst der Besitzer zu sein. Das ergibt dann wiederum einen sauberen Setup mit einheitlichen Besitzverhältnissen.

```bash
$> sudo make install
$> sudo chown `whoami` /apache/modules/mod_security2.so
```

Das Modul trägt die Zahl `2` im Namen. Dies wurde beim Versionsprung auf 2.0 eingeführt, als eine Neuausrichtung des Moduls dies nötig machte. Dies ist aber nur ein Detail, das keine Rolle spielt.

###Schritt 5: Grundkonfiguration erstellen

Wir können nun daran gehen, eine Grundkonfiguration einzurichten. ModSecurity ist ein Modul, das durch Apache geladen wird. Es wird deshalb innerhalb der Apache-Konfiguration konfiguriert. Normalerweise wird empfohlen, ModSecurity in einem eigenen File zu konfigurieren und dann als sogenanntes `Include` nachzuladen. Wir machen das aber nur mit einem Teil der Regeln (in einem späteren Tutorial). Die Grundkonfiguration fügen wir in die Apache-Konfiguration ein, um sie immer im Blick zu haben. Dabei bauen wir auf unserer Apache Basiskonfiguration auf. Natürlich kann man diese Konfiguration auch mit dem `SSL-Setup` und dem `Applikations-Server-Setup` kombinieren. Letzteres unterlassen wir der Einfachheit halber aber. Was wir aber einbinden ist das erweiterte LogFormat, das wir in der 5. Anleitung kennengelernt haben. Dazu kommt ein weiteres, optionales Performance-Log, das bei der Suche nach Geschwindigkeitsengpässen hilft.

```bash
ServerName        localhost
ServerAdmin       root@localhost
ServerRoot        /apache
User              www-data
Group             www-data
PidFile           logs/httpd.pid

ServerTokens      Prod
UseCanonicalName  On
TraceEnable       Off

Timeout           10
MaxClients        100

Listen            127.0.0.1:80
Listen            127.0.0.1:443

LoadModule        mpm_event_module        modules/mod_mpm_event.so
LoadModule        unixd_module            modules/mod_unixd.so

LoadModule        log_config_module       modules/mod_log_config.so
LoadModule        logio_module            modules/mod_logio.so

LoadModule        authn_core_module       modules/mod_authn_core.so
LoadModule        authz_core_module       modules/mod_authz_core.so

LoadModule        ssl_module              modules/mod_ssl.so

LoadModule        unique_id_module        modules/mod_unique_id.so
LoadModule        security2_module        modules/mod_security2.so

ErrorLogFormat          "[%{cu}t] [%-m:%-l] %-a %-L %M"
LogFormat "%h %{GEOIP_COUNTRY_CODE}e %u [%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %v %A %p %R %{BALANCER_WORKER_ROUTE}e %X \"%{cookie}n\" %{UNIQUE_ID}e %{SSL_PROTOCOL}x %{SSL_CIPHER}x %I %O %{ratio}n%% %D %{ModSecTimeIn}e %{ApplicationTime}e %{ModSecTimeOut}e %{ModSecAnomalyScoreIn}e %{ModSecAnomalyScoreOut}e" extended

LogFormat "[%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] %{UNIQUE_ID}e %D \
PerfModSecInbound: %{TX.perf_modsecinbound}M \
PerfAppl: %{TX.perf_application}M \
PerfModSecOutbound: %{TX.perf_modsecoutbound}M \
TS-Phase1: %{TX.ModSecTimestamp1start}M-%{TX.ModSecTimestamp1end}M \
TS-Phase2: %{TX.ModSecTimestamp2start}M-%{TX.ModSecTimestamp2end}M \
TS-Phase3: %{TX.ModSecTimestamp3start}M-%{TX.ModSecTimestamp3end}M \
TS-Phase4: %{TX.ModSecTimestamp4start}M-%{TX.ModSecTimestamp4end}M \
TS-Phase5: %{TX.ModSecTimestamp5start}M-%{TX.ModSecTimestamp5end}M \
Perf-Phase1: %{PERF_PHASE1}M \
Perf-Phase2: %{PERF_PHASE2}M \
Perf-Phase3: %{PERF_PHASE3}M \
Perf-Phase4: %{PERF_PHASE4}M \
Perf-Phase5: %{PERF_PHASE5}M \
Perf-ReadingStorage: %{PERF_SREAD}M \
Perf-WritingStorage: %{PERF_SWRITE}M \
Perf-GarbageCollection: %{PERF_GC}M \
Perf-ModSecLogging: %{PERF_LOGGING}M \
Perf-ModSecCombined: %{PERF_COMBINED}M" perflog

LogLevel                      debug
ErrorLog                      logs/error.log
CustomLog                     logs/access.log extended
CustomLog                     logs/modsec-perf.log perflog env=write_perflog

# == ModSec Base Configuration

SecRuleEngine                 On

SecRequestBodyAccess          On
SecRequestBodyLimit           10000000
SecRequestBodyNoFilesLimit    64000

SecResponseBodyAccess         On
SecResponseBodyLimit          10000000

SecPcreMatchLimit             15000
SecPcreMatchLimitRecursion    15000

SecTmpDir                     /tmp/
SecDataDir                    /tmp/
SecUploadDir                  /tmp/

SecDebugLog                   /apache/logs/modsec_debug.log
SecDebugLogLevel              0

SecAuditEngine                RelevantOnly
SecAuditLogRelevantStatus     "^(?:5|4(?!04))"
SecAuditLogParts              ABIJEFHKZ

SecAuditLogType               Concurrent
SecAuditLog                   /apache/logs/modsec_audit.log
SecAuditLogStorageDir         /apache/logs/audit/

SecDefaultAction              "phase:1,pass,log,tag:'Local Lab Service'"


# == ModSec Rule ID Namespace Definition
# Service-specific before Core-Rules:    10000 -  49999
# Service-specific after Core-Rules:     50000 -  79999
# Locally shared rules:                  80000 -  99999
#  - Performance:                        90000 -  90199
# Recommended ModSec Rules (few):       200000 - 200010
# OWASP Core-Rules:                     900000 - 999999


# === ModSec timestamps at the start of each phase (ids: 90000 - 90009)

SecAction "id:'90000',phase:1,nolog,pass,setvar:TX.ModSecTimestamp1start=%{DURATION}"
SecAction "id:'90001',phase:2,nolog,pass,setvar:TX.ModSecTimestamp2start=%{DURATION}"
SecAction "id:'90002',phase:3,nolog,pass,setvar:TX.ModSecTimestamp3start=%{DURATION}"
SecAction "id:'90003',phase:4,nolog,pass,setvar:TX.ModSecTimestamp4start=%{DURATION}"
SecAction "id:'90004',phase:5,nolog,pass,setvar:TX.ModSecTimestamp5start=%{DURATION}"
                      
# SecRule REQUEST_FILENAME "@beginsWith /" "id:'90005',phase:5,t:none,nolog,noauditlog,pass,setenv:write_perflog"



# === ModSec Recommended Rules (in modsec src package) (ids: 200000-200010)

SecRule REQUEST_HEADERS:Content-Type "text/xml" "id:'200000',phase:1,t:none,t:lowercase,pass,nolog,ctl:requestBodyProcessor=XML"

SecRule REQBODY_ERROR "!@eq 0" "id:'200001',phase:2,t:none,deny,status:400,log,msg:'Failed to parse request body.',\
logdata:'%{reqbody_error_msg}',severity:2"

SecRule MULTIPART_STRICT_ERROR "!@eq 0" \
"id:'200002',phase:2,t:none,log,deny,status:403, \
msg:'Multipart request body failed strict validation: \
PE %{REQBODY_PROCESSOR_ERROR}, \
BQ %{MULTIPART_BOUNDARY_QUOTED}, \
BW %{MULTIPART_BOUNDARY_WHITESPACE}, \
DB %{MULTIPART_DATA_BEFORE}, \
DA %{MULTIPART_DATA_AFTER}, \
HF %{MULTIPART_HEADER_FOLDING}, \
LF %{MULTIPART_LF_LINE}, \
SM %{MULTIPART_MISSING_SEMICOLON}, \
IQ %{MULTIPART_INVALID_QUOTING}, \
IP %{MULTIPART_INVALID_PART}, \
IH %{MULTIPART_INVALID_HEADER_FOLDING}, \
FL %{MULTIPART_FILE_LIMIT_EXCEEDED}'"

SecRule TX:/^MSC_/ "!@streq 0" "id:'200004',phase:2,t:none,deny,status:500,msg:'ModSecurity internal error flagged: %{MATCHED_VAR_NAME}'"


# === ModSecurity Rules 
#
# ...
                

# === ModSec timestamps at the end of each phase (ids: 90010 - 90019)

SecAction "id:'90010',phase:1,pass,nolog,setvar:TX.ModSecTimestamp1end=%{DURATION}"
SecAction "id:'90011',phase:2,pass,nolog,setvar:TX.ModSecTimestamp2end=%{DURATION}"
SecAction "id:'90012',phase:3,pass,nolog,setvar:TX.ModSecTimestamp3end=%{DURATION}"
SecAction "id:'90013',phase:4,pass,nolog,setvar:TX.ModSecTimestamp4end=%{DURATION}"
SecAction "id:'90014',phase:5,pass,nolog,setvar:TX.ModSecTimestamp5end=%{DURATION}"


# === ModSec performance calculations and variable export (ids: 90100 - 90199)

SecAction "id:'90100',phase:5,pass,nolog,setvar:TX.perf_modsecinbound=%{PERF_PHASE1}"
SecAction "id:'90101',phase:5,pass,nolog,setvar:TX.perf_modsecinbound=+%{PERF_PHASE2}"
SecAction "id:'90102',phase:5,pass,nolog,setvar:TX.perf_application=%{TX.ModSecTimestamp3start}"
SecAction "id:'90103',phase:5,pass,nolog,setvar:TX.perf_application=-%{TX.ModSecTimestamp2end}"
SecAction "id:'90104',phase:5,pass,nolog,setvar:TX.perf_modsecoutbound=%{PERF_PHASE3}"
SecAction "id:'90105',phase:5,pass,nolog,setvar:TX.perf_modsecoutbound=+%{PERF_PHASE4}"
SecAction "id:'90106',phase:5,pass,nolog,setenv:ModSecTimeIn=%{TX.perf_modsecinbound}"
SecAction "id:'90107',phase:5,pass,nolog,setenv:ApplicationTime=%{TX.perf_application}"
SecAction "id:'90108',phase:5,pass,nolog,setenv:ModSecTimeOut=%{TX.perf_modsecoutbound}"
SecAction "id:'90109',phase:5,pass,nolog,setenv:ModSecAnomalyScoreIn=%{TX.inbound_anomaly_score}"
SecAction "id:'90110',phase:5,pass,nolog,setenv:ModSecAnomalyScoreOut=%{TX.outbound_anomaly_score}"



SSLCertificateKeyFile   /etc/ssl/private/ssl-cert-snakeoil.key
SSLCertificateFile      /etc/ssl/certs/ssl-cert-snakeoil.pem

SSLProtocol             All -SSLv2 -SSLv3
SSLCipherSuite          'kEECDH+ECDSA kEECDH kEDH HIGH +SHA !aNULL !eNULL !LOW !MEDIUM !MD5 !EXP !DSS !PSK !SRP !kECDH !CAMELLIA !RC4'
SSLHonorCipherOrder     On

SSLRandomSeed           startup file:/dev/urandom 2048
SSLRandomSeed           connect builtin

DocumentRoot            /apache/htdocs

<Directory />
      
        Require all denied

        Options SymLinksIfOwnerMatch
        AllowOverride None

</Directory>

<VirtualHost 127.0.0.1:80>
      
      <Directory /apache/htdocs>

        Require all granted

        Options None
        AllowOverride None

      </Directory>

</VirtualHost>

<VirtualHost 127.0.0.1:443>
    
      SSLEngine On

      <Directory /apache/htdocs>

              Require all granted

              Options None
              AllowOverride None

      </Directory>

</VirtualHost>
```

Neu sind die Module *mod_security2.so* und *mod_unique_id.so* sowie das zusätzliche Performance-Log hinzugekommen. Zunächst definieren wir das _LogFormat_, einige Zeilen weiter unten dann das File _logs/modsec-perf.log_. Hinten auf dieser Zeile ist eine Bedingung eingefügt: Nur wenn die Umgebungsvariable *write_perflog* gesetzt ist, wird dieses Logfile wirklich geschrieben. Wir können also pro Request entscheiden, ob wir die Performance-Daten brauchen oder nicht. Dies schont die Ressourcen und gibt uns die Möglichkeit, punktgenau zu arbeiten: So können wir etwa nur bestimmte Pfade in das Log einbeziehen oder uns auf einzelne Client-IP Adressen konzentrieren.

Auf der nächsten Zeile beginnt die ModSecurity Grundkonfiguration: In diesem Teil legen wir die Basiseinstellungen des Moduls fest. In einem späteren Teil folgen dann einzelne Sicherheitsregeln, die meist etwas komplizierter sind. Gehen wir die Konfiguration Schritt für Schritt durch: Mit _SecRuleEngine_ wird ModSecurity überhaupt erst eingeschaltet. Dann schalten wir den Zugriff auf den Request-Body ein und setzen zwei Limiten: Per Default werden nämlich nur die Header-Zeilen des Requests überprüft. Das ist so, wie wenn man bei einem Brief nur den Umschlag betrachten würde. Den Body und damit den Inhalt des Requests zu überprüfen, ist natürlich mehr Arbeit und braucht mehr Zeit, aber zahlreiche Angriffe sind nicht schon von aussen erkennbar, weshalb wir dies einschalten. Die Grösse des Request-Bodies limitieren wir dann auf 10MB. Das schliesst File-Uploads mit ein. Für Requests mit Body aber ohne File-Upload, also etwa ein Online-Formular, geben wir dann 64KB als Limite an. Im Detail ist *SecRequestBodyNoFilesLimit* für den *Content-Type application/x-www-form-urlencoded* zuständig, während sich *SecRequestBodyLimit* um den *Content-Type: multipart/form-data* kümmert.

Auf der Response-Seite schalten wir den Body-Access auch ein und legen wiederum eine Limite von 10MB fest. Hier gibt es die Unterscheidung in Formular- und File-übertragung nicht; es sind alles Files.

Nun folgt der reservierte Speicher für die _PCRE-Library_. Die ModSecurity-Dokumentation schlägt einen Wert von 1500 Bytes vor. Dies führt in der Praxis aber rasch zu Problemen. Unsere Grundkonfiguration mit einer Limite von 15000 ist etwas robuster. Falls immer noch Probleme auftreten, so sind auch Werte über 100000 gut verkraftbar; der Speicherbedarf wächst einfach ein wenig.

ModSecurity benötigt drei Verzeichnisse zur Datenablage. Wir legen alle auf das _tmp-Verzeichnis_. Dies ist für einen produktiven Betrieb natürlich der falsche Ort, aber für erste Gehversuche passt es und es ist nicht leicht, allgemeingültige Empfehlungen für die richtige Wahl dieses Verzeichnisses zu geben, denn die lokale Umgebung spielt eine grosse Rolle. Bei den besagten Verzeichnissen geht es um temporäre Daten, dann um Session-Daten die über einen Server-Restart hinaus erhalten bleiben sollen, und schliesslich um eine Zwischenablage für File-Uploads, die während der überprüfung nicht zuviel Hauptspeicher besetzen dürfen und ab einer bestimmten Grösse auf die Festplatte ausgelagert werden.

ModSecurity hat ein sehr detailliertes _Debug-Log_. Der konfigurierbare Loglevel reicht von 0 bis 9. Wir lassen ihn auf 0 und sind gewappnet, ihn beim Auftreten von Problemen erhöhen zu können, um genau mitzulesen, wie das Modul arbeitet. Neben der eigentlichen _Rule-Engine_ läuft innerhalb von ModSecurity auch eine _Audit-Engine_ welche das Mitschreiben der Requests organisiert. Denn im Angriffsfall möchten wir ja möglichst viel Informationen über den Angriff erhalten. Mit _SecAuditEngine RelevantOnly_ legen wir fest, dass nur _relevante_ Requests geloggt werden sollen. Was für uns relevant ist, legen wir auf der nächsten Zeile mittels einer Regular Expression fest: Alle Requests, deren HTTP-Status mit 4 oder 5 beginnt, allerdings nicht 404. Zu einem späteren Zeitpunkt werden wir sehen, dass man auch anderes als relevant definieren kann, aber für den Start reicht diese grobe Klassifizierung. Dann geht es weiter mit einer Definition der Teile dieser Requests, welche geloggt werden sollen. Wir kennen bereits den Request Header (Teil B), den Request Body (Teil I), den Response Header (Teil F) und den Response Body (Teil E). Dazu kommen Zusatzinformationen von ModSecurity (Teile A, H, K, Z) und Details über hochgeladene Files, die wir nicht komplett abbilden (Teil J). Eine ausführlichere Erklärung dieser Audit-Log-Teile findet sich im ModSecurity Referenz-Handbuch.

Je nach Anfrage werden sehr viele Daten in das Audit-Log geschrieben. Oft sind es pro Request mehrere hundert Zeilen. Auf einem stark belasteten Server mit vielen gleichzeitigen Requests führt das zu Problemen beim Schreiben des Files. Es wurde deshalb das sogenannte _Concurrent-Logformat_ eingeführt. Dabei wird ein zentrales Audit-Log mit den wichtigsten Informationen geführt. Die Detail-Informationen in den eben beschriebenen Teilen werden aber in Einzel-Dateien ausgelagert. Diese Dateien kommen unter dem mit der Direktive _SecAuditLogStorageDir_ definierten Verzeichnisbaum zu stehen. ModSecurity legt in diesem Baum für jeden Tag ein Verzeichnis an und darunter für jede Minute des Tages wieder ein eigenes Verzeichnis (allerdings nur, wenn innerhalb dieses Minute auch wirklich ein Request aufgezeichnet wurde). Darunter liegen dann die einzelnen Requests mit einem Dateinamen, der durch das Datum, die Uhrzeit und die Unique-ID der Anfrage bezeichnet wird.

Hier ein Beispiel aus dem zentralen Audit-Log:

```bash
localhost 127.0.0.1 - - [17/Oct/2015:15:54:54 +0200] "POST /index.html HTTP/1.1" 200 45 "-" "-" UYkHrn8AAQEAAHb-AM0AAAAB "-" 
  /20130507/20130507-1554/20130507-155454-UYkHrn8AAQEAAHb-AM0AAAAB 0 20343 md5:a395b35a53c836f14514b3fff7e45308
```

Wir sehen einige Informationen zum Request, den HTTP Status Code und kurz darauf die _Unique-ID_ des Requests, die wir auch in unserem Access-Log finden. Wenig später folgt ein absoluter Pfad. Er ist aber nur scheinbar absolut. Konkret müssen wir diesen Pfad-Teil an den Wert in _SecAuditLogStorageDir_ hinzufügen. Für uns heisst das also _/apache/logs/audit/20130507/20130507-1554/20130507-155454-UYkHrn8AAQEAAHb-AM0AAAAB_. In diesem File finden wir dann die Details zum Request:

```bash
--5a70c866-A--
[17/Oct/2013:15:54:54 +0200] UYkHrn8AAQEAAHb-AM0AAAAB 127.0.0.1 42406 127.0.0.1 80
--5a70c866-B--
POST /index.html HTTP/1.1
User-Agent: curl/7.35.0 (x86_64-pc-linux-gnu) libcurl/7.35.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3
Accept: */*
Host: 127.0.0.1
Content-Length: 3
Content-Type: application/x-www-form-urlencoded

...

```

Die beschriebenen Teile gliedern das File in Abschnitte. Es folgt der Teil _--5a70c866-A--_, als Teil A, dann _--5a70c866-B--_ als Teil B etc. In einem späteren Tutorial werden wir uns dieses Log im Detail ansehen. Für den Moment genügt diese Einführung. Was aber noch nicht genügt, ist unser Dateisystem. Denn um das _Audit-Log_ überhaupt schreiben zu können, muss das Verzeichnis erst erstellt und die entsprechenden Berechtigungen vergeben werden:

```bash
$> sudo mkdir /apache/logs/audit
$> sudo chown www-data:www-data /apache/logs/audit
```

Wir kommen damit zur Direktiven _SecDefaultAction_. Sie bezeichnet die Grundeinstellung einer Sicherheits-Regel. Wir können diese Werte zwar pro Regel festlegen, es ist aber üblich mit einem Default-Wert zu arbeiten, der dann an alle Regeln vererbt wird. ModSecurity kennt fünf Phasen. Die hier aufgeführte Phase 1 läuft an, sobald die Request-Header auf dem Server eingetroffen sind. Bei der Kompilation des Moduls haben wir mit _--enable-request-early_ festgelegt, dass das wirklich so ist, denn aus technischen Gründen wurde dieses Verhalten verändert und die Phase 1 mit der folgenden Phase zusammengelegt. Mit dem besagten Flag machen wir diese Verhaltensänderung rückgängig. Die übrigen Phasen sind _Request-Body-Phase (Phase 2)_, _Response-Header-Phase (Phase 3)_, _Response-Body-Phase (Phase 4)_ und _Logging-Phase (Phase 5)_. Dann sagen wir, dass wir beim Anschlagen einer Regel den Request im Normalfall passieren lassen möchten. Blockierungs-Massnahmen werden wir separat definieren. Wir möchten loggen; das heisst, wir möchten einen Hinweis auf die ausgelöste Regel im _Error-Log_ des Apache Servers sehen und schliesslich vergeben wir jedem dieser Logeinträge ein *Tag*. Das gesetzte Tag _Local Lab Service_ ist nur ein Beispiel dafür, dass hier beliebige Zeichenketten, auch mehrere, gesetzt werden können. In einem grösseren Unternehmen kann es zum Beispiel sinnvoll sein, Zusatzinformationen zu einem Service (Vertragsnummer, Kontaktdaten des Kunden, Hinweise zur Dokumentation etc.) abzubilden. Diese Informationen werden dann bei jedem Logeintrag mitgegeben. Das klingt zunächst nach Ressourcen-Verschwendung, tatsächlich kann ein Mitarbeiter im Betriebssicherheits-Team aber für mehrere hundert Services zuständig sein, und die URL alleine reicht ihm bei unbekannten Services in diesem Moment nicht. Diese Service-Metadaten, die sich über Tags hinzufügen lassen, erlauben eine rasche und adäquate Reaktion auf Angriffe.

Damit kommen wir zu den ModSecurity Regeln. Das Modul arbeitet zwar mit den oben definierten Limiten, die eigentliche Funktionalität steht aber vor allem in einzelnen Regeln, die in einer eigenen Regel-Sprache ausgedrückt werden. Bevor wir uns die einzelnen Regeln aber ansehen folgt in der Apache-Konfiguration ein Kommentarteil mit der Definition des Namensraums der Regel-ID Nummern. Jede ModSecurity Regel hat eine Nummer als Identifikation. Um die Regeln verwaltbar zu halten ist es sinnvoll, den Namensraum sauber aufzuteilen.

Das OWASP ModSecurity Core Rules Projekt bringt einen Grundstock an gut 200 ModSecurity Regeln. Wir werden diese Regeln in der nächsten Anleitung mit einbinden. Sie haben IDs beginnend mit der Zahl 900'000 und reichen bis zu 999'999. In diesem Bereich sollten wir also keine Regeln ablegen. Die ModSecurity Beispielkonfiguration bringt einige wenige Regeln im Bereich ab 200'000. Unsere eigenen Regeln gliedern sich am Besten in die grossen Zwischenräume. Ich schlage vor, im Bereich unter 100'000 zu bleiben.

Falls ModSecurity auf mehreren Services eingesetzt wird, kommen eventuell eigene gesharte Regeln zum Einsatz. Also selbstgeschriebene Regeln, die auf jedem der eigenen Instanzen konfiguriert werden. Legen wir diese in den Bereich von 80'000 bis 99'999. Für die weiteren eigenen, service-spezifischen Regeln spielt es oft eine Rolle, ob sie vor den Core Rules oder nach den Core Rules defniert werden. Sinnvollerweise teilt man den verbleibenden Raum deshalb in zwei Abschnitte: 10'000 bis 49'999 für service-spezifische Regeln vor den Core Rules und 50'000 bis 79'999 nach den Core Rules. Wir werden die Core Rules zwar in dieser Anleitung noch nicht einbinden, aber wir bereiten uns so darauf vor.

Damit kommen wir zu den ersten Regeln. Wir beginnen mit einem Block mit Performance-Daten. Es sind also noch keine sicherheitsrelevanten Regeln, sondern die Definition von Informationen zum Ablauf des Requests innerhalb von ModSecurity. Wir verwenden die Direktive _SecAction_. Eine _SecAction_ wird ohne Bedingung immer durchgeführt. Als Parameter folgt dann eine komma-separierte Liste mit Anweisungen. Zunächst definieren wir die Regel ID, dann die Phase in welcher die Regel ablaufen soll (1 bis 5). Wir möchten keinen Eintrag im Error-Log des Servers (_nolog_). Ferner lassen wir den Request passieren (_pass_) und setzen mehrere interne Variablen: Wir definieren für jede ModSecurity-Phase eine Timestamp. Sozusagen eine Zwischenzeit innerhalb des Requests beim Start jeder einzelnen Phase. Dies geschieht mit Hilfe der mitlaufenden Uhr in Form der Variblen _Duration_, die beim Start des Requests in Mikrosekunden zu ticken beginnt.

Die Regel mit der ID 90005 ist auskommentiert. Wir können sie einschalten, um mit Ihr die Apache Umgebungsvariable *write_perflog* zu setzen. Sobald wir das tun, wird das im Apache-Teil definierte Performance-Log mitgeschrieben. Diese Regel ist nicht mehr als _SecAction_, sondern als _SecRule_definiert. Hier kommt zur Regel-Anweisung noch eine vorgeschaltete Bedingung hinzu. In unserem Fall untersuchen wir *REQUEST_FILENAME* in Bezug auf den Beginn der Zeichenfolge. Wenn der String mit _/_ beginnt, dann sollen die folgenden Anweisungen inklusive dem Setzen der Umgebungsvariabeln ausgeführt werden. Natürlich beginnt jede valide Request-URI mit dem Zeichen _/_. Wenn wir das Log aber nur für bestimmte Pfade aktivieren wollen (z.B. _/login_), dann sind wir darauf vorbereitet und brauchen nur noch den Pfad zu verfeinern.

Soweit zu diesem Performance Teil. Es folgen nun die Regeln, welche durch das *ModSecurity* Projekt in der Beispielkonfigurationsdatei vorgeschlagen werden. Sie besitzen Regel IDs ab 200'000 und sind nicht sehr zahlreich. Die erste Regel untersucht den _Request Header Content-Type_. Die Regel greift, wenn dieser Header dem Text _text/xml_ entspricht. Sie wird in Phase 1 evaluiert. Nach der Phase folgt die Anweisung _t:none_. Dies bedeutet _Transformation: none_. Wir möchten die Parameter des Requests also vor der Verarbeitung dieser Regel nicht transformieren. Nach _t:none_ kommt eine Transformation mit dem selbsterklärenden Namen _t:lowercase_ auf dem Text zur Anwendung. Mit _t:none_ löschen wir also alle allenfalls vordefinierten Default-Transformationen und führen dann _t:lowercase_ aus. Das heisst, dass wir auf dem _Content-Type_ Header sowohl _text/xml_ als auch _Text/Xml_, _TEXT/XML_ und alle Kombinationen greifen werden. Schlägt diese Regel an, dann führen wir ganz hinten auf der Zeile eine _Control-Action_ durch: Wir wählen _XML_ als Prozessor des _Request Bodys_. Ein Detail bleibt noch zu erklären: Die vorangegangene, auskommentierte Regel führte den Operator _@beginsWith_ ein. Hier ist im Gegensatz dazu kein Operator bezeichnet. Damit kommt der _Default-Operator @rx_ zur Anwedung. Dies ist eine Operator für reguläre Ausdrücke (_RegEx_). _beginsWith_ ist erwartungsgemäss ein sehr schneller Operator; die Arbeit mit Regular Expression ist dem gegenüber sehr schwerfällig und langsam.

Die nächste Regel ist wiederum etwas komplizierter. Wir untersuchen die interne Variable *REQBODY_ERROR*. Im Bedingungsteil nehmen wir den numerischen Vergleichsoperator _@eq_. Das vorangestellte Ausrufezeichen negiert seinen Wert. Die Syntax meint also, falls der *REQBODY_ERROR* nicht gleich null ist. Natürlich könnten wir hier auch mit einem regulären Ausdruck arbeiten, aber der _@eq_ Operator ist in der Verarbeitung durch das Modul effizienter. Im Aktions-Teil der Regel kommt erstmals ein _deny_ zur Anwendung. Der Request soll also blockiert werden, falls die Verarbeitung des Request Bodies zu einem Fehler führte. Konkret retournieren wir den HTTP Status Code _400 Bad Request_ (_status:400_). Wir möchten erstmals loggen und geben die Nachricht vor. Zusätzlich loggen wir als weitere Informationen in einem separaten Logfeld namens _logdata_ die genaue Bezeichnung des Fehlers. Diese Information wird sowohl im Error-Log als auch im Audit-Log des Servers auftauchen. Zu guter Letzt wird der Regel die _Severity_, also die _Schwere_, 2 zugewiesen. Dies ist ein Grad für die Wichtigkeit der Regel, was bei der Auswertung von sehr vielen Regelverletzungen genützt werden kann.

Die Regel mit der Identifikation 200002 kümmert sich ebenfalls um Fehler im Request Body. Es geht um _Multipart HTTP Bodies_. Dies kommt dann zum tragen, wenn Dateien via HTTP Requests an den Server übermittelt werden sollen. Dies ist einerseits sehr gebräuchlich, aber andererseits ein grosses Sicherheitsproblem. ModSecurity untersucht _Multipart HTTP Bodies_ deshalb sehr genau. Es besitzt eine interne Variable namens *MULTIPART_STRICT_ERROR*, welche die zahlreichen Checks zusammenfasst. Sollte hier ein anderer Wert als 0 stehen, dann blockieren wir den Request mit dem Status Code 403 (_Forbidden_). In der Logmeldung rapportieren wir dann die Resultate der einzelnen Checks. In der Praxis ist zu wissen, dass diese Rule in sehr seltenen Fällen auch bei legalen Requests anschlagen könnte. Falls dies der Fall ist, muss sie gebenenfalls adaptiert oder als _False Positive_ ausgeschaltet werden. Wir werden weiter unten auf die Ausmerzung von False Positives zurückkommen und in einer späteren Anleitung das Thema im Detail kennenlernen.

Die Beispielkonfiguration der ModSecurity Distribution weist im Weiteren eine Regel mit der Identifikation 200003 auf. Ich habe sie aber nicht in die Anleitung übernommen, da sie in der Praxis zu viele legitime Anfragen blockiert (_False Positives_). Es wird die Variable *MULTIPART_UNMATCHED_BOUNDARY* überprüft. Dieser Wert, der einen Fehler in der Abgrenzung der Multipart Bodies bezeichnet, ist fehleranfällig und rapportiert häufig Textschnippsel, die keine Abgrenzungen meinen. In der Praxis hat sie sich aus meiner Sicht nicht bewährt.

Mit 200004 folgt eine weitere Regel, welche interne Verarbeitungs-Fehler abfängt. Im Gegensatz zu den vorangegangenen internen Variablen suchen wir hier aber nach einer Gruppe von Variablen, welche dem laufenden Request dynamisch mitgegeben werden. Für jeden Request wird ein Datenblatt namens _TX_ (Transaktion) eröffnet. Im ModSecurity Jargon spricht man von einer _Collection_, also einer Sammlung von Variablen und Werten. Während der Verarbeitung einer Anfrage setzt ModSecurity nun unter Umständen neben den bereits untersuchten Variablen auch noch Werte in der _TX Collection_. Die Namen dieser Variablen beginnen mit dem Prefix *MSC_*. Wir greifen nun parallel auf sämtliche Variablen dieses Musters in der Sammlung zu. Dies geschieht über die Konstruktion *TX:/^MSC_/*. Also die Transaktions-Collection und dann Variable-Namen auf welche der Reguläre Ausdruck *^MSC_* passt: Ein Wortbeginn mit *MSC_*. Sollte eine dieser gefundenen Variablen nicht gleich null sein, dann blockieren wir den Request mit dem HTTP Status 500 (_Internal Server Error_) und rapportieren in der Log-Datei den Variable-Namen.

Wir haben nun einige Regeln angesehen und das prinzipielle Funktionieren der _WAF_ ModSecurity kennengelernt. Die Regelsprache ist anspruchsvoll, aber sehr systematisch. Die Struktur orientiert sich dabei zwangsläufig an der Struktur von Apache Direktiven. Denn bevor ModSecurity die Direktiven verarbeiten kann, werden sie durch den Konfigurationsparser von Apache eingelesen. Dies bringt auch die Komplexität in der Ausdrucksweise mit sich. Gegenwärtig wird *ModSecurity* in eine Richtung weiterentwickelt, welche das Modul von Apache frei macht. Wir werden hoffentlich via einfacher zu lesende Konfigurationen davon profitieren.

In der Konfigurationsdatei folgt nun ein Kommentar, der den Platz markiert, um weitere Regeln einzugeben. Nach diesem Block, der unter Umständen sehr gross werden kann, folgen noch einige Regeln, welche Performance-Daten für das oben definierte Performance-Log zur Verfügung stellen. Der Block mit den Rule-IDs 90010 bis 90014 speichert den Zeitpunkt des Endes der einzelnen ModSecurity-Phasen ab. Dies korrespondiert mit dem oben kennengelernten Block der IDs 90000 - 90004. Im letzten ModSecurity-Block wird dann mit den erhobenen Performance-Daten gerechnet. Für uns bedeutet dies, dass wir die Zeit, welche Phase 1 und Phase 2 benötigten, zur Variable *perf_modsecinbound* zusammenrechnen. In der Regel mit der ID 90100 wird diese Variable auf die Performance der Phase 1 gesetzt, in der folgenden Regel wird die Performance der Phase 2 hinzuaddiert. Die Variable *perf_application* müssen wir aus den Timestamps herausrechnen. Wir ziehen dazu das Ende der Phase 2 vom Start der Phase 3 ab (Rule ID 90102 und 90103). Dies ist natürlich keine ganz exakte Berechnung der Zeit, welche die Applikation selbst auf dem Server benötigte, denn es spielen je nach dem auch noch andere Apache-Module hinein (die Authentifizierung etwa), aber der Wert ist ein Hinweis, der Aufschluss darüber gibt, ob tatsächlich ModSecurity die Performance einschränkt, oder ob das Problem eher bei der Applikation liegt. In den Rule IDs 90104 und 5 schliesslich noch die Berechnung des Zeitverbrauchs der Phase 3 und 4, analog zu den Phasen 1 und 2. Damit haben wir die drei relevanten Werte, welche die Performance einfach zusammenfassen: *perf_modsecinbound*, *perf_application* und *perf_modsecoutbound*. Sie werden im separaten Performance-Log ausgewiesen. Allerdings haben wir auch im normalen Zugriffslog einen Platz für diese drei Werte vorgesehen. Dort haben wir sie _ModSecTimeIn_, _ApplicationTime_ und _ModSecTimeOut_. In den Regeln 90106 bis 90108 exportieren wir unsere _perf_-Werte in die entsprechenden Umgebungsvariabeln, damit sie im _Access-Log_ angezeigt werden können. Zum Schluss noch die Regeln 90109 und 90110. In diesen Exportieren wir die _OWASP ModSecurity Core Rules_ Anomalie-Werte. Diese Werte werden noch nicht geschrieben, aber da wir diese Regeln in der nächsten Anleitung bereitstellen werden, können wir den Variable-Export hier schon vorbereiten.

Damit sind wir nun soweit, dass wir das Performance-Log verstehen können. Die obenstehende Definition bringt die folgenden Teile:

```bash
LogFormat "[%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] %{UNIQUE_ID}e %D \
PerfModSecInbound: %{TX.perf_modsecinbound}M \
PerfAppl: %{TX.perf_application}M \
PerfModSecOutbound: %{TX.perf_modsecoutbound}M \
TS-Phase1: %{TX.ModSecTimestamp1start}M-%{TX.ModSecTimestamp1end}M \
TS-Phase2: %{TX.ModSecTimestamp2start}M-%{TX.ModSecTimestamp2end}M \
TS-Phase3: %{TX.ModSecTimestamp3start}M-%{TX.ModSecTimestamp3end}M \
TS-Phase4: %{TX.ModSecTimestamp4start}M-%{TX.ModSecTimestamp4end}M \
TS-Phase5: %{TX.ModSecTimestamp5start}M-%{TX.ModSecTimestamp5end}M \
Perf-Phase1: %{PERF_PHASE1}M \
Perf-Phase2: %{PERF_PHASE2}M \
Perf-Phase3: %{PERF_PHASE3}M \
Perf-Phase4: %{PERF_PHASE4}M \
Perf-Phase5: %{PERF_PHASE5}M \
Perf-ReadingStorage: %{PERF_SREAD}M \
Perf-WritingStorage: %{PERF_SWRITE}M \
Perf-GarbageCollection: %{PERF_GC}M \
Perf-ModSecLogging: %{PERF_LOGGING}M \
Perf-ModSecCombined: %{PERF_COMBINED}M" perflog
```



   * %{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t meint wie in unserem Standard-Log die Timestamp des Empfangs der Requestzeile in der Genauigkeit von Microsekunden.
   * %{UNIQUE_ID}e : Die Unique-ID des Requests
   * %D : Die totale Dauer des Requests vom Empfang der Request-Zeile bis zum Ende des kompletten Requests in Microsekunden
   * PerfModSecInbound: %{TX.perf_modsecinbound}M : Zusammenfassung der in ModSecurity verbrauchten Zeit beim Eingang des Requests
   * PerfAppl: %{TX.perf_application}M : Zusammenfassung der in der Applikation verbrauchten Zeit
   * PerfModSecOutbound: %{TX.perf_modsecoutbound}M :  Zusammenfassung der in ModSecurity verbrauchten Zeit bei der Behandlung der Antwort
   * TS-Phase1: %{TX.ModSecTimestamp1start}M-%{TX.ModSecTimestamp1end}M : Die Timestamps zu Start und Ende von Phase 1 (Nach Empfang der Request Header)
   * TS-Phase2: %{TX.ModSecTimestamp2start}M-%{TX.ModSecTimestamp2end}M : Die Timestamps zu Start und Ende von Phase 2 (Nach Empfang des Request Bodies)
   * TS-Phase3: %{TX.ModSecTimestamp3start}M-%{TX.ModSecTimestamp3end}M : Die Timestamps zu Start und Ende von Phase 3 (Nach Empfang der Antwort Header) 
   * TS-Phase4: %{TX.ModSecTimestamp4start}M-%{TX.ModSecTimestamp4end}M : Die Timestamps zu Start und Ende von Phase 4 (Nach Empfang des Antwort Bodies)
   * TS-Phase5: %{TX.ModSecTimestamp5start}M-%{TX.ModSecTimestamp5end}M : Die Timestamps zu Start und Ende von Phase 5 (Logging Phase)
   * Perf-Phase1: %{PERF_PHASE1}M : Die durch ModSecurity intern durchgeführte Berechnung der Performance der Rules der Phase 1
   * Perf-Phase2: %{PERF_PHASE2}M : Die durch ModSecurity intern durchgeführte Berechnung der Performance der Rules der Phase 2
   * Perf-Phase3: %{PERF_PHASE3}M : Die durch ModSecurity intern durchgeführte Berechnung der Performance der Rules der Phase 3
   * Perf-Phase4: %{PERF_PHASE4}M : Die durch ModSecurity intern durchgeführte Berechnung der Performance der Rules der Phase 4
   * Perf-Phase5: %{PERF_PHASE5}M : Die durch ModSecurity intern durchgeführte Berechnung der Performance der Rules der Phase 5
   * Perf-ReadingStorage: %{PERF_SREAD}M : Die Zeit, welche das Lesen der ModSecurity Session-Speicher benötigte
   * Perf-WritingStorage: %{PERF_SWRITE}M : Die Zeit, welche das Schreiben der ModSecurity Session-Speicher benötigte
   * Perf-GarbageCollection: %{PERF_GC}M : Die Zeit welche die Garbage Collection, also die Aufräumarbeiten, benötigten
   * Perf-ModSecLogging: %{PERF_LOGGING}M : Die Zeit welche das Loggen durch ModSecurity, namentlich das Error-Log und das Audit-Log verbrauchten
   * Perf-ModSecCombined: %{PERF_COMBINED}M : Die Zeit, welche ModSecurity total für alle Arbeiten benötigte

Mit dieser langen Liste von Zahlen lassen sich ModSecurity Performance-Probleme sehr gut eingrenzen und gegebenenfalls beheben. Wenn noch tiefer gesucht werden muss, dann kann das _Debug-Log_ helfen, oder man nimmt die Variable-Sammlung *PERF_RULES* zu Hilfe, die im Referenz-Handbuch gut erklärt ist.

###Schritt 6: Einfache Blacklist Regeln schreiben

Mit der obenstehenden Konfiguration ist ModSecurity aufgesetzt und konfiguriert. Es kann fleissig Performance-Datan loggen, aber auf der Sicherheitsseite sind nur die rudimentären Grundlagen vorhanden. In einer späteren Anleitung werden wir wie angekündigt die _OWASP ModSecurity Core Rules_, eine umfassende Regelsammlung, einbinden. Zunächst ist es aber wichtig, dass wir lernen, selbst Regeln zu schreiben. In der Grundkonfiguration wurden schon einige Regeln erklärt. Von da ist es nur noch ein kleiner Schritt.

Nehmen wir einen einfachen Fall: Wir möchten sicher stellen, dass der Zugriff auf eine bestimmte URI auf dem Server verboten wird. Wir wollen auf eine solche Anfrage mit einem _HTTP Status 403_ antworten. Die entsprechende Regel schreiben wir in der Konfiguration in den Bereich _ModSecurity Rules_ und teilen ihr die ID 10000 (_service-specific before core-rules_) zu.

```bash
SecRule  REQUEST_FILENAME "/phpmyadmin" "id:'10000',phase:1,deny,t:lowercase,t:normalisePath,\
msg:'Blocking access to %{MATCHED_VAR}.',tag:'Blacklist Rules'"
```

Die Regel leiten wir mit _SecRule_ ein. Dann sagen wir, dass wir den Pfad der Anfrage, also die Variable *REQUEST_FILENAME* untersuchen möchten. Falls in diesem Pfad irgendwo _/phpmyadmin_ auftaucht, wollen wir ihn gleich schon in der ersten Verarbeitungsphase blockieren. Das Schlüsselwort _deny_ bewerkstelligt dies für uns. Unser Pfad-Kriterium ist in Kleinbuchstaben gehalten. Da wir die Transformation _t:lowercase_ anwenden, erwischen wir damit sämtliche möglichen Gross-Kleinbuchstaben-Kombinationen des Pfades. Der Pfad könnte nun natürlich auch in ein Unterverzeichnis weisen oder auf andere Art und Weise verschleiert werden. Wir helfen dem ab, indem wir die Transformation _t:normalisePath_ einschalten. Damit wird der Pfad transformiert bevor wir unsere Regel anwenden. Im _msg-Teil_ tragen wir eine Nachricht ein, die dann so im _Error-Log_ des Servers auftauchen wird, wenn die Regel zuschlägt. Schliesslich geben wir auch noch einen Tag an. Wir haben dies in der Grundkonfiguration bereits mit _SecDefaultAction_ getan. Hier nun ein weiterer Tag, der sich etwa dazu verwenden lässt, verschiedene Regeln zu gruppieren.

Wir nennen diesen Typ von Regeln _Blacklist Regeln_, da beschrieben wird, was wir verbieten wollen. Prinzipiell lassen wir alles passieren, ausser Anfragen, welche die konfigurierten Regeln verletzen. Der umgekehrte Weg, also das Beschreiben der erwünschten Anfragen und damit das Blockieren von allen unbekannten Anfragen, nennen wir _Whitelist Regeln_. _Blacklist Regeln_ sind einfacher zu schreiben, bleiben aber oft unvollständig. _Whitelist Regeln_ sind umfassender und bei richtiger Schreibweise kann man damit einen Server komplett abdichten. Aber sie sind schwer zu schreiben und führen in der Praxis oft zu Problemen, wenn sie nicht sehr ausgereift konstruiert werden. Weiter unten folgt ein _Whitelisting Beispiel_.

###Schritt 7: Blockade ausprobieren

Probieren wir die Blockade einmal aus:

```bash
$> curl http://localhost/phpmyadmin
```

Wir erwarten folgende Antwort:

```bash
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>403 Forbidden</title>
</head><body>
<h1>Forbidden</h1>
<p>You don't have permission to access /phpmyadmin
on this server.</p>
</body></html>
```

Sehen wir auch nach, was wir im _Error-Log_ dazu finden:

```bash
[2015-10-27 22:43:28.265834] [-:error] - - [client 127.0.0.1] ModSecurity: Access denied with code 403 (phase 1). Pattern match "/phpmyadmin" at REQUEST_FILENAME. [file "/apache/conf/httpd.conf_modsec_minimal"] [line "140"] [id "10000"] [msg "Blocking access to /phpmyadmin."] [tag "Local Lab Service"] [tag "Blacklist Rules"] [hostname "localhost"] [uri "/phpmyadmin"] [unique_id "Vi-wAH8AAQEAABuNHj8AAAAA"]
```

_ModSecurity_ beschreibt hier die ausgelöste Regel und die Massnahme, die ergriffen wurde: Zunächst der Zeitstempfel. Dann die durch Apache zugewiesene Schwere des Log-Eintrages. Die Stufe _error_ wird für alle _ModSecurity_ Meldungen vergeben. Dann folgt die IP-Adresse des Clients. Dazwischen einige leere Felder, welche nur mittels "-" bezeichnet werden. Sie bleiben bei Apache 2.4 leer, weil das Logformat sich änderte und *ModSecurity* diese Änderung noch nicht nachvollzogen hat. Danach die eigentliche Meldung, die mit der Massnahme eröffnet: _Access denied with code 403_ und zwar bereits in der Phase 1, also während des Empfangens der Anfrage-Header. Danach sehen wir einen Hinweis auf die Regelverletzung: Der String _"/phpMyAdmin"_ wurde im *REQUEST_FILENAME* gefunden. Dies ist genau das, was wir definiert haben. Die folgenden Informations-Stücke sind in Blöcken aus eckigen Klammern eingebettet. In jedem Block zunächst die Bezeichnung und dann durch einen Leerschlag getrennt die Information. Wir befinden uns mit unserer Regel also in der Datei */opt/apache-2.4.23/conf/httpd.conf_modsec_minimal* auf der Zeile 140. Die Regel besitzt - wie wir wissen - die ID 10000. Unter _msg_ sehen wir die in der Regel definierte Zusammenfassung der Regel, wobei die Variable *MATCHED_VAR* durch den Pfad-Teil der Anfrage ersetzt wurde. Danach der Tag, den wir in der _SecDefaultAction_ gesetzt haben; schliesslich der zusätzliche für diese Regel gesetzte Tag. Schliesslich folgen noch Hostname, URI und die Unique-ID der Anfrage.

Diese Angaben finden wir auch noch ausführlicher im oben besprochenen _Audit-Log_. Für den normalen Gebrauch reicht allerdings oft das _Error-Log_.

###Schritt 8: Einfache Whitelist Regeln schreiben

Mit der im Schritt 7 beschriebenen Regel konnten wir den Zugriff auf eine bestimmte URL verhindern. Nun werden wir den umgekehrten Fall behandeln: Wir möchten sicher stellen, dass nur noch auf eine bestimmte URL zugegriffen werden kann. Darüber hinaus werden wir nur noch vorher bekannte _POST-Parameter_ in einem vorgegebenen Format akzeptieren. Eine solche Whitelist Regel zu schreiben, das geht so:

```bash

SecMarker "BEGIN_LOGIN_WHITELIST"

SecRule REQUEST_FILENAME     "!@beginsWith /login" "id:10001,phase:1,pass,t:lowercase,t:normalisePath,nolog,msg:'Skipping',skipAfter:END_LOGIN_WHITELIST"
SecRule REQUEST_FILENAME     "!@beginsWith /login" "id:10002,phase:2,pass,t:lowercase,t:normalisePath,nolog,msg:'Skipping',skipAfter:END_LOGIN_WHITELIST"

SecRule REQUEST_FILENAME     "!^/login/(index.html|login.do)$" "id:10003,phase:1,deny,log,msg:'Unknown Login URL',tag:'Whitelist Login'"

SecRule ARGS_GET_NAMES       "!^()$" "id:10004,phase:1,deny,log,msg:'Unknown Query-String Parameter',tag:'Whitelist Login'"
SecRule ARGS_POST_NAMES      "!^(username|password)$" "id:10005,phase:2,deny,log,msg:'Unknown Post Parameter',tag:'Whitelist Login'"

SecRule &ARGS_POST:username  "@gt 1" "id:10006,phase:2,deny,log,msg:'%{MATCHED_VAR_NAME} occurring more than once',tag:'Whitelist Login'"
SecRule &ARGS_POST:password  "@gt 1" "id:10007,phase:2,deny,log,msg:'%{MATCHED_VAR_NAME} occurring more than once',tag:'Whitelist Login'"

SecRule ARGS_POST:username   "!^[a-zA-Z0-9_-]{1,16}$" "id:10008,phase:2,deny,log,msg:'%{MATCHED_VAR_NAME} parameter does not meet value domain',tag:'Whitelist Login'"
SecRule ARGS_POST:password   "!^[a-zA-Z0-9@#+<>_-]{1,16}$" "id:10009,phase:2,deny,log,msg:'%{MATCHED_VAR_NAME} parameter does not meet value domain',tag:'Whitelist Login'"

SecMarker "END_LOGIN_WHITELIST"

```

Da es sich um ein mehrzeiliges Regelwerk handelt, begrenzen wir die Gruppe von Regeln mit zwei Markierungen: *BEGIN_LOGIN_WHITELIST* und *END_LOGIN_WHITELIST*. Den ersten Marker benötigen wir nur zur Lesbarkeit, den zweiten als Sprungmarke. Mit der ersten Regel (id 10001) stellen wir nämlich fest, ob unsere Regelgruppe überhaupt betroffen ist. Sollte der kleingeschriebene und normalisierte Pfad nicht mit _/login_ beginnen, so springen wir - ohne Eintrag im Logfile übrigens - zur End-Markierung. Wir umgehen so den ganzen Regelblock. (Es wäre möglich, diesen ganzen Regelblock innerhalb eines Apache *Location*-Blockes zu platzieren. Ich bevorzuge aber die hier vorgestellte Schreibweise). Danach folgen unsere eigentlichen Regeln. Eine HTTP-Anfrage besitzt mehrere Charakteristiken, die für uns von Belang sind: Den Pfad, Query-String Parameter sowie allfällige Post-Parameter (es geht ja um einen Login mittels Benutzername und Passwort). Request-Header inklusive der Cookies lassen wir in diesem Beispiel weg, aber sie könnten je nach Applikation auch zu Schwachstellen werden und sollten dann auch abgefragt werden.

Zunächst ist nun also der Pfad zu prüfen (id 10002). Wir kennen unter */login* zwei Pfade, die wir akzeptieren: _/login/index.html_ und _/login/login.do_. Alles andere wird an der Regel 10002 scheitern. Anders als bei den _Blacklisting Rules_ brauchen wir uns jetzt nicht mehr um Transformationen zu kümmern. Denn jeder Pfad, der nicht mehr unserem Muster entspricht, wird ohnehin blockiert werden.

Danach kümmern wir uns um die zugelassenen Query-String- und Post-Parameter (id 10003 und 10004). Wir akzeptieren keine Query-String-Parameter (die entsprechende Rule liesse sich auch einfacher Schreiben, aber so wie sie dasteht ist sie bereit für das Einfüllen von zugelassenen Parametern). Als Post-Parameter kommen nur _username_ und _password_ in Frage. Jeder andere Parameter führt zu einer Blockade. Die Regeln 10005 und 10006 kümmern sich um eine gängige Methode von Angreifern, Sicherheitsregeln zu umgehen: Sie senden einen Parameter mehrmals und hoffen, dass die Web Application Firewall nicht jedes einzelne Vorkommen überprüft und dass es auf dem Applikationsserver zur Anwendung kommt. Wir zählen das Vorkommen der Parameter und stellen sicher, dass sie nie mehr als ein Mal auftauchen.

Damit bleiben die beiden finalen Regeln 10007 und 10008. Sie geben die Muster vor, denen die Parameter _Username_ und _Passwort_ entsprechen müssen. In der Regel 10007 blockieren wir die Nachricht, wenn der Username länger als 16 Zeichen ist und Zeichen jenseits von Buchstaben, Ziffern, "*_*" und dem Bindestrich enthält. Dieses Muster ist natürlich gegebenenfalls anzupassen. Die Regel 10008 erlaubt beim _Passwort-Parameter_ noch einige weitere Zeichen, verhält sich sonst aber identisch.

Mit diesem Regelblock sind wir nun sicher, dass der Zugriff auf _/login_ nur noch in sehr engen Schranken erlaubt ist. Wir haben damit ein Grundgerüst von Whitelisting Regeln geschrieben, das sich für kompliziertere Applikationsteile wiederverwenden lässt.

###Schritt 9: Blockade ausprobieren

Aber funktioniert das auch wirklich? Hier einige Versuche:

```bash
$> curl http://localhost/login/index.html
-> OK (ModSecurity erlaubt den Zugriff. Die Seite selbst existiert aber nicht. Wir erhalten also ein 404, Page not Found)
$> curl http://localhost/login/index.html?debug=on
-> FAIL
$> curl http://localhost/login/admin.html
-> FAIL
$> curl -d "username=1234&password=test" http://localhost/login/login.do
-> OK (ModSecurity erlaubt den Zugriff. Die Seite selbst existiert aber nicht. Wir erhalten also ein 404, Page not Found)
$> curl -d "username=1234&password=test&backdoor=1" http://localhost/login/login.do
-> FAIL
$> curl -d "username=12345678901234567&password=test" http://localhost/login/login.do
-> FAIL
$> curl -d "username=1234'&password=test" http://localhost/login/login.do
-> FAIL
$> curl -d "username=1234&username=5678&password=test" http://localhost/login/login.do
-> FAIL
```

Ein Blick in das Error-Log des Servers belegt, dass die Regeln genau so griffen, wie wir sie definiert haben (Auszug gefiltert):

```bash
[2015-10-17 05:26:05.396430] [-:error] - - [client 127.0.0.1] ModSecurity: Access denied with code 403 (phase 1). Match of "rx ^()$" against "ARGS_GET_NAMES:debug" required. [file "/opt/apache-2.4.23/conf/httpd.conf_modsec_minimal"] [line "180"] [id "10003"] [msg "Unknown Query-String Parameter"] [tag "Local Lab Service"] [tag "Whitelist Login"] [hostname "localhost"] [uri "/login/index.html"] [unique_id "UcAVIn8AAQEAAFjeANQAAAAA"]
[2015-10-17 05:26:07.539846] [-:error] - - [client 127.0.0.1] ModSecurity: Access denied with code 403 (phase 1). Match of "rx ^()$" against "ARGS_GET_NAMES:debug" required. [file "/opt/apache-2.4.23/conf/httpd.conf_modsec_minimal"] [line "180"] [id "10003"] [msg "Unknown Query-String Parameter"] [tag "Local Lab Service"] [tag "Whitelist Login"] [hostname "localhost"] [uri "/login/index.html"] [unique_id "UcAVkH8AAQEAAFjeANYAAAAC"]
[2015-10-17 05:26:12.345245] [-:error] - - [client 127.0.0.1] ModSecurity: Access denied with code 403 (phase 1). Match of "rx ^/login/(index.html|login.do)$" against "REQUEST_FILENAME" required. [file "/opt/apache-2.4.23/conf/httpd.conf_modsec_minimal"] [line "179"] [id "10002"] [msg "Unknown Login URL"] [tag "Local Lab Service"] [tag "Whitelist Login"] [hostname "localhost"] [uri "/login/admin.html"] [unique_id "UcAVlH8AAQEAAFjeANcAAAAD"]
[2015-10-17 05:26:19.976533] [-:error] - - [client 127.0.0.1] ModSecurity: Access denied with code 403 (phase 2). Match of "rx ^(username|password)$" against "ARGS_POST_NAMES:backdoor" required. [file "/opt/apache-2.4.23/conf/httpd.conf_modsec_minimal"] [line "181"] [id "10004"] [msg "Unknown Post Parameter"] [tag "Local Lab Service"] [tag "Whitelist Login"] [hostname "localhost"] [uri "/login/login.do"] [unique_id "UcAVmn8AAQEAAFjeANkAAAAF"]
[2015-10-17 05:26:25.165337] [-:error] - - [client 127.0.0.1] ModSecurity: Access denied with code 403 (phase 2). Match of "rx ^[a-zA-Z0-9_-]{1,16}$" against "ARGS_POST:username" required. [file "/opt/apache-2.4.23/conf/httpd.conf_modsec_minimal"] [line "186"] [id "10007"] [msg "ARGS_POST:username parameter does not meet value domain"] [tag "Local Lab Service"] [tag "Whitelist Login"] [hostname "localhost"] [uri "/login/login.do"] [unique_id "UcAVnn8AAQEAAFjeANoAAAAG"]
[2015-10-17 05:26:42.924352] [-:error] - - [client 127.0.0.1] ModSecurity: Access denied with code 403 (phase 2). Match of "rx ^[a-zA-Z0-9_-]{1,16}$" against "ARGS_POST:username" required. [file "/opt/apache-2.4.23/conf/httpd.conf_modsec_minimal"] [line "186"] [id "10007"] [msg "ARGS_POST:username parameter does not meet value domain"] [tag "Local Lab Service"] [tag "Whitelist Login"] [hostname "localhost"] [uri "/login/login.do"] [unique_id "UcAVon8AAQEAAFjeANsAAAAH"]
[2015-10-17 05:27:55.853951] [-:error] - - [client 127.0.0.1] ModSecurity: Access denied with code 403 (phase 2). Operator GT matched 1 at ARGS_POST. [file "/opt/apache-2.4.23/conf/httpd.conf_modsec_minimal"] [line "183"] [id "10005"] [msg "ARGS_POST occurring more than once"] [tag "Local Lab Service"] [tag "Whitelist Login"] [hostname "localhost"] [uri "/login/login.do"] [unique_id "UcAVpn8AAQEAAFjeANwAAAAI"]
```

Es funktioniert also von A bis Z.

###Schritt 10 Bonus: Client-Verkehr komplett auf Disk schreiben

Bevor wir zum Ende dieser Anleitung kommen, folgt hier noch ein Tipp, der einem in der Praxis oft hilft: _ModSecurity_ ist nämlich nicht nur eine _Web Application Firewall_. Es ist auch ein sehr exaktes Debugging-Hilfsmittel. So lässt sich etwa der komplette Verkehr zwischen Client und Server aufzeichnen. Das geht so:

```bash
SecRule REMOTE_ADDR  "@streq 127.0.0.1"   "id:11000,phase:1,pass,log,auditlog,msg:'Initializing full traffic log'"
```
Wir finden den Verkehr des in der Regel angegebenen Clients 127.0.0.1 dann im Audit-Log.

```bash
$> curl localhost
...
$> sudo tail -1 /apache/logs/modsec_audit.log
localhost 127.0.0.1 - - [17/Oct/2015:06:17:08 +0200] "GET /index.html HTTP/1.1" 404 214 "-" "-" UcAmDH8AAQEAAGUjAMoAAAAA "-" /20151017/20151017-0617/20151017-061708-UcAmDH8AAQEAAGUjAMoAAAAA 0 15146 md5:e2537a9239cbbe185116f744bba0ad97 
$> sudo cat /apache/logs/audit/20151017/20151017-0617/20151017-061708-UcAmDH8AAQEAAGUjAMoAAAAA
--c54d6c5e-A--
[17/Oct/2015:06:17:08 +0200] UcAmDH8AAQEAAGUjAMoAAAAA 127.0.0.1 52386 127.0.0.1 80
--c54d6c5e-B--
GET /index.html HTTP/1.1
User-Agent: curl/7.35.0 (x86_64-pc-linux-gnu) libcurl/7.35.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3
Host: localhost
Accept: */*

--c54d6c5e-F--
HTTP/1.1 200 OK
Date: Tue, 27 Oct 2015 21:39:03 GMT
Server: Apache
Last-Modified: Tue, 06 Oct 2015 11:55:08 GMT
ETag: "2d-5216e4d2e6c03"
Accept-Ranges: bytes
Content-Length: 45

--c54d6c5e-E--
<html><body><h1>It works!</h1></body></html>
...

```

Die Regel, welche den Verkehr aufzeichnet, lässt sich natürlich beliebig anpassen, so dass wir punktgenau mitlesen können, was in den Server eingeht und was er retourniert (nur eine bestimmte Client-IP, ein bestimmter User, nur ein Applikationsteil mit einem bestimmten Pfad etc.). Damit kommt man einem Fehlverhalten einer Applikation oft schnell auf die Schliche.

Damit sind wir zum Ende dieser Anleitung gelangt. *ModSecurity* ist eine wichtige Komponente für den Betrieb eines sicheren Webservers. Mit dieser Anleitung ist der Einstieg hoffentlich geglückt.

###Verweise

* Apache [https://httpd.apache.org](http://httpd.apache.org)
* ModSecurity [https://www.modsecurity.org](http://www.modsecurity.org)
* ModSecurity Reference Manual [https://github.com/SpiderLabs/ModSecurity/wiki/Reference-Manual](https://github.com/SpiderLabs/ModSecurity/wiki/Reference-Manual)

### Lizenz / Kopieren / Weiterverwenden

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />Diese Arbeit ist wie folgt lizenziert / This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

