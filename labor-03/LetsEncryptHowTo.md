##Let's Encrypt BETA

###Was ist Let's Encrypt?

Let's Encrypt will das ganze Internet sicher machen. 
Die Zertifizierungsstelle hat es sich zum Ziel gemacht, das ganze Internet mit Zertifikaten zu versorgen.
Betrieben wird das Projekt von der non-profit Organisation _Internet Security Research Group (ISRG)_.

Let's Encrypt m�chte das ganze Vorhaben kostenlos, automatisiert, und offen f�r alle zur Verf�gung stellen.

Bekannte Sponsoren des Projekts sind etwa Mozilla, Cisco und Google Chrome. 
Und auch Facebook scheint ein Interesse an einem sichern Web zu haben.
Zudem finden sich Namen von grossen schweizer Hosting Anbietern, welche in ihren Angeboten inzwischen gratis SSL-Zertifikate anbieten.
Das Ziel von 100% https ist also auf eine solide Basis gestellt.

###Wie funktioniert das?

Da das Ganze automatisiert geschehen soll, ben�tigen wir einen Client oder ein Script auf unserem Server, 
sodass wir keinen Aufwand mehr haben ein Zertifikat zu bestellen.
 * genauere Technische Erkl�rung (Englisch): https://letsencrypt.org/how-it-works/

Let's Encrypt schl�gt einige Clients vor.
Eine einfache Variante (es handelt sich lediglich um ein Bash-Script) ist getssl.

###HowTo

Mit der nachfolgenden Zeile kopieren wir den ganzen Source-Code zu uns auf den Server und geben Ausf�hr-Rechte:

```
curl --silent https://raw.githubusercontent.com/srvrco/getssl/master/getssl > getssl ; chmod 700 getssl
```

Nun f�hren wir das Script aus um die ben�tigten Dateien zu generieren:

(Nat�rlich sollte man die Domain besitzen und diese bei einem Registrar angemeldet haben.)

```
./getssl -c domain.ch
```

Nun haben wir im Home-Verzeichnis folgende Dateien:

```
~/.getssl/getssl.cfg #<- Konfigurationsdatei f�r alle Domains
~/.getssl/domain.ch/getssl.cfg #<- Konfigurationsdatei f�r domain.ch
```

In den zwei Dateien passen wir nun nach unseren Bed�rfnissen an:

~/.getssl/getssl.cfg
```
# Testserver (stellt kein g�ltigen Zertifikate aus)
CA="https://acme-staging.api.letsencrypt.org"
# Der "richtige" Zertifikatserver, ACHTUNG: Aus Sicherheitsgr�nden gibt es ein Limit f�r angeforderte Zertifikate. Also nicht "probieren"
#CA="https://acme-v01.api.letsencrypt.org"

AGREEMENT="https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf"

# Unser "Account"
ACCOUNT_EMAIL="me@example.com" #Mail-Adresse welche hinterlegt wird
ACCOUNT_KEY_LENGTH=4096
ACCOUNT_KEY="/home/[USERHOME]/.getssl/account.key"
PRIVATE_KEY_ALG="rsa"

# Erlaubter Zeitraum in Tagen welcher neue Zertifikate angefordert werden
RENEW_ALLOW="30"

# openssl config file. Sollte im normalfall funktionieren
SSLCONF="/usr/lib/ssl/openssl.cnf"
```

