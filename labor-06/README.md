##Title: OWASP ModSecurity Core Rules einbinden

###Was machen wir?

Wir binden die OWASP ModSecurity Core Rules in unseren Apache Webserver ein und merzen Fehlalarme aus.

###Warum tun wir das?

Die Web Application Firewall ModSecurity, wie wir sie in Anleitung Nummer 6 eingerichtet haben, besitzt noch beinahe keine Regeln. Der Schutz spielt aber erst, wenn man ein möglichst umfassendes Regelset hinzukonfiguriert und die ganzen Fehlalarme (*False Positives*) ausgemerzt hat. Die Core Rules bieten generisches Blacklisting. Das heisst, sie untersuchen die Anfragen und die Antworten nach Hinweisen auf Angriffe. Die Hinweise sind oft Schlüsselwörter und typische Muster, die auf verschiedenste Arten von Angriffen hindeuten können. Das bringt es mit sich, dass auch Fehlalarme ausgelöst werden.

###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](https://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/) erstellt.
* Verständnis der minimalen Konfiguration in [Anleitung 2 (Apache minimal konfigurieren)](https://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/).
* Ein Apache Webserver mit SSL-/TLS-Unterstützung wie in [Anleitung 4 (Konfigurieren eines SSL Servers)](https://www.netnea.com/cms/apache-tutorial-4-ssl-server-konfigurieren)
* Ein Apache Webserver mit erweitertem Zugriffslog wie in [Anleitung 5 (Das Zugriffslog Ausbauen und Auswerten)](https://www.netnea.com/cms/apache-tutorial-5-zugriffslog-ausbauen/)
* Ein Apache Webserver mit ModSecurity wie in [Anleitung 6 (ModSecurity einbinden)](https://www.netnea.com/cms/apache-tutorial-6-modsecurity-einbinden/)

###Schritt 1: OWASP ModSecurity Core Rules herunterladen

Die ModSecurity Core Rules werden unter dem Dach von *OWASP*, dem Open Web Application Security Project entwickelt. Die Rules selbst liegen auf *GitHub* und können wie folgt heruntergeladen werden. 

```
$> wget https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/2.2.9.tar.gz
$> tar xvzf 2.2.9.tar.gz
owasp-modsecurity-crs-2.2.9/
owasp-modsecurity-crs-2.2.9/.gitignore
owasp-modsecurity-crs-2.2.9/CHANGES
owasp-modsecurity-crs-2.2.9/INSTALL
owasp-modsecurity-crs-2.2.9/LICENSE
owasp-modsecurity-crs-2.2.9/README.md
...
$> sudo mkdir /opt/modsecurity-core-rules-2.2.9
$> sudo chown `whoami` /opt/modsecurity-core-rules-2.2.9
$> cp owasp-modsecurity-crs-2.2.9/base_rules/* /opt/modsecurity-core-rules-2.2.9
$> sudo ln -s /opt/modsecurity-core-rules-2.2.9 /modsecurity-core-rules
$> rm -r 2.2.9.tar.gz owasp-modsecurity-crs-2.2.9 
```

Damit entpacken wir den Basis-Teil der Core-Rules in ein Verzeichnis `/opt/modsecurity-core-rules-2.2.9`. Dazu erzeugen wir einen Link von `/modsecurity-core-rules` auf dieses Verzeichnis. Den ganzen Rest des Core Rules-Pakets löschen wir wieder. Tatsächlich gibt es noch eine Vielzahl von optionalen Regeln, welche je nach Situation von Interesse sein können. Für den Einstieg in unserem Labor-Setup lassen wir sie aber links liegen. Ferner übergehen wir ein File namens `modsecurity_crs_10_setup.conf`. Üblicherweise wird eine Grundkonfiguration in dieses File geschrieben und die Datei dann via *Include* durch Apache importiert. Das hat sich aus meiner Sicht aber nicht bewährt. Den Inhalt dieses Files werden wir im nächsten Abschnitt direkt in unsere Apache-Konfiguration integrieren, so dass wir die Datei selbst nicht benötigen.

###Schritt 2: Core Rules einbinden

In der Anleitung 6, in welcher wir ModSecurity selbst eingebunden haben, markierten wir bereits einen Bereich für die Core-Rules. In diesen Bereich fügen wir die Include-Direktive jetzt ein. Konkret kommen vier Teile zur bestehenden Konfiguration hinzu. (1) Die Core Rules Basis-Konfiguration, (2) ein Teil für selbst zu definierende Ignore-Rules vor den Core Rules. Dann (3) die Core Rules selbst und schliesslich ein Teil (4) für selbst zu definierende Ignore-Rules nach den Core Rules.

Die sogenannten Ignore-Rules bezeichnen Regeln, welche dazu dienen, mit den oben beschriebenen Fehlalarmen umzugehen. Manche Fehlalarme müssen verhindert werden, bevor die entsprechende Core Rule geladen wird. Manche Fehlalarme können erst nach der Definition der Core Rule selbst abgefangen werden. Aber der Reihe nach. Hier zunächst das komplette Konfigurationsfile:

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


# === ModSecurity Rules (ids: 900000-999999)
                
# === ModSec Core Rules Base Configuration (ids: 900001-900021)

SecAction "id:'900001',phase:1,t:none, \
   setvar:tx.critical_anomaly_score=5, \
   setvar:tx.error_anomaly_score=4, \
   setvar:tx.warning_anomaly_score=3, \
   setvar:tx.notice_anomaly_score=2, \
   nolog, pass"
SecAction "id:'900002',phase:1,t:none,setvar:tx.inbound_anomaly_score_level=10000,setvar:tx.inbound_anomaly_score=0,nolog,pass"
SecAction "id:'900003',phase:1,t:none,setvar:tx.outbound_anomaly_score_level=10000,setvar:tx.outbound_anomaly_score=0,nolog,pass"
SecAction "id:'900004',phase:1,t:none,setvar:tx.anomaly_score_blocking=on,nolog,pass"

SecAction "id:'900006',phase:1,t:none,setvar:tx.max_num_args=255,nolog,pass"
SecAction "id:'900007',phase:1,t:none,setvar:tx.arg_name_length=100,nolog,pass"
SecAction "id:'900008',phase:1,t:none,setvar:tx.arg_length=400,nolog,pass"
SecAction "id:'900009',phase:1,t:none,setvar:tx.total_arg_length=64000,nolog,pass"
SecAction "id:'900010',phase:1,t:none,setvar:tx.max_file_size=10000000,nolog,pass"
SecAction "id:'900011',phase:1,t:none,setvar:tx.combined_file_sizes=10000000,nolog,pass"
SecAction "id:'900012',phase:1,t:none, \
  setvar:'tx.allowed_methods=GET HEAD POST OPTIONS', \
  setvar:'tx.allowed_request_content_type=application/x-www-form-urlencoded|multipart/form-data|text/xml|application/xml|application/x-amf|application/json', \
  setvar:'tx.allowed_http_versions=HTTP/0.9 HTTP/1.0 HTTP/1.1', \
  setvar:'tx.restricted_extensions=.asa/ .asax/ .ascx/ .axd/ .backup/ .bak/ .bat/ .cdx/ .cer/ .cfg/ .cmd/ .com/ .config/ .conf/ .cs/ .csproj/ .csr/ .dat/ .db/ .dbf/ .dll/ .dos/ .htr/ .htw/ .ida/ .idc/ .idq/ .inc/ .ini/ .key/ .licx/ .lnk/ .log/ .mdb/ .old/ .pass/ .pdb/ .pol/ .printer/ .pwd/ .resources/ .resx/ .sql/ .sys/ .vb/ .vbs/ .vbproj/ .vsdisco/ .webinfo/ .xsd/ .xsx/', \
  setvar:'tx.restricted_headers=/Proxy-Connection/ /Lock-Token/ /Content-Range/ /Translate/ /via/ /if/', \
  nolog,pass"

SecRule REQUEST_HEADERS:User-Agent "^(.*)$" "id:'900018',phase:1,t:none,t:sha1,t:hexEncode,setvar:tx.ua_hash=%{matched_var}, \
  nolog,pass"
SecRule REQUEST_HEADERS:x-forwarded-for "^\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b" \
  "id:'900019',phase:1,t:none,capture,setvar:tx.real_ip=%{tx.1},nolog,pass"
SecRule &TX:REAL_IP "!@eq 0" "id:'900020',phase:1,t:none,initcol:global=global,initcol:ip=%{tx.real_ip}_%{tx.ua_hash}, \
  nolog,pass"
SecRule &TX:REAL_IP "@eq 0" "id:'900021',phase:1,t:none,initcol:global=global,initcol:ip=%{remote_addr}_%{tx.ua_hash},setvar:tx.real_ip=%{remote_addr}, \
  nolog,pass"

# === ModSecurity Ignore Rules Before Core Rules Inclusion; order by id of ignored rule (ids: 10000-49999)

# ...

# === ModSecurity Core Rules Inclusion

Include    /modsecurity-core-rules/*.conf

# === ModSecurity Ignore Rules After Core Rules Inclusion; order by id of ignored rule (ids: 50000-59999)

# ...

# === ModSec Timestamps at the End of Each Phase (ids: 90010 - 90019)

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

DocumentRoot		/apache/htdocs

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

In der Basis-Konfiguration definieren wir verschiedene Werte, welche durch die Core Rules abgerufen und benützt werden. In der Regel *900001* werden verschiedenen Schweregraden Zahlenwerte, sogenannte Scores, zugeweisen. Ein "kritischer Fehler" erhält den Wert 5, ein Fehler der Stufe *Error* die 4, eine "Warnung" 3 und eine "Notiz" einen Score von 2. Eine HTTP-Anfrage durchläuft die Core Rules wie einen grossen Filter. Jeder einzelnen Core Rule ist ein Schweregrad zugewiesen. Verletzt also eine Anfrage eine Regel der Stufe *Critical*, dann erhält der Request 5 Punkte. Eine Anfrage kann mehrere Regeln verletzen und dieselbe Regel kann mehrmals verletzt werden, wenn verschiedene Parameter abgefragt werden und die Regel mehrfach greift. Die sogenannten Anomalie-Werte (*Anomaly Scores*) werden dann pro Anfrage aufsummiert, jeweils für den Request, aber auch separat für die Response. Dabei kann bei einem ungetunten System eine recht hohe Summe zusammen kommen; Scores von über 500 sind keine Seltenheit und auch 1000 wurde schon gesehen.

In den Regeln *900002* und *900003* definieren wir die Limiten, bei welchen ein Request blockiert werden soll. Eine Limite betrifft die Anfragen (*Inbound*), eine zweite Limite die Antworten (*outbound*). Wir legen für den Start sehr hohe Werte von 10000 für beide Limiten fest. In der Praxis bedeutet dies, dass die Limiten niemals erreicht werden. In der Regel *900004* aktivieren wir formell den blockierenden Modus. Wir könnten hier auch festlegen, dass wir gar nicht blockieren möchten, sondern im Monitoring-Modus arbeiten möchten. Davon rate ich aber entschieden ab. Wir sollten von Anfang an im Blocking-Modus arbeiten und die Limiten Schritt um Schritt reduzieren. Das Reduzieren der Limiten im Monitoring-Modus bleibt häufig auf halbem Weg stecken und gelingt es dennoch sie zu reduzieren, traut man sich am Ende oft nicht, in den Blocking-Modus zu wechseln. Besser ist es also, im Blocking-Modus zu starten und bei jeder Limiten-Reduktion mehr Vertrauen in die Installation zu erhalten.

Zusammengefasst haben wir für die Core Rules nun als eine blockierende Betriebsart mit sehr laxen Limiten gewählt. Die Limiten können wir zu einem späteren Zeitpunkt schrittweise anziehen; am Blocking-Prinzip selbst müssen wir aber nichts mehr ändern.

In den Regeln *900006* bis *900009* setzen wir nacheinander die maximale Zahl der Anfrage-Parameter, die maximale Zeichenlänge der Parameternamen, die Länge eines Parameters und schliesslich die kombinierte Länge aller Parameter. Der letzte Wert korrespondiert ein Stück weit mit dem oben in der Datei als *SecRequestBodyLimit* und *SecRequestBodyNoFilesLimit* gesetzten Werten. Während diese beiden Werte aber harte Limiten darstellen, sind die Parameter *tx.max_file_size* sowie *tx.combined_file_sizes=1000* weicher, indem sie einfach eine Verletzung einer *Core Rule* der Severity *notice* (= 2 Punkte) mit sich bringen. In diesem Sinn handelt es sich um eine serverseitige Warnung im Log und noch nicht um eine Blockade. Möchte man sofort hart reagieren, dann sind *SecRequestBodyLimit* und *SecRequestBodyNoFilesLimit* die richtigen Werte.

Dies trifft auch für die folgenden Regeln *900010* und *900011* zu, welche maximale Dateigrössen und kombinierte Dateigrössen fixieren. In der Regel *900012* werden die erlaubten HTTP-Methoden angeführt, denn wir akzeptieren nicht mehr länger sämtliche Methoden. Dann die in den Anfragen erlaubten Media-Typen: Dies sind primär der Standard *application/x-www-form-urlencoded* und der bei Datei-Uploads eingesetzte *multipart/form-data*. Dazu kommen nun noch zwei, drei XML-Varianten und *application/json*. Es folgen die akzeptablen HTTP-Versionen, dann eine Liste mit nicht erwünschten Datei-Endungen und schliesslich verbotene Anfrage-Header.

Es folgen nun die Regeln *900018* bis und mit *900021*. Diese Regeln sind sehr anspruchsvoll. Sie arbeiten zusammen und kreieren zwei sogenannte Collections. Collections sind Datensammlungen, welche über eine einzelne Anfrage hinaus erhalten bleiben. Damit lassen sich User-Sessions erfassen und beobachten. In der Regel *900018* wird der *User-Agent Header* aus der Anfrage mit dem SHA1-Verfahren in einen Hash übersetzt und dann im Hexadezimalformat codiert. Diesen Wert - hier *ua_hash*, also User-Agent-Hash, genannt - wird in eine Variable geschrieben. Dies geschieht via *%{matched_var}*, eine interne Variable von *ModSecurity*, welche den Wert im Bedingungsteil der Regel repräsentiert. *%{matched_var}* ist bei einer *SecRule*-Direktive immer vorhanden. Darauf wird in der Regel *900019* nach einem Forwarded-For Header Ausschau gehalten. Forwarded-For Header werden von Proxies geschrieben, welche typischerweise HTTP-Clients in Firmennetzen abweisen. Im Header selbst steht dann die ursprüngliche IP-Adresse des Clients. Falls vorhanden nehmen wir die IP-Adresse und setzen die Variable *real_ip* entsprechend. Anders als in der vorausgegangenen Regel nehmen wir aber nicht mehr *%{matched_var}*, sondern wählen den in der Klammer des regulären Ausrucks vorgefundenen Wert aus. Dazu setzen wir die Aktion *capture* ab und greifen dann mittels *%{tx.1}* auf diese erste Klammer zu. Bei *TX* handelt es sich um einen Kürzel für *Transaktion*. Gemeint ist eine Collection, die den momentanen Request und hier den momentanen Treffer des regulären Ausdrucks betrifft. Hat das geklappt, dann initialisieren wir bei *900020* die Collection *GLOBAL* mit dem Wert *global* und initialisieren gleichzeitig die Collection IP mit dem zusammengesetzten Schlüssel aus *real_ip* und *ua_hash*. Falls wir keinen Forwarded-For Header vorgefunden haben, dann setzen wir die Collection *IP* in der Regel *900021* auf die IP-Adresse der TCP-Verbindung, also den Wert der internen Variable *REMOTE_ADDR* respektive hier *remote_addr*.

Damit sind alle nötigen Variablen initialisiert und wir sind bereit für das Laden der *OWASP ModSecurity Core Rules*, die wir ja vorher bereitgestellt haben. Vor dem dazu nötigen *Include-Befehl* folgt in der Konfigurations-Datei aber noch der erwähnte Block für die zukünftige Behandlung von Fehlalarmen. Dieser Block besteht zur Zeit erst aus einem Kommentar und einem Platzhalter. Darauf der eigentliche *Include-Befehl* für die Core-Rules, wiederum gefolgt von einem Kommentar als Platzhalter für die zukünftige Behandlung von Fehlalarmen. Die Fehlalarme können auf verschiedene Arten bekämpft werden. Zum Teil muss das vor dem Laden der Core Rules geschehen, zum Teil nachdem sie bereits geladen wurden. Deshalb stellen wir zwei Plätze für diese Direktiven bereit.

Damit haben wir die Core Rules eingebunden und sind bereit für den Testbetrieb. Die Regeln werden Anfragen und Antworten untersuchen. Sie werden auch Alarme auslösen, aber sie werden noch keine Requests blockieren, da die Limiten sehr hoch gesetzt wurden. Das Auslösen von Alarmen und tatsächliche Blockierungen lassen sich im Apache Error-Log sehr einfach unterscheiden. Zumal die einzelnen Core Rules, wie wir gesehen haben, ja nur einen Anomalie-Wert erhöhen, aber noch keine Blockade auslösen. Die Blockade selbst wird durch eine separate Blockierungs-Regel mit Rücksicht auf die Limiten durchgeführt. Diese wird für den Moment aber noch nicht anschlagen. Normale Regelverletzungen rapportiert ModSecurity im Error-Log mit *ModSecurity. Warning ...*, Blockaden als *ModSecurity. Access denied ...*. Solange also kein *Access denied* rapportiert wird, arbeiten die Benutzer ohne Beeinträchtigung durch ModSecurity.

###Schritt 3: Testhalber Alarme auslösen

Damit haben wir unseren Webserver nun mit einer kompletten WAF-Installation komplementiert. Was noch aussteht ist das Tuning, also das Verfeinern der Konfiguration: Eben das Ausmerzen der Fehlalarme. Zunächst wollen wir aber einmal sehen, wie die Alarme überhaupt aussehen. Lassen wir dazu einen einfachen Schwachstellen-Scanner gegen unsere Testinstallation laufen. *Nikto* ist ein solches simples Hilfsmittel, das uns rasch Resultate liefert. *Nikto* muss je nachdem noch installiert werden. Der Scanner ist aber in den meisten Distributionen enthalten.

```bash
$> nikto -h localhost
- Nikto v2.1.4
---------------------------------------------------------------------------
+ Target IP:          127.0.0.1
+ Target Hostname:    localhost
+ Target Port:        80
+ Start Time:         2015-11-08 08:33:59
---------------------------------------------------------------------------
+ Server: Apache
+ No CGI Directories found (use '-C all' to force check all possible dirs)
+ ETag header found on server, fields: 0x2d 0x432a5e4a73a80 
+ Allowed HTTP Methods: POST, OPTIONS, GET, HEAD 
+ 6448 items checked: 0 error(s) and 2 item(s) reported on remote host
+ End Time:           2015-11-08 08:34:14 (15 seconds)
---------------------------------------------------------------------------
+ 1 host(s) tested
```

Dieser Scan sollte auf dem Server zahlreiche *ModSecurity-Alarme* ausgelöst haben. Sehen wir uns das *Apache Error-Log* einmal genauer an. In meinem Fall waren es gut 33'000 Einträge im Error-Log. Hier eine Beispielmeldung:

```bash
[2015-11-07 08:34:13.816811] [-:error] - - [client 127.0.0.1] ModSecurity: Warning. Pattern match "(fromcharcode|alert|eval)\\\\s*\\\\(" at ARGS:how_many_back. [file "/modsecurity-core-rules/modsecurity_crs_41_xss_attacks.conf"] [line "391"] [id "973307"] [rev "2"] [msg "XSS Attack Detected"] [data "Matched Data: alert( found within ARGS:how_many_back: \\x22><script>alert(1)</script>"] [ver "OWASP_CRS/2.2.9"] [maturity "8"] [accuracy "8"] [tag "Local Lab Service"] [tag "OWASP_CRS/WEB_ATTACK/XSS"] [tag "WASCTC/WASC-8"] [tag "WASCTC/WASC-22"] [tag "OWASP_TOP_10/A2"] [tag "OWASP_AppSensor/IE1"] [tag "PCI/6.5.1"] [hostname "localhost"] [uri "/scripts/message/message_dialog.tml"] [unique_id "Vj2pdX8AAQEAABa9vbcAAAAU"]
```

Das *Error-Log* wurde bereits in der vorangegangenen Anleitung beschrieben. Die Meldungen, welche durch die Core-Rules ausgelöst werden, bringen gegenüber den Standard-Meldungen noch weitere Informationen, so dass es sich anbietet, das Logformat noch einmal zu besprechen.

Den Beginn der Zeile machen die apache-spezifischen Teile, also der Zeitstempel und der Schweregrad der Meldung aus Sicht des Apache Servers. Leider bleiben einige Felder leer (-> "-"). Dies liegt an einem Fehler in *ModSecurity*, der in der nächsten Version behoben worden sein soll. Die *ModSecurity*-Meldungen werden immer auf Stufe *error* abgesetzt. Dann folgt die IP Adresse des Clients. Darauf ein Hinweis auf ModSecurity. Hier ist es sehr wichtig zu wissen, dass die Meldung *ModSecurity: Warning.* wirklich nur eine Warnung darstellt. Wenn das Modul in den Verkehr eingreift, dann schreibt es *ModSecurity: Access denied with code ...*. Auf diese Unterscheidung ist Verlass. Ein *Warning* kann auf den Client also keine direkten Auswirkungen haben.

Wie geht es nun weiter? Es folgt ein Hinweis auf das Muster, das in der Anfrage gefunden wurde. Im Anfragen-Argument *ctr* wurde ein bestimmtes Muster eines regulären Ausdrucks gefunden. Nun folgen eine Reihe von Parametern, die immer dasselbe Muster besitzen: Sie stehen in eckigen Klammern und besitzen einen eigenen Bezeichner. Zunächst der Bezeichner *file*. Er zeigt uns, in welchem File die Regel definiert wurde, die nun den Alarm auslöste. Dem folgt mit *line* die Zeilennummer in dieser Datei. Wichtiger scheint mir der Parameter *id*. Jede Regel in *ModSecurity* besitzt eine Identifikationsnummer und ist damit eindeutig identifizierbar. Darauf folgt mit *rev* ein Hinweis auf die Revisionsnummer der Regel. In den Core Rules wird mit diesem Parameter ausgedrückt, wie oft die Regel schon revidiert wurde. Kommt es also zu einer Regeländerung, wird *rev* um eins erhöht. Die *msg*, kurz für *Message*, beschreibt den Typ des identifizierten Angriffs. Bei *data* wird der relevante Teil der Anfrage, also der Parameter *ctr*, gezeigt: Es handelt sich in meinem Beispiel um einen offensichtlichen Fall von *Cross Site Scripting* (XSS).

Wir kommen mit *ver* zum Release des Core Rule-Sets, dann folgt mit *maturity* ein Hinweis auf die Qualität der Regel. Eine hohe *Maturität* besagt, dass wir dieser Regel trauen können, da sie breit eingesetzt wird und kaum zu Problemen geführt hat. Eine niedrige *Maturität* deutet hingegen eher auf eine experimentelle Regel hin. Der Wert 1 kommt in den *Core Rules* denn auch nur sechs Mal vor, während in der verwendeten Version 116 Regeln einen Wert von 8 besitzen, bei 99 Regeln wird sogar eine Reife von 9 angenommen. Ähnlich wie mit der *Maturity* verhält es sich mit *Accuracy*, also der Exaktheit der Regel. Auch dies ist ein optionaler Wert, den der Regelschreiber bei der Definition der Regel festgelegt hat. Hier kommen im Regelwerk gar keine tiefen Werte vor, 8 ist der häufigste Wert (144 Mal), 9 ist auch verbreitet (82). Diese verschiedenen Zusatzhinweise in der Log-Meldung dienen lediglich Dokumentationszwecken. In meiner Erfahrung sind sie wenig relevant und verändern sich zwischen den *Core Rules* Releases auch kaum.

Nun folgen eine Reihe von *Tags*, die der Regel zugewiesen werden. Zunächst der Tag *Local Lab Service*. Den hatten wir selbst in unserer Konfiguration definiert. Er wird also wie gewünscht jeder Regelverletzung mitgegeben. Danach folgen mehrere Tags aus dem *Core Rule Set*, welche die Art des Angriffs klassifizieren. Mit diesen Hinweisen lassen sich beispielsweise Auswertungen und Statistiken erstellen.

Gegen das Ende des Alarms folgen mit *hostname*, *uri* und *unique_id* drei weitere Werte, welche die Anfrage klarer spezifizieren. Mit der *Unique ID* können wir die Verbindung zu unserem *Access-Log* machen und mit der *URI* finden wir die betroffene Ressource auf unserem Server.

Ein einzelner Alarm bringt also sehr viel Information mit sich. Bei über 30'000 Einträgen eines einzigen *nikto*-Aufrufes kamen so 23MB an Daten zusammen. Man tut gut daran, die Grösse des *Error-Logs* im Auge zu behalten.

###Schritt 4: Anomalie-Werte auswerten

Das Format der Einträge im Error-Log ist zwar sehr klar, aber ohne Hilfsmittel ist es sehr anstrengend zu lesen. Einfache Abhilfe schaffen einige *Shell-Aliase*, welche einzelne Informationsteile aus den Einträgen ausschneiden. Sie sind im Alias-File abgespeichert, welches wir bereits in der 5. Anleitung hinzugeladen haben.

```
$> cat ~/.apache-modsec.alias
...
alias meldata='grep -o "\[data [^]]*" | cut -d\" -f2'
alias melfile='grep -o "\[file [^]]*" | cut -d\" -f2'
alias melhostname='grep -o "\[hostname [^]]*" | cut -d\" -f2'
alias melid='grep -o "\[id [^]]*" | cut -d\" -f2'
alias melip='grep -o "\[client [^]]*" | cut -b9-'
alias melline='grep -o "\[line [^]]*" | cut -d\" -f2'
alias melmatch='grep -o " at [^\ ]*\. \[file" | sed -e "s/\. \[file//" | cut -b5-'
alias melmsg='grep -o "\[msg [^]]*" | cut -d\" -f2'
alias meltimestamp='cut -b2-25'
alias melunique_id='grep -o "\[unique_id [^]]*" | cut -d\" -f2'
alias meluri='grep -o "\[uri [^]]*" | cut -d\" -f2'
...
$> source ~/.apache-modsec.alias 
```

Diese Abkürzungen beginnen mit dem Prefix *mel* - kurz für *ModSecurity-Error-Log*. Darauf folgt der Feldname. Probieren wir das einmal aus, um die Regel-ID der Meldungen auszugeben.

```
$> cat logs/error.log | melid | head
960015
990002
990012
960024
950005
981173
981243
981203
960901
960015
990002
```

Das funktioniert prinzipiell. Erweitern wir das Beispiel also in mehreren Schritten:

```
$> cat logs/error.log | melid | sort | uniq -c | sort -n
      1 950000
      1 950107
      1 950907
      1 950921
      1 960007
      1 960208
      1 960209
      1 981202
      1 981319
      2 958031
      2 959071
      2 960008
      2 973304
      2 973334
      3 950011
      3 973338
      3 981240
      3 981260
      3 981276
      3 981317
      5 950001
      5 959073
      5 960010
      6 950006
      6 981257
      7 970901
      8 981249
      9 981242
     11 960032
     13 960034
     15 973305
     15 973346
     17 960011
     17 960911
     19 981227
     29 981246
     64 973335
     67 950109
     68 960901
     75 981231
     77 981245
    106 958001
    141 950118
    155 981243
    162 981318
    179 950103
    219 960035
    225 950005
    231 973336
    245 958051
    245 973331
    247 950901
    248 973300
    284 958052
    284 973307
    418 960024
    531 981173
   2274 950119
   2335 950120
   6133 960015
   6134 981203
   6135 990002
   6135 990012
$> cat logs/error.log | melid | sort | uniq -c | sort -n  | while read STR; do echo -n "$STR "; ID=$(echo "$STR" | sed -e "s/.*\ //"); grep $ID logs/error.log | head -1 | melmsg; done
1 950000 Session Fixation
1 950107 URL Encoding Abuse Attack Attempt
1 950907 System Command Injection
1 950921 Backdoor access
1 960007 Empty Host Header
1 960208 Argument value too long
1 960209 Argument name too long
1 981202 Correlated Attack Attempt Identified: (Total Score: 22, SQLi=5, XSS=) Inbound Attack (SQL Injection Attack: Common Injection Testing Detected Inbound Anomaly Score: 18) + Outbound Application Error (The application is not available - Outbound Anomaly Score: 4)
1 981319 SQL Injection Attack: SQL Operator Detected
2 958031 Cross-site Scripting (XSS) Attack
2 959071 SQL Injection Attack
2 960008 Request Missing a Host Header
2 973304 XSS Attack Detected
2 973334 IE XSS Filters - Attack Detected.
3 950011 SSI injection Attack
3 973338 XSS Filter - Category 3: Javascript URI Vector
3 981240 Detects MySQL comments, conditions and ch(a)r injections
3 981260 SQL Hex Encoding Identified
3 981276 Looking for basic sql injection. Common attack string for mysql, oracle and others.
3 981317 SQL SELECT Statement Anomaly Detection Alert
5 950001 SQL Injection Attack
5 959073 SQL Injection Attack
5 960010 Request content type is not allowed by policy
6 950006 System Command Injection
6 981257 Detects MySQL comment-/space-obfuscated injections and backtick termination
7 970901 The application is not available
8 981249 Detects chained SQL injection attempts 2/2
9 981242 Detects classic SQL injection probings 1/2
11 960032 Method is not allowed by policy
13 960034 HTTP protocol version is not allowed by policy
15 973305 XSS Attack Detected
15 973346 IE XSS Filters - Attack Detected.
17 960011 GET or HEAD Request with Body Content.
17 960911 Invalid HTTP Request Line
19 981227 Apache Error: Invalid URI in Request.
29 981246 Detects basic SQL authentication bypass attempts 3/3
64 973335 IE XSS Filters - Attack Detected.
67 950109 Multiple URL Encoding Detected
68 960901 Invalid character in request
75 981231 SQL Comment Sequence Detected.
77 981245 Detects basic SQL authentication bypass attempts 2/3
106 958001 Cross-site Scripting (XSS) Attack
141 950118 Remote File Inclusion Attack
155 981243 Detects classic SQL injection probings 2/2
162 981318 SQL Injection Attack: Common Injection Testing Detected
179 950103 Path Traversal Attack
219 960035 URL file extension is restricted by policy
225 950005 Remote File Access Attempt
231 973336 XSS Filter - Category 1: Script Tag Vector
245 958051 Cross-site Scripting (XSS) Attack
245 973331 IE XSS Filters - Attack Detected.
247 950901 SQL Injection Attack: SQL Tautology Detected.
248 973300 Possible XSS Attack Detected - HTML Tag Handler
284 958052 Cross-site Scripting (XSS) Attack
284 973307 XSS Attack Detected
418 960024 Meta-Character Anomaly Detection Alert - Repetative Non-Word Characters
531 981173 Restricted SQL Character Anomaly Detection Alert - Total # of special characters exceeded
2274 950119 Remote File Inclusion Attack
2335 950120 Possible Remote File Inclusion (RFI) Attack: Off-Domain Reference/Link
6133 960015 Request Missing an Accept Header
6134 981203 Inbound Anomaly Score (Total Inbound Score: 10, SQLi=, XSS=): Rogue web site crawler
6135 990002 Request Indicates a Security Scanner Scanned the Site
6135 990012 Rogue web site crawler
```

Damit lässt sich arbeiten. Aber es bietet sich wohl an, den *One-Liner* genauer zu erklären. Wir extrahieren die Regelidentifikationen aus dem *Error-Log*, dann sortieren wir sie (*sort*), dann summieren wir diese Liste Liste nach den gefundenen IDs (*uniq -c*) und sortieren sie neu nach der Anzahl der Funde. Das ist der erste *One-Liner*. Da fehlt natürlich noch die Bezeichnung der einzelnen Regeln, denn mit der Identifikationsnummer könne wir noch nicht so viel anfangen. Die Bezeichnungen holen wir wieder aus dem *Error-Log* indem wir die vorher durchgeführte Auswertung Zeile um Zeile in einer Schleife durchsehen. In dieser Schleife zeigen wir mal an, was wir haben. Dann müssen wir die Summer der Funde und die Identifikation wieder trennen. Dies geschieht mittels einem eingebetteten Unter-Kommando (`ID=$(echo "$STR" | sed -e "s/.*\ //")`). Wir suchen dann mit der neu gefundenen Identifikation im *Error-Log* selbst wieder nach einem Eintrag, nehmen aber nur den ersten, holen den *msg*-Teil heraus und zeigen ihn an. Fertig.

Dieses Kommando kann je nach Rechnerleistung einige Sekunden oder sogar Minuten dauern. Man könnte nun meinen, es wäre schlauer einen zusätzlichen Alias zu definieren, um Identifikation und Beschreibung der Regel in einem Schritt zu eruieren. Dies führte uns aber auf den Holzweg, denn die Regel 981203 hat eine Bezeichnung, die in der Klammer und nach der Klammer dynamische Teile enthält. Das möchten wir natürlich zusammenfassen, um die Regel nur einmal abzubilden. Um die Auswertung also wirklich zu vereinfachen müssen wir die dynamischen Bezeichnungen eliminieren. Hier ein zusätzlicher *Alias*, der diese Idee umsetzt. Er ist Teil des bereits bekannten *Alias-Files .apache-modsec.alias*.

```bash
alias melidmsg='grep -o "\[id [^]]*\].*\[msg [^]]*\]" | sed -e "s/\].*\[/] [/" | cut -b6-11,19- | tr -d \] | sed -e "s/(Total .*/(Total ...) .../" | tr -d \"'
```

```
$> cat logs/error.log | melidmsg | sucs
      1 950000 Session Fixation
      1 950107 URL Encoding Abuse Attack Attempt
      1 950907 System Command Injection
      1 950921 Backdoor access
      1 960007 Empty Host Header
      1 960208 Argument value too long
      1 960209 Argument name too long
      1 981202 Correlated Attack Attempt Identified: (Total ...) ...
      1 981319 SQL Injection Attack: SQL Operator Detected
      2 958031 Cross-site Scripting (XSS) Attack
      2 959071 SQL Injection Attack
      2 960008 Request Missing a Host Header
      2 973304 XSS Attack Detected
      2 973334 IE XSS Filters - Attack Detected.
      3 950011 SSI injection Attack
      3 973338 XSS Filter - Category 3: Javascript URI Vector
      3 981240 Detects MySQL comments, conditions and ch(a)r injections
      3 981260 SQL Hex Encoding Identified
      3 981276 Looking for basic sql injection. Common attack string for mysql, oracle and others.
      3 981317 SQL SELECT Statement Anomaly Detection Alert
      5 950001 SQL Injection Attack
      5 959073 SQL Injection Attack
      5 960010 Request content type is not allowed by policy
      6 950006 System Command Injection
      6 981257 Detects MySQL comment-/space-obfuscated injections and backtick termination
      7 970901 The application is not available
      8 981249 Detects chained SQL injection attempts 2/2
      9 981242 Detects classic SQL injection probings 1/2
     11 960032 Method is not allowed by policy
     13 960034 HTTP protocol version is not allowed by policy
     15 973305 XSS Attack Detected
     15 973346 IE XSS Filters - Attack Detected.
     17 960011 GET or HEAD Request with Body Content.
     17 960911 Invalid HTTP Request Line
     19 981227 Apache Error: Invalid URI in Request.
     29 981246 Detects basic SQL authentication bypass attempts 3/3
     64 973335 IE XSS Filters - Attack Detected.
     67 950109 Multiple URL Encoding Detected
     68 960901 Invalid character in request
     75 981231 SQL Comment Sequence Detected.
     77 981245 Detects basic SQL authentication bypass attempts 2/3
    106 958001 Cross-site Scripting (XSS) Attack
    141 950118 Remote File Inclusion Attack
    155 981243 Detects classic SQL injection probings 2/2
    162 981318 SQL Injection Attack: Common Injection Testing Detected
    179 950103 Path Traversal Attack
    219 960035 URL file extension is restricted by policy
    225 950005 Remote File Access Attempt
    231 973336 XSS Filter - Category 1: Script Tag Vector
    245 958051 Cross-site Scripting (XSS) Attack
    245 973331 IE XSS Filters - Attack Detected.
    247 950901 SQL Injection Attack: SQL Tautology Detected.
    248 973300 Possible XSS Attack Detected - HTML Tag Handler
    284 958052 Cross-site Scripting (XSS) Attack
    284 973307 XSS Attack Detected
    418 960024 Meta-Character Anomaly Detection Alert - Repetative Non-Word Characters
    531 981173 Restricted SQL Character Anomaly Detection Alert - Total # of special characters exceeded
   2274 950119 Remote File Inclusion Attack
   2335 950120 Possible Remote File Inclusion (RFI) Attack: Off-Domain Reference/Link
   6133 960015 Request Missing an Accept Header
   6134 981203 Inbound Anomaly Score (Total ...) ...
   6135 990002 Request Indicates a Security Scanner Scanned the Site
   6135 990012 Rogue web site crawler
```

###Schritt 5: Fehlalarme auswerten

Mit unserem *Nikto*-Scan haben wir tausende von Alarmen losgetreten. Sie waren wohl berechtigt. Anders sieht es im normalen Einsatz von *ModSecurity* aus: Eine normale Installation wird je nach Applikation ebenfalls sehr viele Alarme sehen und erfahrungsgemäss sind die meisten davon Fehlalarme. Die Konfiguration muss zunächst justiert werden, um einen sauberen Betrieb sicher zu stellen. Was wir erreichen möchten ist eine hohe Trennschärfe. Wir wollen *ModSecurity* so konfigurieren, dass die Engine genau zwischen legitimen Anfragen und Angriffen zu unterscheiden weiss.

Fehlalarme sind in beide Richtungen möglich. Angriffe, welche nicht erkannt werden, nennt man *False Negative*. Die *Core-Rules* sind streng und achten darauf, *False Negatives* klein zu halten. Ein Angreifer muss schon sehr viel Grips investieren, um am Regelwerk vorbeizukommen. Diese Strenge führt leider dazu, dass auch erwünschte Anfragen an den Webserver zu Alarmen führen. Man nennt dies *False Positive* und davon gibt es sehr viele. Gemeinhin ist es so, dass man bei niedriger Trennschärfe entweder viele *False Negatives* erhält, oder viele *False Positives*. Die *False Negatives* zu reduzieren führt zu einer Erhöhung der *False Positives*. Die beiden Werte hängen also eng miteinander zusammen.

Diese Verbindung müssen wir überwinden: Wir wollen die Trennschärfe erhöhen, um die *False Positives* reduzieren zu können, ohne dass die *False Negatives* zunehmen. Dies erreichen wir, indem wir das Regelwerk punktuell nachjustieren. Zunächst benötigen wir aber ein klares Bild der gegenwärtigen Situation: Wie viele *False Positives* sind vorhanden und welche Regeln werden in welchem Kontext verletzt? Wir benötigen auch einen Plan, oder ein Ziel. Wie viele *False Positives* wollen wir dem System noch zugestehen? Sie auf null zu reduzieren wird uns nur sehr schwer gelingen, aber wir können mit Prozentzahlen arbeiten. Ein mögliches Ziel wäre: 99,99% der legitimen Anfragen sollen ohne Blockierung passieren dürfen. Das ist realistisch, bedeutet aber je nach Applikation einigen Aufwand.

Um ein solches Ziel zu erreichen, benötigen wir ein, zwei Hilfsmittel, die uns bei der Standort-Bestimmung helfen. Konkret geht es darum herauszufinden, welche *Anomaly-Scores* die verschiedenen Anfragen an den Server erreicht haben und welche Regeln denn tatsächlich verletzt wurden. Wir haben das *LogFormat* so angepasst, dass die *Anomaly-Scores* sich einfach aus dem *Access-Log* herauslesen lassen. Es geht nun darum, diese Daten in geeigneter Form darzustellen.

In der Anleitung 4 haben wir mit einem Beispiel-Logfile mit 10'000 Einträgen gearbeitet. Dieses Logfile ziehen wir hier nun erneut heran: [labor-04-example-access.log](https://github.com/Apache-Labor/labor/blob/master/labor-04/labor-04-example-access.log). Die Datei stammt von einem richtigen Server, die IP-Adressen, Servername und Pfade wurden aber vereinfacht, respektive umgeschrieben. Die für unsere Auswertung notwendigen Informationen sind aber nach wie vor vorhanden. Schauen wir uns die Verteilung der *Anomaly-Scores* einmal an:

```
$> egrep -o "[0-9-]+ [0-9-]+$" labor-04-example-access.log | cut -d\  -f1 | sucs
      1 21
      2 41
      8 5
     11 2
     17 3
     41 -
   9920 0
$> egrep -o "[0-9-]+$" labor-04-example-access.log | sucs
     41 -
   9959 0
```

Die erste Befehlszeile liest den eingehenden *Anomaly-Score* aus. Er ist auf der *Access-Log-Zeile* der zweithinterste Wert. Wir nehmen die beiden hintersten Werte (*egrep*) und schneiden dann den ersten aus (*cut*). Dann sortieren wir die Resultate mit dem bereits bekannten Alias *sucs*. Der ausgehende *Anomaly-Score* ist der hinterste Wert der *Log-Zeile*. Der *cut-*Befehl entfällt deshalb auf der zweiten Befehlszeile.

Diese Resultate geben uns eine Idee der Situation: Die allermeisten Anfragen passieren das *ModSecurity-Modul* ohne Regelverletzung. Es kommt ein Score von 41 zwei Mal vor, was zahlreichen schweren Regelverletzungen entspricht. Das ist in der Praxis durchaus gängig. Bei den Scores in den Antworten des Servers haben wir in 41 Fällen gar keinen Score erhalten. Dabei handelt es sich um Logeinträge von leeren Requests, wo zwar eine Verbindung mit dem Client zustande kam, aber kein Request abgesetzt wurde. Dieser Möglichkeit haben wir im regulären Ausdruck beim *egrep* jeweils Rechnung getragen und den Default-Wert "-" mitberücksichtigt. Neben diesen leeren Einträgen gab es gar keine anderen Auffälligkeiten. Das ist typisch. Wir werden in aller Regel zahlreiche Verletzungen bei den Anfragen und sehr wenige Alarme bei den Antworten sehen.

So eine richtige Idee über die nötigen *Tuning-Schritte* gibt uns dies aber noch nicht. Um diese Information in geeigneter Form darzustellen, habe ich ein Skript vorbereitet, das die *Anomaly-Scores* auswertet: [modsec-positive-stats.rb](https://github.com/Apache-Labor/labor/blob/master/bin/modsec-positive-stats.rb). Das Skript auf das Logfile angewendet bringt folgendes Resultat:

```
$> cat labor-04-example-access.log  | egrep -o "[0-9-]+ [0-9-]+$" | tr " " ";" | modsec-positive-stats.rb
INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |     41 |   0.4100% |   0.4100% |  99.5900%
Reqs with incoming score of   0 |   9920 |  99.2000% |  99.6100% |   0.3900%
Reqs with incoming score of   1 |      0 |   0.0000% |  99.6100% |   0.3900%
Reqs with incoming score of   2 |     11 |   0.1100% |  99.7200% |   0.2800%
Reqs with incoming score of   3 |     17 |   0.1699% |  99.8900% |   0.1100%
Reqs with incoming score of   4 |      0 |   0.0000% |  99.8900% |   0.1100%
Reqs with incoming score of   5 |      8 |   0.0800% |  99.9700% |   0.0300%
Reqs with incoming score of   6 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of   7 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of   8 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of   9 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  10 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  11 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  12 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  13 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  14 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  15 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  16 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  17 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  18 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  19 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  20 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  21 |      1 |   0.0100% |  99.9800% |   0.0200%
Reqs with incoming score of  22 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  23 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  24 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  25 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  26 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  27 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  28 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  29 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  30 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  31 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  32 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  33 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  34 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  35 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  36 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  37 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  38 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  39 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  40 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  41 |      2 |   0.0200% | 100.0000% |   0.0000%

Average:   0.0217        Median   0.0000         Standard deviation   0.6490


OUTGOING                     Num of req. | % of req. |  Sum of % | Missing %
Number of outgoing req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. outgoing score   |     41 |   0.4100% |   0.4100% |  99.5900%
Reqs with outgoing score of   0 |   9959 |  99.5900% | 100.0000% |   0.0000%

Average:   0.0000        Median   0.0000         Standard deviation   0.0000
```

Das Skript gliedert die eingehenden und die ausgehenden *Anomaly-Scores*. Zunächst werden die eingehenden behandelt. Zunächst beschreibt eine Zeile, wie oft ein leerer *Anomaly-Score* gefunden wurde (*empty incoming score*). In unserem Fall war das wie vorhin gesehen 41 Mal der Fall. Dann folgt die Aussage zum *score 0*: 9920 Anfragen. Dies entspricht einer Abdeckung von 99.2%. Zusammen mit den leeren Scores ist das bereits eine Abdeckung von 99.61% (*Sum of %*). 0.39% hatten einen höheren *Anomaly-Score* (*Missing %*). Wir haben oben definiert, dass wir erreichen wollen, dass 99.99% der Anfragen den Server passieren können. Davon trennen uns also noch 0.38% respektive 38 Anfragen. Der nächste im Datenbestand vorkommende *Anomaly-Score* ist 2. Er kommt 11 Mal vor, also 0.11%. Dann 17 Mal die 3 und 8 Mal einen Score von 5. Aufsummiert stehen wir damit bei 99.97%. Dann gab es einen Request mit einem Score von 21 und schliesslich noch 2 Anfragen mit 41. Um 99.99% Abdeckung zu erreichen müssen wir letztlich bis zu dieser Grenze gehen (und erhalten damit basierend auf dem Logfile 100% Abdeckung).

Vermutlich liegen hier *False Positives* vor. In der Praxis müssen wir dies sicherstellen, bevor wir in das Tuning der Regeln einsteigen. Es wäre ja grundfalsch aufgrund eines berechtigten Alarms ein False Positive anzunehmen und den Alarm zukünftig zu unterdrücken. Es muss also vor dem Tuning sicher gestellt werden, dass keine Angriffe im Logfile vorliegen. Das ist nicht immer ganz leicht. Manueller Review hilft, die Beschränkung auf bekannte IP-Adressen, das Testen / Tunen in einem eigenen, vom Internet getrennten Test-System, das filtern des Access-Logs nach Herkunftsländern der IP Adressen etc.: Es ist ein weites Feld und generelle Empfehlungen fallen schwer.

###Schritt 6: Fehlalarme unterdrücken: Einzelne Regeln ausschalten

Der einfache Weg, mit einem *False Positive* umzugehen, besteht darin, die Regel einfach auszuschalten. Das bedeutet sehr wenig Aufwand, aber ist natürlich potentiell gefährlich, denn die Regel ist damit nicht nur für legitime Benutzer, sondern auch für die Angreifer ausgeschaltet. Mit dem kompletten Ausschalten einer Regel beschneiden wir also die Fähigkeiten von *ModSecurity*. Oder drastischer ausgedrückt, wir ziehen der *WAF* die Zähne. In der Praxis ist dies unerwünscht. Trotzdem ist es wichtig zu wissen, wie diese einfache Methode funktioniert:

Wir haben oben die Liste der Alarme gesehen, welche wir mit dem Security Scanner *Nikto* provozieren konnten. Eine Regel, die neben *Nikto* aber bisweilen auch legitime Browser verletzen, ist 960015: Request Missing an Accept Header. Auf einem normalen Service sind die Alarme aufgrund dieser Regel sehr häufig. Für uns ist es ein Grund, die Regel auszuschalten.

In unserem Konfigurationsfile haben wir zwei Positionen markiert, an dem *Ignore Rules* platziert werden sollen. Ein Mal vor den *Core Rules*, ein zweites Mal nach den *Core Rules*:

```bash
# === ModSecurity Ignore Rules Before Core Rules Inclusion; order by id of ignored rule (ids: 10000-49999)

...

# === ModSecurity Core Rules Inclusion

Include    conf/modsecurity-core-rules-latest/*.conf

# === ModSecurity Ignore Rules After Core Rules Inclusion; order by id of ignored rule (ids: 50000-79999)

...

```

Wir unterdrücken die Regel *960015* im oberen Abschnitt. Bevor wir dies tun, provozieren wir einen Alarm der Regel:

```bash
$> curl -v -H "Accept: " http://localhost/index.html
...
> GET /index.html HTTP/1.1
> User-Agent: curl/7.32.0
> Host: localhost
...
$> tail /apache/logs/error.log
...
[Tue Dec 10 06:41:41 2013] [error] [client 127.0.0.1] ModSecurity: Warning. Operator EQ matched 0 at REQUEST_HEADERS. [file "/apache/conf/modsecurity-core-rules-latest/modsecurity_crs_21_protocol_anomalies.conf"] [line "47"] [id "960015"] [rev "1"] [msg "Request Missing an Accept Header"] [severity "NOTICE"] [ver "OWASP_CRS/2.2.8"] [maturity "9"] [accuracy "9"] [tag "Local Lab Service"] [tag "OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER_ACCEPT"] [tag "WASCTC/WASC-21"] [tag "OWASP_TOP_10/A7"] [tag "PCI/6.5.10"] [hostname "localhost"] [uri "/index.html"] [unique_id "UqaplX8AAQEAABiYANYAAAAD"]
[Tue Dec 10 06:41:41 2013] [error] [client 127.0.0.1] ModSecurity: Warning. Operator LT matched 1000 at TX:inbound_anomaly_score. [file "/apache/conf/modsecurity-core-rules-latest/modsecurity_crs_60_correlation.conf"] [line "33"] [id "981203"] [msg "Inbound Anomaly Score (Total Inbound Score: 2, SQLi=, XSS=): Request Missing an Accept Header"] [tag "Local Lab Service"] [hostname "localhost"] [uri "/index.html"] [unique_id "UqaplX8AAQEAABiYANYAAAAD"]
```

Wir haben *curl* angewiesen, einen Request ohne den *Accept-Header* abzusetzen. Mit der *Verbose*-Option (*-v*) können wir dieses Verhalten schön kontrollieren. Das *Error-Log* zeigt dann auch tatsächlich den provozierten Alarm und auf der folgenden Zeile die Zusammenfassung des *Anomaly Scores*: Die Regelverletzung brachte dem Request 2 Punkte. Nun unterdrücken wir die Regel durch das Schreiben einer *Ignore-Rule*, welche wir im dazu vorgesehenen Konfigurationsteil vor dem *Core-Rules Include" positionieren:

```bash
SecRule REQUEST_FILENAME "@beginsWith /" "phase:1,nolog,pass,t:none,id:10000,ctl:ruleRemoveById=960015"
```

Wir definieren eine Regel, welche zunächst den Pfad überprüft. Mit der Bedingung auf dem Pfad *"/"* wird die Regel natürlich immer zutreffen und die Bedingung ist damit an sich überflüssig. Wir setzen sie mit Vorteil dennoch in dieser Art, denn auf diesem Grundmuster lässt sie sich leicht für verschiedene Pfade verwenden. Ohne Bedingung würden wir sie als *SecAction* formulieren. Wir definieren unsere Regel in der Phase 1, wir wollen nicht loggen, sondern weisen ihr eine Identifikation zu Beginn unseres Blocks zu (*10000*). Schliesslich unterdrücken wir die Regel *960015*. Dies geschieht über eine Kontroll-Anweisung (*ctl:*).

Das war sehr wichtig. Deshalb nochmals zusammengefasst: Wir definieren eine Regel, um eine andere Regel zu unterdrücken. Wir benützen dazu ein Muster, das uns einen Pfad als Bedingung definieren lässt. Damit können wir Regeln für einzelne Applikationsteile ausschalten. Just dort, wo der Fehlalarm auftritt. Dies verhindert, dass wir die Regel auf dem gesamten Server ausschalten, während der Fehlalarm doch nur bei der Verarbeitung eines einzelnen Formulars auftritt, was sehr häufig der Fall ist. Das sähe etwa so aus:

```
SecRule REQUEST_FILENAME "@beginsWith /app/submit.do" "phase:1,nolog,pass,t:none,id:10001,ctl:ruleRemoveById=960015"
```

Nun haben wir also eine Regel ausgeschaltet. Sei es für den kompletten Service (Pfad *"/"*) oder für einen bestimmten Unterpfad (Pfad *"/app/submit.do"*). Leider sind wir damit blind geworden, was diese Regel betrifft: Wir wissen gar nicht mehr, ob eingehende Requests die Regel verletzen würden. Denn nicht immer kennen wir die Applikationen auf unseren Servern bis ins Detail und wenn wir nun ein Jahr abwarten und uns überlegen, ob wir die *Ignore-Rule* weiterhin brauchen, werden wir keine Antwort darauf haben. Wir haben jede Meldung zum Thema unterdrückt. Ideal wäre es, wenn wir das Zuschnappen der Regel noch beobachten könnten, aber so, dass der Request nicht blockiert wird und auch der *Anomaly Score* unverändert bleibt. Die Erhöhung des *Anomaly Scores* geschieht in der Definition der Regel. Dies ist in den *Core Rules* für die Regel *960015* wie folgt gelöst:

```
setvar:tx.inbound_anomaly_score=+%{tx.notice_anomaly_score}"
```

Hier wird also zur Transaktionsvariablen *inbound_anomaly_score* der Wert *tx.notice_anomaly_score* addiert. Wir haben die Möglichkeit, diese Regel konfigurativ zu verändern, ohne das Regelfile zu berühren. Die Addition können wir nicht unterdrücken, aber wir können sie mit einer Subtraktion neutralisieren. Dies bedeutet aber ein anderes Regelmuster in Form einer Regel, die nach der Einbindung der *Core Rules* konfiguriert wird.

```
...
SecRule REQUEST_FILENAME "@beginsWith /index.html" "chain,phase:2,log,pass,t:none,id:10004,msg:'Adjusting inbound anomaly score for rule 960015'"
   SecRule "&TX:960015-OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER-REQUEST_HEADERS" "@ge 1" "setvar:tx.inbound_anomaly_score=-%{tx.notice_anomaly_score}"
...
```

Wir haben hier zwei Regeln vor uns, die mittels dem Kommando *chain* verbunden werden. Das heisst, dass die erste Regel eine Bedingung formuliert und die zweite Regel nur ausgeführt wird, wenn die erste Bedingung zutrifft. In der zweiten Regel wird eine weitere, etwas kryptische Bedingung formuliert. Konkret sehen wir nach, ob eine bestimmte Variable gesetzt ist, nämlich *TX:960015-OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER-REQUEST_HEADERS*. Diese Transaktionsvariable wurde durch die Regel *960015* gesetzt und weist auf einen Treffer der Regel 960015 hin. Sollten wir diese Variable also vorfinden, dann bedeutet dies, dass die Regel 960015 angeschlagen hat. In diesem Fall reduzieren wir den *Inbound Anomaly Score* wieder um den Wert, um den die Regel ihn erhöht hat. Wir neutralisieren also den Effekt der Regel, ohne die Meldung selbst zu unterdrücken.

Im *Error-Log* ergibt das nachher für den oben bereits vorgestellen *curl-*Aufruf folgende zwei Einträge:

```bash
[2015-11-08 08:16:19.215089] [-:error] - - [client 127.0.0.1] ModSecurity: Warning. Operator EQ matched 0 at REQUEST_HEADERS. [file "/modsecurity-core-rules/modsecurity_crs_21_protocol_anomalies.conf"] [line "47"] [id "960015"] [rev "1"] [msg "Request Missing an Accept Header"] [severity "NOTICE"] [ver "OWASP_CRS/2.2.9"] [maturity "9"] [accuracy "9"] [tag "Local Lab Service"] [tag "OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER_ACCEPT"] [tag "WASCTC/WASC-21"] [tag "OWASP_TOP_10/A7"] [tag "PCI/6.5.10"] [hostname "localhost"] [uri "/app/submit.do"] [unique_id "Vj72w38AAQEAADwHNSoAAAAA"]
[2015-11-08 08:16:19.220263] [-:error] - - [client 127.0.0.1] ModSecurity: Warning. Operator GE matched 1 at TX. [file "/apache/conf/httpd.conf_labor-06"] [line "187"] [id "10001"] [msg "Adjusting inbound anomaly score for rule 960015"] [tag "Local Lab Service"] [hostname "localhost"] [uri "/app/submit.do"] [unique_id "Vj72w38AAQEAADwHNSoAAAAA"]
```

Der Eintrag zum abschliessenden *Anomaly-Score* fällt weg, da dieser Wert wieder auf 0 zurückgesetzt wurde. Das alles bedeutet nun, dass wir weiterhin informiert werden, wenn eine Regelverletzung vorliegt, aber dem Request wird kein *Anomaly-Score* mehr aufgrund dieser Regel zugewiesen. Wir haben den Alarm in diesem Sinn akzeptiert.

Diese Arten von Regeln sind anstrengend: Während die erste Bedingung einem bekannten Muster folgt, ist die zweite Regel, welche die Transaktionsvariable einschliesst, mit einigem Schreibaufwand verbunden: Wie kommen wir zum Variablen-Namen und woher kennen wir genau den Score?

Den Variablen-Namen können wir entweder aus der Regeldefinition in den *Core Rules* ableiten - oder wir halten uns an das *Debug-Log*, das wir in der höchsten Stufe (*SecDebugLogLevel 9*) definieren:

```
$> sudo egrep "Set variable.*960015" logs/modsec_debug.log
[16/Dec/2013:10:16:11 +0100] [localhost/sid#1470170][rid#7fbc5c018e40][/app/submit.do][9] Set variable "tx.960015-OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER-REQUEST_HEADERS" to "0".
```

Die hier als *tx.960015-OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER-REQUEST_HEADERS* muss in einer Regel als *TX:960015-OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER-REQUEST_HEADERS* geschrieben werden; genau so, wie wir es oben gemacht haben. Das vorgestellte *&* bedeutet, dass nicht die Variable selbst untersucht wird, sondern die Anzahl der Variablen mit diesem Namen: Also *1*. Den genauen Wert, den wir im *Inbound Anomaly Score* wieder abziehen müssen, finden wir ebenfalls im *Debug Log*:

```bash
$> sudo egrep -B9 "Set variable.*960015" logs/modsec_debug.log
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Setting variable: tx.anomaly_score=+%{tx.notice_anomaly_score}
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Recorded original collection variable: tx.anomaly_score = "0"
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Resolved macro %{tx.notice_anomaly_score} to: 2
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Relative change: anomaly_score=0+2
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Set variable "tx.anomaly_score" to "2".
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Setting variable: tx.%{rule.id}-OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER-%{matched_var_name}=%{matched_var}
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Resolved macro %{rule.id} to: 960015
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Resolved macro %{matched_var_name} to: REQUEST_HEADERS
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Resolved macro %{matched_var} to: 0
[08/Nov/2015:08:16:19 +0100] [localhost/sid#758700][rid#7fee30002970][/app/submit.do][9] Set variable "tx.960015-OWASP_CRS/PROTOCOL_VIOLATION/MISSING_HEADER-REQUEST_HEADERS" to "0"
```

Wir sehen hier im Detail, wie *ModSecurity* seine arithmetischen Funktionen durchführt. Interessant ist die erste Zeile, in der dargelegt wird, wie der Anomaly Score erhöht wird. Er wird um *tx.notice_anomaly_score* erhöht. Diesen Wert würden wir auch in der Definition der *Core Rules* finden, hier ist er aber leichter zu lesen.

Es kommt natürlich vor, dass eine Regel mehrfach verletzt wird. Das heisst, dass mehrere Parameter dieselbe Regel verletzen. Auch diesen Fall können wir abdecken, wenn auch unter der weiteren Erhöhung der Komplexität. In diesem Fall schreibt *ModSecurity* eine Collection-Variable, welche den Variablen-Namen mit einschliesst: also Regelnummer sowie Bezeichnung und dies um das Suffix *-ARGS:<name>* erweitert. Das ergibt für eine *File Injection Regel* wie *950005* zum Beispiel *TX:950005-OWASP_CRS/WEB_ATTACK/FILE_INJECTION-ARGS:contact_form_name*. Haben wir es mit zwei Parametern zu tun, welche diese Regel verletzen (sagen wir *contact_form_name* und *contact_form_address*), die folgende Konstruktion:

```bash
SecRule REQUEST_FILENAME "@beginsWith /app/submit.do" "chain,phase:2,log,t:none,pass,id:10003,msg:'Adjusting inbound anomaly score for rule 950005'"
   SecRule "&TX:950005-OWASP_CRS/WEB_ATTACK/FILE_INJECTION-ARGS:contact_form_name" "@ge 1" "setvar:tx.inbound_anomaly_score=-%{tx.critical_anomaly_score}"

SecRule REQUEST_FILENAME "@beginsWith /submit.do" "chain,phase:2,log,pass,t:none,id:10004,msg:'Adjusting inbound anomaly score for rule 950005'"
   SecRule "&TX:950005-OWASP_CRS/WEB_ATTACK/FILE_INJECTION-ARGS:contact_form_address" "@ge 1" "setvar:tx.inbound_anomaly_score=-%{tx.critical_anomaly_score}"
```

Auslösen können wir die Regelverletzung und die eben konfigurierte Nachjustierung der Anomalie-Werte durch folgenden Aufruf:

```bash
$> curl -d "contact_form_name=/etc/passwd" -d "contact_form_address=/etc/passwd" http://localhost/app/submit.do
...
$> tail -1 logs/access.log
127.0.0.1 - - [2015-11-08 08:25:46.950543] "POST /app/submit.do HTTP/1.1" 404 45 "-" "curl/7.46.0-DEV" localhost 127.0.0.1 80 - - "-" Vj74@n8AAQEAADydhKkAAAAE - - 219 231 -% 21734 19189 71 588 0 0
$> grep Vj74@n8AAQEAADydhKkAAAAE logs/error.log
...
[2015-11-08 08:25:46.961718] [-:error] - - [client 127.0.0.1] ModSecurity: Warning. Pattern match "(?:\\\\b(?:\\\\.(?:ht(?:access|passwd|group)|www_?acl)|global\\\\.asa|httpd\\\\.conf|boot\\\\.ini)\\\\b|\\\\/etc\\\\/)" at ARGS:contact_form_address. [file "/modsecurity-core-rules/modsecurity_crs_40_generic_attacks.conf"] [line "205"] [id "950005"] [rev "3"] [msg "Remote File Access Attempt"] [data "Matched Data: /etc/ found within ARGS:contact_form_address: /etc/passwd"] [severity "CRITICAL"] [ver "OWASP_CRS/2.2.9"] [maturity "9"] [accuracy "9"] [tag "Local Lab Service"] [tag "OWASP_CRS/WEB_ATTACK/FILE_INJECTION"] [tag "WASCTC/WASC-33"] [tag "OWASP_TOP_10/A4"] [tag "PCI/6.5.4"] [hostname "localhost"] [uri "/app/submit.do"] [unique_id "Vj74@n8AAQEAADydhKkAAAAE"]
[2015-11-08 08:25:46.961953] [-:error] - - [client 127.0.0.1] ModSecurity: Warning. Pattern match "(?:\\\\b(?:\\\\.(?:ht(?:access|passwd|group)|www_?acl)|global\\\\.asa|httpd\\\\.conf|boot\\\\.ini)\\\\b|\\\\/etc\\\\/)" at ARGS:contact_form_name. [file "/modsecurity-core-rules/modsecurity_crs_40_generic_attacks.conf"] [line "205"] [id "950005"] [rev "3"] [msg "Remote File Access Attempt"] [data "Matched Data: /etc/ found within ARGS:contact_form_name: /etc/passwd"] [severity "CRITICAL"] [ver "OWASP_CRS/2.2.9"] [maturity "9"] [accuracy "9"] [tag "Local Lab Service"] [tag "OWASP_CRS/WEB_ATTACK/FILE_INJECTION"] [tag "WASCTC/WASC-33"] [tag "OWASP_TOP_10/A4"] [tag "PCI/6.5.4"] [hostname "localhost"] [uri "/app/submit.do"] [unique_id "Vj74@n8AAQEAADydhKkAAAAE"]
[2015-11-08 08:25:46.970259] [-:error] - - [client 127.0.0.1] ModSecurity: Warning. Operator GE matched 1 at TX. [file "/apache/conf/httpd.conf_labor-06"] [line "187"] [id "50001"] [msg "Adjusting inbound anomaly score for rule 950005"] [tag "Local Lab Service"] [hostname "localhost"] [uri "/app/submit.do"] [unique_id "Vj74@n8AAQEAADydhKkAAAAE"]
[2015-11-08 08:25:46.970320] [-:error] - - [client 127.0.0.1] ModSecurity: Warning. Operator GE matched 1 at TX. [file "/apache/conf/httpd.conf_labor-06"] [line "190"] [id "50002"] [msg "Adjusting inbound anomaly score for rule 950005"] [tag "Local Lab Service"] [hostname "localhost"] [uri "/app/submit.do"] [unique_id "Vj74@n8AAQEAADydhKkAAAAE"]

```

Wir sehen also, wir können *ModSecurity* instruieren, die Core Rules anschlagen zu lassen, ohne den Score hochzuzählen. Man muss aber ehrlicherweise einräumen, dass die damit verbundenen Konstruktionen unheimlich aufwändig und auch fehleranfällig sind. Ich benütze diese Technik in der Praxis deshalb nicht, sondern unterdrücke *False Positives* durch selektives Ausschalten von Regeln und kämpfe aus diesem Grund mit der eingangs beschriebenen Blindheit.

Beim Ausschalten der Regeln haben wir eine sehr einfache Methode noch nicht kennengelernt:

###Schritt 7: Fehlalarme unterdrücken: Einzelne Regeln für bestimmte Parameter ausschalten

Bislang haben wir einzelne Regeln für bestimmte Pfade unterdrückt. In der Praxis gibt einen zweiten Fall, der zumindest quantitativ verbreitet ist: Ein einzelner Parameter, typischerweise ein Cookie, löst unabhängig vom Pfad Regelverletzungen aus. Bei jedem einzelnen Request kommt es also zu einer Regelverletzung. Beim ersten Blick auf die Statistik ist das erst einmal erschreckend. Aber wenn man sieht, wie einfach man dies bekämpfen kann, entspannt sich die Situation wieder etwas. Man müsste die Regel also für den Grundpfad */* ausschalten - oder man schafft es, die Regel generell für den betreffenden Parameter auszuschalten. Das geht so:

```bash
SecRuleUpdateTargetById 950005 "!REQUEST_COOKIES:basket_id"
```

Dieses Kommando, das nach dem Laden der *Core Rules* konfiguriert werden muss, passt die sogenannte *Target List* der Regel 950005 an. Das heisst, dass das Cookie *basket_id* nicht mehr länger durch die Regel 950005 untersucht werden soll. Das führt wieder zur erwähnten Blindheit, immerhin ist es bei einem Cookie aber zu einem späteren Zeitpunkt sehr leicht zu überprüfen, ob die damit verbundenen Regeln noch relevant sind.

Bei Formular-Parametern sollten wir nicht so generell vorgehen, dass wir ihre Behandlung auf dem gesamten Service ausschalten. Es gibt aber ein Regel-Muster, das sehr eng an diesem Beispiel anlehnt, aber nur für einen einzelnen Parameter auf einem einzigen Pfad greift:

```bash
SecRule REQUEST_FILENAME "@beginsWith /app/submit.do" "phase:2,nolog,pass,t:none,id:10002,ctl:ruleRemoveTargetById=950005;ARGS:contact_form_name"
```

Hier schalten wir die Behandlung des Parameters *contact_form_name* durch die Regel *950005* für den Pfad */app/submit.do* aus. Das ist punktgenau und in meiner Praxis die bevorzugte Art und Weise, ein einzelnes False Positive für einen Parameter zu unterdrücken.

Mit den verschiedenen Techniken der Konstruktion von *Ignore-Rules* besitzen wir nun das nötige Handwerkszeug, um die *False Positives* eine nach der anderen abzuarbeiten. Um zügig arbeiten zu können, braucht es Erfahrung und unterstützende Hilfsmittel, welche wir in der nächsten Anleitung kennen lernen werden.

###Schritt 8: Anomalie-Limite nachjustieren

Mit den oben beschriebenen Mustern für *Ignore-Rules* bearbeitet man nun die verschiedenen *False Positives*. Diese Arbeit ist sehr aufwändig. Im Hinblick auf das Ziel, die Applikation im Detail zu schützen, lohnt es sich aber sehr wohl. Zu bedenken gilt allerdings, bis zu welchem Grad man die *False Positives* eliminieren soll. Ein typischer Zielwert ist es etwa, jeden Request zu blockieren, der eine als *kritisch* eingestufte Regel verletzt. Das bedeutet, dass die *Anomaly Limite* auf 5 gesetzt wird. Jeder Request, der nun eine kritische Regel verletzt, erhält einen Wert von mindestens 5 zugewiesen und wird dann final blockiert. Ein entsprechend getunter Service könnte eine *Access-Log* Auswertung nach folgendem Muster erhalten:

```
$> egrep  -o "[0-9]+ [0-9]+$" logs/access.log   | ./modsec-positive-stats.rb 
INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with incoming score of   0 |   9970 |  99.7000% |  99.7000% |   0.3000%
Reqs with incoming score of   1 |      4 |   0.0400% |  99.7400% |   0.2600%
Reqs with incoming score of   2 |     21 |   0.2100% |  99.9500% |   0.0500%
Reqs with incoming score of   3 |      0 |   0.0000% |  99.9500% |   0.0500%
Reqs with incoming score of   4 |      4 |   0.0400% |  99.9900% |   0.0100%
Reqs with incoming score of   5 |      1 |   0.0100% | 100.0000% |   0.0000%

Average:   0.0067        Median   0.0000         Standard deviation   0.1329


OUTGOING                     Num of req. | % of req. |  Sum of % | Missing %
Number of outgoing req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. outgoing score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with outgoing score of   0 |  10000 | 100.0000% | 100.0000% |   0.0000%

Average:   0.0000        Median   0.0000         Standard deviation   0.0000
```

Von 10'000 Requests besitzen 9999 einen *Anomaly Score* von 4 oder tiefer. Der Service ist damit abschliessend getunt. Wir können damit das anfangs erhöhte *Inbound Anomaly Score Limit* reduzieren. Wenn wir bei kritischen Regelverletzungen alarmiert werden möchten, dann setzen wir die Limite wie folgt:

```
...
SecAction "id:'900002',phase:1,t:none,setvar:tx.inbound_anomaly_score_level=5,nolog,pass"
SecAction "id:'900003',phase:1,t:none,setvar:tx.outbound_anomaly_score_level=5,nolog,pass"
...
```

Den *Outbound Anomaly Score* scheren wir über denselben Kamm. In der Praxis wird man meist etwas differenzierter vorgehen müssen.

###Schritt 9: Zusammenfassung der Varianten bei der Bekämpfung von False Positives

Wir haben damit vier verschiedene Arten kennengelernt, wie man einen Fehlalarm unterdrücken kann. Ich stelle sie hier nochmals nebeneinander mit jeweils einem konkreten Beispiel vor:

**Fall 1 : Regel für bestimmten Pfad deaktivieren** </br>
```bash
SecRule REQUEST_FILENAME "@beginsWith /app/submit.do" "phase:1,nolog,pass,t:none,id:10001,ctl:ruleRemoveById=950005"
```
Position in der Konfiguration: Am besten generell vor dem *Core Rule Include* platzieren, kann aber bei *phase:1* auch nach *Include* platziert werden. </br>
Phase: Mit Vorteil in Phase 1, da der Pfad in diesem Moment bekannt ist.</br>


**Fall 2 : Regel für bestimmten Parameter deaktivieren** </br>
```bash
SecRuleUpdateTargetById 950005 "!ARGS:contact_form_name"
```
Position in der Konfiguration: Generell nach dem *Core Rule Include* platzieren. </br>


**Fall 3 : Regel für bestimmten Parameter auf einem bestimmten Pfad deaktivieren** </br>
```bash
SecRule REQUEST_FILENAME "@beginsWith /app/submit.do" "phase:2,nolog,pass,t:none,id:10002,ctl:ruleRemoveTargetById=950005;ARGS:contact_form_name"
```
Position in der Konfiguration: Am Besten generell vor dem *Core Rule Include* platzieren. </br>
Phase: Für *Post-Parameter* zwingend in Phase 2, ansonsten auch Phase 1 denkbar.</br>


**Fall 4 : Regel aktiv lassen, aber Scoring für bestimmten Parameter auf bestimmten Pfad deaktiveren** </br>
```bash   
SecRule REQUEST_FILENAME "@beginsWith /app/submit.do" "chain,phase:2,log,pass,t:none,id:10003,msg:'Adjusting inbound anomaly score for rule 950005'"
SecRule "&TX:950005-OWASP_CRS/WEB_ATTACK/FILE_INJECTION-ARGS:contact_form_name" "@ge 1" "setvar:tx.inbound_anomaly_score=-%{tx.critical_anomaly_score}"
```
Position in der Konfiguration:: Am Besten generell vor dem *Core Rule Include* platzieren. </br>
Phase: Für *Post-Parameter* zwingend in Phase 2, ansonsten auch Phase 1 denkbar.</br>

In der Praxis ist es wichtig, systematisch vorzugehen. *ModSecurity* und die *Core Rules* sind bereits sehr komplex. Wenn wir nicht gut aufpassen, resultiert von all unseren Tuning-Bemühungen zu guter Letzt nur noch ein grosses Chaos. Besser ist es, sich zu überlegen, mit welchen Tuning-Regel-Ansätzen man arbeiten möchte. Technisch gesehen ist die Variante über die Manipulation des *Anomaly Scores* die bevorzugte Vorgehensweise. Allerdings ist sie nur schwer zu lesen und auch der Schreib- und Testaufwand überwiegt gegenüber den einfacheren Varianten, obschon diese wiederum den beschriebenen Nachteil mit sich bringen, dass man sämtliche Meldungen zur Regel unterdrückt.

In der nächsten Anleitung werden wir uns der Praxis zuwenden und aus den Logfiles einer ungetunten Applikation Tuning-Regeln ableiten.

###Schritt 10 (Bonus): Ein Bier

Diese Anleitung war ein hartes Stück Arbeit. Für einmal brechen wir also hier ab und genehmigen uns ein Bier. In der nächsten Anleitung geht es um die Praxis beim Tuning. Die prinzipiellen Techniken haben wir in dieser Anleitung kennengelernt, aber wie wendet man diese Techniken gezielt an, wenn man in einer Vielzahl von False Positives versinkt?

###Verweise
- [Spider Labs Blog Post: Exception Handling](http://blog.spiderlabs.com/2011/08/modsecurity-advanced-topic-of-the-week-exception-handling.html)
- [ModSecurity Referenzhandbuch](https://github.com/SpiderLabs/ModSecurity/wiki/Reference-Manual)

### Lizenz / Kopieren / Weiterverwenden

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />Diese Arbeit ist wie folgt lizenziert / This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