~/.getssl/domain.ch/getssl.cfg
(Wenn direkt mehrere Domains "verwaltet" werden k�nnen hier noch jeweils Abweichungen vom "Standard" oben gemacht werden.)
```
# Testserver (stellt kein g�ltigen Zertifikate aus)
#CA="https://acme-staging.api.letsencrypt.org"
# Der "richtige" Zertifikatserver, ACHTUNG: Aus Sicherheitsgr�nden gibt es ein Limit f�r angeforderte Zertifikate. Also nicht "probieren"
#CA="https://acme-v01.api.letsencrypt.org"

#AGREEMENT="https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf"

# Unser "Account"
#ACCOUNT_EMAIL="me@example.com"
#ACCOUNT_KEY_LENGTH=4096
#ACCOUNT_KEY="/home/user/.getssl/account.key"
PRIVATE_KEY_ALG="rsa"

# Die zus�tzlich zu zertifizierenden Subdomains / Domains
SANS=www.domain.ch,srv.domain.ch

# Acme Challenge Location. 
# Erste Zeile f�r die Domain. Die zus�tzlichen f�r die oben erw�hnten zus�tzlichen Subdomains / Domains
# Dort wird eine "Challenge" hinterlegt welche dann von Let's Encrypt abgefragt wird. (Muss also im DocumentRoot liegen)
ACL=('/apache/htdocs/.well-known/acme-challenge'
     '/apache/htdocs/.well-known/acme-challenge'
     '/apache/htdocs/.well-known/acme-challenge')

# Ort der Zertifikate
DOMAIN_CERT_LOCATION="/etc/ssl/domain.crt"
DOMAIN_KEY_LOCATION="/etc/ssl/domain.key"
#CA_CERT_LOCATION="/etc/ssl/chain.crt"
#DOMAIN_CHAIN_LOCATION="" this is the domain cert and CA cert
#DOMAIN_PEM_LOCATION="" this is the domain_key. domain cert and CA cert


# Befehl um den Apache die Konfiguration neu laden zu lassen
RELOAD_CMD="service apache2 reload"
# Erlaubter Zeitraum in Tagen welcher neue Zertifikate angefordert werden
#RENEW_ALLOW="30"

# Define the server type.  The can either webserver, ldaps or a port number which
# will be checked for certificate expiry and also will be checked after
# an update to confirm correct certificate is running (if CHECK_REMOTE) is set to true
#SERVER_TYPE="webserver"
#CHECK_REMOTE="true"

# Eine von 3 Varianten um via DNS zu �berpr�fen
#VALIDATE_VIA_DNS="true"
#DNS_ADD_COMMAND=
#DNS_DEL_COMMAND=
# If your DNS-server needs extra time to make sure your DNS changes are readable by the ACME-server (time in seconds)
#DNS_EXTRA_WAIT=60
```

Nun f�hren wir das Script nochmals mit unseren Konfigurationen aus:

```
getssl domain.ch
```

Sollte dann etwa so aussehen:
```
Registering account
Verify each domain
Verifing yourdomain.com
Verified yourdomain.com
Verifing www.yourdomain.com
Verified www.yourdomain.com
Verification completed, obtaining certificate.
Certificate saved in /home/user/.getssl/yourdomain.com/yourdomain.com.crt
The intermediate CA cert is in /home/user/.getssl/yourdomain.com/chain.crt
copying domain certificate to ssh:server5:/home/yourdomain/ssl/domain.crt
copying private key to ssh:server5:/home/yourdomain/ssl/domain.key
copying CA certificate to ssh:server5:/home/yourdomain/ssl/chain.crt
reloading SSL services
```

Wenn nun alles funktioniert, die Dateien richtig generiert werden, setzen wird den CA-Server auf "produktiv":

~/.getssl/getssl.cfg
```
# Testserver (stellt kein g�ltigen Zertifikate aus)
#CA="https://acme-staging.api.letsencrypt.org"
# Der "richtige" Zertifikatserver, ACHTUNG: Aus Sicherheitsgr�nden gibt es ein Limit f�r angeforderte Zertifikate. Also nicht "probieren"
CA="https://acme-v01.api.letsencrypt.org"

...
```

Danach forcieren wir ein Neugenerieren um auch ein g�ltiges Zertifikat zu bekommen:
```
getssl -f domain.ch
```

Fertig. :)


####Automatisierte Abfrage mittels Cron-Job

Um nicht regelm�ssig das Script auszuf�hren, greifen wir auf einen Cron-Job zur�ck:

```
crontab -e
```
Folgende Zeile �berpr�ft Regelm�ssig auf eine aktualisierung:
```
23  5 * * * [Pfad zum Script]/getssl -u -a -q
```

Quellen:

 * https://github.com/srvrco/getssl
 * https://letsencrypt.org/getting-started/
 * https://letsencrypt.org/how-it-works/
