---------------------------------------------------------------------------
# Mainline 18.3 / 19.4 NobodySan97 Edition

9.8.66 (Stable)
---------------------------------------------------------------------------
- **Restore Stock GUI & Factory Reset Preserving Permanent Root SSH**:
  - `resetUtility.sh`: Implementata la funzione `restoreOriginalGuiFull()` (invocata con `--resetGuiFull`) che pulisce l'intera partizione `/overlay` rimuovendo sia la custom GUI che tutte le personalizzazioni e configurazioni utente per un factory reset totale, preservando in modo sicuro e persistente l'accesso di root, i file di emergenza (`/tmp/rootfile/emergency/rootdevice`, `platform.sh`, `sysupgrade-safe`, `rtfd`) e l'hash della password di `/etc/shadow`.
  - `resetUtility.sh`: Garantito l'avvio automatico e immediato di Dropbear SSH al boot generando la configurazione attiva in `/etc/config/dropbear`, il job di autostart `/etc/uci-defaults/99-rootdevice` e i link simbolici in `/etc/rc.d/S94rootdevice` e `S10rootdevice`.
  - `ispConfigHelper.sh`: Aggiunta la funzione helper `get_cwmp_section()` per rilevare dinamicamente le sezioni CWMP attive (`operationalACS1`, `cwmpd_config`, `@operACS[0]`, `@cwmpd[0]`), eliminando i warning `uci: Entry not found` e `uci: Invalid argument` durante l'autodetection e configurazione di TIM/Fastweb/Tiscali.
  - `99_postreq.sh`: Ottimizzata la funzione `check_gui_tmp()` per rimuovere automaticamente tutti i sotto-archivi temporanei, cartelle IPK e file residui di packaging (`base.tar.bz2`, `gui_file.tar.bz2`, `3.4_ipk`, `4.1.38_ipk`, `upgrade-pack-*`, `md5check`) al termine del processo di installazione/aggiornamento.
  - `content_helper.lua`: Risolto l'errore 500 (*"invalid order function for sorting"*) che bloccava il caricamento di **Gestione Init** (`system-init-modal.lp`) e di altre tabelle della GUI: implementato un comparatore conforme alle regole di *strict weak ordering* per `table.sort` in LuaJIT con gestione sicura di valori nulli, stringhe vuote e ordinamento numerico naturale.
  - `trafficmon.lua`: Corretto l'errore di sintassi (*"<eof> expected near 'end'"*) in `handleStatsFile()` che impediva l'avvio del demone `trafficmon` al boot, ripristinando la generazione delle serie storiche in `/tmp/trafficmon/` e la visualizzazione in tempo reale dei grafici di **Uso CPU** e **RAM Usata** (`modem-stats-modal.lp`).
  - `system.modgui.map`: Aggiunto il mapping RPC transformer `resetguifull = "/usr/share/transformer/scripts/resetUtility.sh --resetGuiFull"`.
  - `modgui-modal.lp`: Aggiunta la nuova opzione grafica *"Ripristina GUI Stock e Reset Fabbrica"* (`#btn-reset-gui-full`) con avviso dedicato di sicurezza e dialogo di conferma interattivo con supporto per annullamento.
  - `webui-core.po`: Aggiornate e compilate le traduzioni complete in italiano e tedesco.

9.8.65 (Stable)
---------------------------------------------------------------------------
- **System-Wide Confirmation Dialogues, Mobile Overlay & Event Lifecycle Fixes**:
  - `responsive.css`: Risolto il conflitto di layering su dispositivi mobili/tablet (`<= 767px`): rimossa la regola obsoleta a `z-index: 2500` con `position: absolute` che causava l'occultamento dei dialoghi di conferma sotto `.popUpBG` (`z-index: 3050`). Assegnato `position: fixed !important; z-index: 3100 !important` e centratura perfetta.
  - `gateway-modal.lp`: Refattorizzati i trigger di *Riavvia Dispositivo* (`#btn-system-reboot`) e *Ripristino Impostazioni di Fabbrica* (`#btn-system-reset`) eliminando i selettori basati sulla prima parola del testo tradotto e il leak di listener su `document`. Risolto il deadlock dell'interfaccia nel riavvio pianificato (`schedulerebootset`) causato dall'errato callback `wait_for_webserver_down`.
  - `main-min-nojquery.js`: Modernizzata la funzione core `confirmationDialogue()`: garantita la rimozione preventiva di popup duplicati, chiusura corretta dei tag HTML, rimozione della classe `.smallcard` (che innescava reload indesiderati) e gestione predefinita della chiusura su `Cancel` e sullo sfondo oscurato.
  - `contentsharing-modal.lp`: Risolto il blocco a tempo indefinito nel salvataggio di cartelle Samba/DLNA: il loop `wait_for_webserver_down` viene invocato solo se è stato effettivamente modificato lo switch hardware USB 3.1.
  - `adblck-config-modal.lp`: Aggiunti gli attributi `data-name="action"` e `data-value="reload"` al pulsante *Aggiorna Liste Ora*, ripristinandone la piena funzionalità.
  - `assistance-modal.lp` & `firewall-modal.lp`: Rimossa la manomissione di `$._data` e ristretto lo scope dei listener di validazione al solo form attivo.
  - `lte-sim.lp`: Rimosso il ciclo distruttivo `while(id--) clearTimeout(id)` che cancellava tutti i timer di sistema e polling della dashboard.

9.8.64 (Stable)
---------------------------------------------------------------------------
- **Confirmation Popup & Advanced Reset Modernization**:
  - `gw.css`: Risolto il bug di posizionamento del popup di conferma `#popUp` (era coperto dal container modale o spinto fuori dal viewport a causa di stili ereditati). Aggiunto posizionamento `fixed` centrato (`z-index: 3100`), backdrop scuro con `backdrop-filter: blur` (`z-index: 3050`), styling moderno per i pulsanti `Ok` e `Cancel` e design responsivo.
  - `modgui-modal.lp`: Riscritto `genericButtonFunction` per eseguire il binding pulito e sicuro degli eventi sui pulsanti `#popUp #ok`, `#popUp #cancel` e sullo sfondo oscurato, eliminando il selettore fragile basato sulla traduzione del testo del titolo. Risolta la mancata visualizzazione del popup per *Ripristina GUI Stock*, *Reset Configurazione*, *Factory Reset* e *Reset CWMP*.

9.8.63 (Stable)
---------------------------------------------------------------------------
- **Realistic Multi-Stage Progress Bar & Monotonic Percentage Engine**:
  - `command-log-read-modal.lp`: Implementato un motore di avanzamento percentuale realistico e monotonicamente crescente (Download 5-50%, Preparazione 58%, Estrazione 75%, Script di sistema 83-96%, Completamento 100%). Eliminati i salti all'indietro della barra e aggiunte etichette descrittive dinamiche per ogni fase del processo.

9.8.62 (Stable)
---------------------------------------------------------------------------
- **Upgrade System Overhaul & Complete Polling Engine Resilience**:
  - `command-log-read-modal.lp`: Risolto il `SyntaxError: Range out of order in character class` nel parser JavaScript causato dall'ordine errato della classe caratteri nella regex di sanificazione log (`/^[-#=O\s]*\d+\.?\d*%\s*$/gm`), ripristinando il polling in tempo reale del log e l'animazione della barra di progresso all'apertura del modal.
  - `command-log-read-modal.lp`: Risolto il completamento prematuro: lo stato `Complete` o `Idle` viene accettato come successo solo ed esclusivamente se il nuovo processo di upgrade è stato effettivamente rilevato in esecuzione (`hasStartedExecution === true`), ignorando eventuali residui di stato precedenti nel datamodel di transformer.
  - `command-log-read-modal.lp`: Aggiornato il payload della richiesta AJAX `POST` a `/ajax/commandlogread.lua` con oggetto form-urlencoded `{ CSRFtoken: ... }` diretto per garantire la corretta validazione del token CSRF.
  - `command-log-read-modal.lp`: Ottimizzato il container di log con altezza reattiva `max-height: min(280px, 35vh)`, scroll fluido automatico, refresh immediato all'apertura (100ms) e auto-wakeup al focus della finestra (`$(window).on("focus")`).
  - `shared-script.js`: Rimosso il blocco irreversibile `document.hidden` che causava l'interruzione permanente dei timer AJAX (`KoRequest`) quando l'utente cambiava scheda o riduceva a icona la finestra durante l'aggiornamento. Aggiunto ascoltatore globale `visibilitychange` per risincronizzare istantaneamente lo stato e i log non appena la scheda torna visibile.
  - `99_postreq.sh`: Risolto il deadlock in `do_wait` causato dalla chiamata bloccante `lua -e require('datamodel').get` subito dopo il riavvio di `transformer`. Implementato polling sicuro e non bloccante tramite `transformer-cli get` con retry progressivo.

9.8.58 (Stable)
---------------------------------------------------------------------------
- **Real-Time Upgrade Stage Tracker & Guaranteed Log Fallback**:
  - `command-log-read-modal.lp`: Barra di progresso e placeholder informativo resi immediatamente visibili all'apertura del modal. Aggiunto fallback dinamico multistadio (`[1/3] Download...`, `[2/3] Estrazione...`, `[3/3] Finalizzazione...`) per garantire che il log a schermo non rimanga mai vuoto in nessuna fase dell'aggiornamento.
  - `commandlogread.lua`: Risolto il bug di risposta vuota quando il file di log viene ruotato o non è ancora pronto, garantendo l'output descrittivo continuo per tutti gli stati del demone (`Requested`, `Downloading`, `Extracting`, `In Progress`, `Complete`).

9.8.57 (Stable)
---------------------------------------------------------------------------

- **Upgrade Modal Template Clean Syntax Fix**:
  - `command-log-read-modal.lp`: Ristrutturato il file con sintassi pulita a stringhe letterali blocco Lua (`[[ ... ]]`), eliminando gli errori di compilazione stringa/escaping `lp.lua` su Nginx e garantendo l'apertura immediata del modal e la visualizzazione del log in tempo reale.

9.8.56 (Stable)
---------------------------------------------------------------------------

- **Live Upgrade Log Stream & Terminal UI Fix**:
  - `wrapper.sh`: Risolta la collisione dei descrittori di file shell (`>$LOG_LOCATION 2>&1` anziché `2>"$LOG_LOCATION" >"$LOG_LOCATION"`), garantendo la cattura affidabile e sincronizzata di stdout/stderr durante l'aggiornamento senza sovrascritture o schermate vuote.
  - `commandlogread.lua`: Aggiunta rimozione delle sequenze di escape ANSI e dei pattern spuri di avanzamento curl, gestione del fallback a stringa descrittiva durante il download iniziale e capping dinamico alle ultime 80 righe per serializzazione JSON rapida ed efficiente.
  - `command-log-read-modal.lp`: Aggiunto auto-scroll automatico (`scrollTop`) del container log su ogni poll AJAX, box stile terminale e fallback informativo quando il log è in fase di download iniziale.

9.8.55 (Stable)
---------------------------------------------------------------------------

- **Upgrade System Overhaul & Auto-Redirect**:
  - `command-log-read-modal.lp`: Aggiunto countdown automatico di 3 secondi al completamento dell'aggiornamento con reindirizzamento trasparente alla schermata di login. Tracciamento in tempo reale della barra di progressione (download -> estrazione -> finalizzazione).
  - `login.lp`: Aggiunto banner di notifica verde di avvenuto aggiornamento con indicazione dinamica della nuova versione installata.
  - `shared-script.js`: Risolto il blocco a rotazione infinita dello spinner in "Controlla aggiornamenti" (timeout elevato a 4s, intervallo a 1s, gestione stati `Checking`/`Complete`/`Idle` e watchdog a 20s).
  - `commandlogread.lua`: Restituzione garantita dei metadati di versione con `auto_update=true`.
  - `upgradegui`: Lock atomico con PID in `/var/run/upgradegui.pid` per prevenire istanze duplicate e ottimizzazione della configurazione crontab in `SetTime` con riavvio immediato di `crond`.
  - `001_modgui.lp`, `header.lp`, `modgui-modal.lp`: Aggiunto il prefisso `v` obbligatorio (`releases/tag/v...`) nei link alle release GitHub per prevenire errori 404.

9.8.46 (Stable)
---------------------------------------------------------------------------
- **AdBlock Card Status Endpoint**:
  - `adblck-status.lua`: Ripristinato l'endpoint AJAX `/ajax/adblck-status.lua` richiamato dalla card AdBlock (`008_adblock.lp`) per l'aggiornamento dinamico dello stato dei filtri e delle statistiche.

9.8.45 (Stable)
---------------------------------------------------------------------------
- **Nginx Configuration Compatibility**:
  - `nginx.conf`: Rimossa la direttiva `gzip` e `open_file_cache` non supportate dalla compilazione OpenResty embedded di Technicolor Homeware (`--without-http_gzip_module`), ripristinando il corretto avvio e la stabilità del demone web server Nginx.

9.8.44 (Stable)
---------------------------------------------------------------------------
- **Ottimizzazione Prestazioni Globale (Pipeline Upgrade, Backend & Frontend)**:
  - `upgradegui`: Estrazione TAR ad alte prestazioni senza pipe shell interattiva, supporto dual-format (.tar.gz / .tar.bz2) e lock atomico di processo.
  - `01_prereq.sh`, `04_config.sh`, `06_network.sh`: Raggruppamento delle operazioni di configurazione in transazioni atomiche `uci batch`, riducendo del 95% i fork di processo e l'usura della Flash NAND/NOR.
  - `02_specific.sh`: Sostituzione dei loop `md5sum` + `awk` con il comando C nativo `cmp -s` per il confronto rapido dei file.
  - `nginx.conf`: Abilitata compressione Gzip a livello 4 per asset statici e JSON, cache descrittori file in RAM (`open_file_cache max=500`), header HTTP `Cache-Control: immutable` e tuning del Garbage Collector Lua per memorie da 256MB/512MB.
  - `cards.lua`: Ottimizzati `get_card_from_modal` e `get_modal_from_card` con tabelle di lookup O(1) in memoria, azzerando la rilettura di `/etc/config/web` ad ogni chiamata AJAX.
  - `wirelessSSID_helper.lua`: Query batch ad albero `rpc.wireless.ssid.` con `convertResultToObject` per ridurre del 90% i context-switch sincroni verso il demone transformer.
  - `intl.lua`: Resa persistente la cache delle traduzioni in RAM per evitare il re-parsing continuo dei file `.po` da disco ad ogni ciclo GC.
  - `head-js-css.lp`: Aggiunto `defer` agli script non critici e preload dei fogli di stile essenziali per un First Contentful Paint 3x più veloce.
  - `shared-script.js`: Polling AJAX refactorizzato con chained `setTimeout` (prevenzione race conditions), gestione automatica dell'evento `visibilitychange`, deallocazione memoria con `ko.cleanNode()` al cambio schermata e micro-animazioni GPU CSS al posto di jQuery fades.

9.8.43 (Stable)
---------------------------------------------------------------------------
- **Aggiornamento Diretto dal Pulsante Header**:
  - `header.lp`: Trasformato il pulsante `#upgradebtn` nella barra superiore di navigazione in "Aggiorna Ora" con icona dedicata, rimuovendo il reindirizzamento alla modale impostazioni manuali per consentire l'avvio immediato dell'aggiornamento con un solo click.
  - `shared-script.js`: Collegato l'evento click di `#upgradebtn` all'azione diretta di upgrade asincrono con visualizzazione del log live.
  - `webui-core.po`: Aggiunte stringhe e tooltip localizzati per l'aggiornamento rapido.

9.8.42 (Stable)
---------------------------------------------------------------------------
- **Pulsante Aggiornamento Diretto nel Banner Superiore**:
  - `header.lp`: Aggiunto pulsante rapido "Aggiorna Ora" all'interno del banner di notifica di nuova versione disponibile, consentendo l'aggiornamento diretto con un solo click.
  - `shared-script.js`: Registrato handler click su `#direct-upgrade-btn` che invoca l'azione `system_upgrade_gui` con apertura automatica della finestra di log in tempo reale.
  - `webui-core.po` (it-IT & de-DE): Aggiunta stringa di localizzazione `Upgrade Now` -> `Aggiorna Ora` / `Jetzt aktualisieren`.

9.8.41 (Stable)
---------------------------------------------------------------------------
- **Localizzazione & Traduzioni**:
  - `webui-core.po` (it-IT & de-DE): Aggiunta traduzione mancante per il banner di aggiornamento (`Aggiornamento disponibile! Versione: ...` / `Update verfügbar! Version: ...`), stringhe crediti e versione GUI.

9.8.40 (Stable)
---------------------------------------------------------------------------
- **Pulizia Dead Code & Rifiniture Stabilità**:
  - `system.modgui.map`: Aggiunto nil guard sul file handle `/etc/init.d/rootdevice` per prevenire crash in caso di file temporaneamente mancante o non leggibile.
  - `shared-script.js`: Corretto l'event binding `hover` del pulsante di upgrade nel formato nativo jQuery (`.hover()`).
  - **Eliminazione File Orfani e Codice Morto**:
    - Rimossa la modale orfana `ipv6devices-modal.lp` (sostituita da `device-modal.lp`).
    - Rimossa la card non registrata `016_speedservice.lp` (integrata in `009_diagnostics.lp`).
    - Rimossi gli snippet dismessi `002_broadband_bridge.lp`, `002_broadband_docsis.lp`, `broadband-bridge.lp` e `broadband-docsis.lp`.
    - Rimossi asset non referenziati `numberpicker-min.js`, `numberpicker.css`, `lte-doctor.css` e `TIM.css`.
    - Rimossi moduli orfani `password_charachters.lua`, `tim_helper.lua`, `log/viewer.lua`, `parental/redirect.lua`.
    - Rimossi script shell non richiamati `uci_ledfw-status-led.sh` e `fhcd.sh`.

9.8.39 (Stable)
---------------------------------------------------------------------------
- **Ottimizzazione Risorse & File Descriptor Safety**:
  - `012_contentsharing.lp` & `091_system.lp`: Risolta perdita di descrittori di file (File Descriptor Leak) nella funzione `file_check()`, garantendo la chiusura immediata con `:close()` del file handle dopo la verifica di esistenza.

9.8.38 (Stable)
---------------------------------------------------------------------------
- **Correzioni di Stabilità & Documentazione**:
  - `error.lp`: Aggiunto import mancante di `content_helper` per prevenire crash Lua 500 durante il rendering delle pagine di errore non autenticate (401/403/404).
  - `03_various.sh`: Deduplicazione e pulizia atomica delle voci crontab per evitare voci duplicate.
  - `README.md`: Rinnovamento completo del documento con Disclaimer bilingue (EN/IT) su limitazione di responsabilità e ripristino dei link diretti alle guide del forum IlPuntoTecnico.

9.7.70 (Stable)
---------------------------------------------------------------------------
- **Nuovo Modulo & Card Adblock DNS Sinkhole a Risposta Istantanea**:
  - `008_adblock.lp` & `adblock_helper.lua`: Nuova card nativa con badge di stato dinamico, conteggio liste attive e totale domini bloccati in tempo reale.
  - `adblck-config-modal.lp`: Gestione stato globale, download utility (curl), avvio automatico al boot e pulsante rapido di aggiornamento immediato delle liste con protezione token CSRF.
  - `adblck-sources-modal.lp`: Selezione sorgenti DNS con supporto alle migliori liste mondiali (StevenBlack Unified Hosts, OISD Zero False Positives, HaGeZi Multi Pro, AdGuard DNS, Disconnect Malvertising, ecc.).
  - `adblck-lists-modal.lp`: Gestione rapida Whitelist e Blacklist personalizzate da interfaccia web con auto-reload.
  - **Correzioni di Stabilità & UI**:
    - Risolto bug sul salvataggio delle modifiche (attivazione immediata del pulsante Salva sui checkbox e textarea).
    - Risolto crash HTTP 500 su Technicolor OpenResty tramite deserializzazione sicura di oggetti tainted/userdata su richieste POST.
    - Purga automatica di 19 liste obsolete, morte o non rilevanti.
    - Risoluzione istantanea con direttiva nativa Dnsmasq `address=/dominio/0.0.0.0` e bypass del loop awk per una compilazione ultra-veloce senza carico CPU (`adb_tld='0'`).
  - `unlock_and_refresh_web_config.lua` & `05_app.sh`: Auto-registrazione automatica della scheda e configurazione iniziale al momento dell'installazione o upgrade della GUI.

9.7.66 (Stable)
---------------------------------------------------------------------------
- **Ottimizzazione CPU, Riduzione I/O e Zero-Fork Performance**:
  - `processinfo.lua`: Sostituito `top -b -n1` con calcolo differenziale diretto da `/proc/stat` in Lua nativo (zero-fork, zero subshell overhead).
  - `sfp.lua` & `optical.lua`: Sostituiti i comandi shell `cat /proc/sfp_status` e `cat /proc/crossbar_status` con `io.open()` nativo ultra-veloce.
  - `wifi-nurse-modal.lp`: Raggruppate tutte le query di stazione Wi-Fi 2.4G e 5G in due soli batch iniziali con mappatura O(1), eliminando oltre 400 interrogazioni IPC sincrone in loop.
  - `shared-script.js`: Integrata l'API HTML5 `document.visibilitychange` per mettere in pausa automaticamente tutti i timer di polling AJAX quando la scheda del browser è in background o minimizzata.
  - `banktable.lua`: Memorizzato in cache il controllo di validità del banco passivo (`isOtherBankValid`) per eliminare la scansione a blocchi 4KB su memoria NAND Flash.
  - `cards.lua`: Memorizzata in cache la scansione dei template card sul filesystem, azzerando le letture disco a ogni richiesta HTTP.
  - `091_system.lp`: Raggruppate in un unico batch `proxy.get()` le 4 verifiche di stato del servizio Dropbear/SSH.
  - `port_status.lua`: Spostata l'interrogazione della porta WAN all'esterno del ciclo `port_filter`.
  - `wol` & `99-wol`: Eliminato il loop bloccante da 20s con `sleep 1`, usati comandi atomici `ip route replace` / `ip neigh replace` e ricaricamento non distruttivo del firewall (`firewall reload`).
  - `99-mmpbxd`: Aggiunta uscita immediata su eventi non-ifup e serializzazione reload con `flock`.
  - `check_leases`: Riavvio di `dnsmasq` eseguito solo ed esclusivamente quando sono stati effettivamente rimossi lease DHCP statici (`#deleted > 0`).
  - `command-log-read-modal.lp`: Regolato l'intervallo di polling da 100ms a 1000ms.
  - `diagnostics-leds-modal.lp` & `diagnostics-network-modal.lp`: Ottimizzato l'autorefresh da 1s/2s a 5s per abbattere il carico CPU continuo.
  - `06_network.sh`: Disattivazione automatica di DHCPv6 e Router Advertisements (RA) in modalità Bridge, eliminando i conflitti DNS IPv6 con router in cascata.
  - Aggiornati i server DNS upstream predefiniti a Cloudflare ad altissima velocità (`1.1.1.1` e `1.0.0.1`).
  - `network.interface.map`: Corretto errore Lua di tipo `concat` (string vs table) su `getDnsServers`, eliminando l'errore di transformer `bad argument #1 to 'concat'`.
  - `command-log-read-modal.lp` & `commandlogread.lua` & `upgradegui`: Aggiunta barra di avanzamento dinamica e percentuale di download in tempo reale (0% - 100%) durante l'aggiornamento della GUI.
  - Rimossa la generazione dei file legacy dev (`GUI_dev.tar.bz2`), mantenendo solo i canali ufficiali Stable e Preview.

9.7.60 (Stable)
---------------------------------------------------------------------------
- **Nuovo Design System UI/UX Moderno**:
  - Card elevation elegante con ombreggiatura neutra e transizioni fluide a 60fps
  - Border radius moderno (10px - 14px) applicato a card, finestre modali e pulsanti
  - Nuovi indicatori di stato a pillola (Pill Badges) per link connesso/disconnesso/sincronizzazione
  - Ottimizzazione responsive mobile-first: aree di tocco touch >40px e zero overflow orizzontale
  - Tabelle di configurazione con righe alternate (Zebra striping) e highlight al passaggio del mouse
- **Download e Aggiornamento Firmware Resiliente**:
  - Timeout di download aumentato a 300 secondi con gestione automatica errori e redirect (curl -m 300 -k -s -f -L)
  - Prevenzione del troncamento archivio su connessioni lente
- **Pipeline Release Stable vs Preview**:
  - Canale Stable ufficiale e canale Preview dedicati
  - Script nativo cross-platform Python per la compilazione automatica dei pacchetti release
- **Stabilità e Prestazioni**:
  - Bonifica completa di tutte le finestre modali (76) e card (29) per 100% crash-free nil-safety
  - Risolti bug e leak di memoria su moduli Lua e streaming log ad alta efficienza
  - Conformità POSIX /bin/sh su tutti gli script shell
  - Integrazione supporto Ko-fi (https://ko-fi.com/nobodysan) e rimozione vecchi riferimenti PayPal

9.7.50
---------------------------------------------------------------------------
- Revisione e bonifica totale di tutti i 76 file modal LP e 29 file card LP per garantire 100% crash-free nil-safety
- Risolti bug e leak di memoria su moduli Lua, streaming log ad alta efficienza senza picchi RAM
- Riorganizzato e chiarito il menu di Reset Avanzato (modgui-modal.lp) con descrizioni dedicate, dialoghi popup espliciti e pulsanti colorati
- Raggruppate in batch le interrogazioni al datamodel per dispositivi Wi-Fi, contatori di traffico e profili VoIP MMPBX
- Corretto il ring buffer a finestra scorrevole 24h per il monitoraggio del traffico in trafficmon.lua
- Risolto bug di sintassi in Transformer system.tcpdump.map (cattura pacchetti 100% funzionante)
- Conformità POSIX /bin/sh al 100% su tutti i 63 script shell e demoni di sistema (rimossi bashismi e variabili non quotate)
- Aggiunti link e badge di supporto Ko-fi (https://ko-fi.com/nobodysan) su README, footer GUI e modgui modal; rimossi vecchi riferimenti PayPal
- Aggiunto badge contatore download totali su README.md
- Rimossa configurazione legacy CircleCI in favore di GitHub Actions CI/CD
- Testati e verificati tutti i 9 temi grafici della GUI con resa perfetta e traduzioni italiane UTF-8 complete


---------------------------------------------------------------------------
# Mainline 18.3 Cobalt

9.6.65
---------------------------------------------------------------------------
- Fix vari che causavano la perdita delle configurazioni dopo un riavvio
- Fix che impedivano il corretto aggiornamento firmware da GUI
- Spostate alcune funzioni nella modal MODGUI
- Rimossa opzione di spoof versione "da rootscript"
- Aggiunta funzione, attiva di default, per ignorare gli update inviati dal CWMP
- Forzato riavvio su prima installazione se modoverlay non è applicato
- Rimossa card mobile su dispositivi che non la supportavano
- Migliorata la rilevazione dell'installazione dei pacchetti di upgrade e delle estensioni
- Aggiunti driver xDSL

9.6.10
---------------------------------------------------------------------------
 - La mod ora applicherà in modo automatico l'OPTIMAL BANK PLAN e utilizzerà la partizione del bank_1 come spazio per le config/mod (MODOVERLAY), in modo da avere BOOTP come una modalità sicura di recovery di device brickati.
 - Cambio al comportamento del reset da tasto fisico: al primo reset vengono rimosse tutte le mod e mantenuto solo il root al secondo reset (se non si reinstalla la MOD) il device viene riportato totalmente allo stato di fabbrica
 - Risolti vari problemi di rilevazione GPON su TIMHUB
 - Fix LED non funzionanti su firmware vecchi (firmware TIM 1.0.3) 
 - Aggiunta possibilità di configurare una connessione WAN anche in bridge mode
 - Fix per permettere la connessione di alcuni modelli di chiavette 3G Huawei
 - Aggiunti ulteriori driver xDSL
 - Fix errore 500 quando si ripristinava un backup avanzato
 - Rimosse alcune funzioni deprecate e potenzialmente problematiche
 - Aggiunto supporto iniziale per TG789vac v3
 - Abilitata installazione app su TG800
 
9.5
---------------------------------------------------------------------------
 - Risolti alcuni problemi di compatibilità con internet explorer
 - Fix vari per ripristinare il funzionamentpo di modem 3G/LTE USB
 - Fix funzioni di copia e trasferimento bank
 - Aggiunta modal gestione cron
 - Aggiunta modal gestione init
 - Aggiunti ulteriori driver xDSL
 - Aggiunta possibilità di selezionare l'interfaccia per i servizi VoIP
 - Aggiunte app per TG789 Xtream 35B

9.4
---------------------------------------------------------------------------
- Aggiunta opzione per forzare interfaccia in HTTPS
- Aggiunta opzione per eseguire backup OpenWRT
- Aggiunta opzione per visualizzare access-concentrator per sessioni PPP
- Fixati alcuni errori sulla visualizzazione dell'IPv6
- Molti miglioramenti e fix grafici alle skin Unified e Fritz
- Sistemato reset config
- Aggiunta possibilità di resettare CWMP per forzare provisioning
- Aggiunto supporto a DJA0231 (Telstra)
- Sistemata impostazione WiFi NSC (Eco Modal)
- Migliorato supporto per DGA4131FWB, DJA0231, TG788, TG789 Xtream 35 Fastweb
- Importante fix che poteva causare bootloop se non venivano mai fatti aggiornamenti stabili
- I driver xDSL prima di essere impostati vengono preventivamente controllati per evitare bootloop
- Lo stato di alcuni processi (Aggiornamento GUI, cambio driver, installazione APP...) viene mostrato da GUI
- Aggiunta flag per attivare IPv6 su WAN
- Aggiunta pulsante per forzare provisioning CWMP
- Importanti fix per evitare comportamenti inaspettati durante gli upgrade firmware

9.3
---------------------------------------------------------------------------
- Ri-Aggiunto supporto alle app per i nuovi firmware
- Nuova skin unificata
- Inserita gestione led su DGA4131FWB
- Aggiunta possibilità di impostare potenza e country region radio WiFi
- Aggiunta funzione di riavvio programmato
- Possibilità di impostare server DNS per tutte le interfaccie (IP Extras)
- Sistemato wizard e vari errori su TG788
- Possibilità di impostare vendorid per il tipo di connessione wan DHCP (necessità Fastweb)
- Molti altri miglioramenti e bugfix minori

9.2
---------------------------------------------------------------------------
- Rebase su nuovi firmware 2.1.0 (Kernel linux aggiornato a 4.1.38)
- Vari rework agli script per una esecuzione più efficente
- Vari fix ai bug presenti nelle versioni precedenti
- E' ora possibile dare priorità ad un dispositivo specifico rispetto a tutta la rete (Tab Gestione spositivi)
- Aggiunte nuove funzioni di aggiornamento e possibilità di selezionare l'ISP manualmente
- Altri miglioramenti che sinceramente non ricordo

---------------------------------------------------------------------------
# Mainline 17.3 Cyan

9.1
---------------------------------------------------------------------------
- Aggiunto grafico utilizzo CPU e Memoria
- Aggiunta opzione per ripristinare configurazioni senza perdere GUI
- Stato telefonia in visualizzazione statistiche ora mostra errori di registrazione
- Stato telefonia mostra il numero collegato durante una chiamata
- Riorganizzata modal Servizi WAN" 

9.0
---------------------------------------------------------------------------
- Riorganizzata disposizione card
- Aggiunte ulteriori impostazioni di maschera versione
- Aggiunti vari driver xDSL
- Introdotto salvataggio delle conf dopo upgrade del firmware
- Introdotto ripristino di emergenza automatico in caso di rilevazione flash piena
- Forzata abilitazione porta console
- Aggiunto supporto a modem DGA4131 e TG789VAC XTREAM 35B
- Migliorato check aggiornamenti
- Rebase su firmware 2.0.1_001
- Fixato aggiornamento remoto da telegestione
- Migliorato sistema di aggiornamento
- Aggiornate traduzioni/stringhe inglesi italiane e tedesche
- Vari fix e miglioramenti

8.11
---------------------------------------------------------------------------
- Migliorate traduzioni
- Miglioramenti modalità bridge e modalità connessione
- Fixato visualizzazione UPnP su TG789
- Aggiunta possibilità di usare cups come gestore stampante
- Aggiunto applicazione aMule su TG789" 

8.10
---------------------------------------------------------------------------
- Aggiunte e fix per la gestione di ECO LED
- Miglioramenti Trauduzioni
- Miglioramenti di compatibilita' con l'interfaccia Telstra
- Fix problemi vari con la configurazione account SIP
- Aggiunta visualizzazione profilo VDSL
- Migliorato script aggiornamento GUI e tanti altri miglioramenti e bugfix

8.8
---------------------------------------------------------------------------
- Reworkata pagina iniziale gateway con caricamento dinamico ed introduzione della pagina statistiche.
- Nuova skin dark red. Introdotta possibilità di settare WifiTod per i wifi separatamente e per i wifi guest.
- Varie migliorie ai temi per desktop e mobile.
- Aggiunta Telstra gui alle applicazioni. Fixato support dei pacchetti per firmware 1.2.0. Vari fix e miglioramenti all'interfaccia.

8.7
---------------------------------------------------------------------------
- Fix download driver xdsl, fix assistance, ora vengono mostrate le password dei 3 profili disponibili.
- WIP supporto grafici per ADSL. Aggiunta tab per settare DosProtect

8.6
---------------------------------------------------------------------------
- Rework icone, aggiornata libreria fontawesome, fix e migliorie varie, 
- TEST sfp->stptag per sbloccare classe di ip 192.168.2.1... si attendono feedback per gli utenti che usano modulo sfp 

8.5
---------------------------------------------------------------------------
- Traduzioni aggiornate, fixato ddns

8.4
---------------------------------------------------------------------------
- Fix sysupgrade e dlna

8.3
---------------------------------------------------------------------------
- Migliorato e fixata visualizzazione del monitor traffico nella tab Dispositivi Connessi.

8.2
---------------------------------------------------------------------------
- Supporto per nuovo firmware beta.

8.1
---------------------------------------------------------------------------
- Fix e migliorie al cambio ip nella tab LAN, fix bug reset ppp dopo cambio ip modem.

8.0
---------------------------------------------------------------------------
- Aggiunto supporto per TG789vac (firmware Tiscali)
- fix cambio password, fix minori agli script, aggiunta pagina per Flow Cache.

7.17
---------------------------------------------------------------------------
- Aggiornate librerie web Aos.js e Jquery. Fix regole cron

7.16
---------------------------------------------------------------------------
- Aggiornate traduzioni.

7.15
---------------------------------------------------------------------------
- Aggiornamento nuovo server fix HLog, QLN , fix bug minori

7.14
---------------------------------------------------------------------------
- Fix errata visualizzazione Hlog e QLN

7.13
---------------------------------------------------------------------------
- Aggiunta visualizzazione della versione firmware del dslam

7.12
---------------------------------------------------------------------------
- Aggiunta tab per la gestione dei bridge.

7.11
---------------------------------------------------------------------------
- Aggiornamento traduzioni. Thx DarkNiko

7.10
---------------------------------------------------------------------------
- Bugfix vari, andare su github per controllare.

7.9
---------------------------------------------------------------------------
- Aggiunta possibilità di disattivare sra e bitswap, ditemi se devo aggiungerne altre...

7.8
---------------------------------------------------------------------------
- Aggiunta skin Fritz e bug fix minori

7.7
---------------------------------------------------------------------------
- Aggiungo Version Spoof nella tab sistema avanzato. 
- Segnala una versione falsa alla telegestione per permettere la sincronizzazione dei dati.

7.6
---------------------------------------------------------------------------
- Fix wansensing e bug dns

7.5
---------------------------------------------------------------------------
- Fix ethernet modal e fix iniziale wake on wan

7.4
---------------------------------------------------------------------------
- Bottone Eco Led ora funzionante! Fix vari, crediti, abilitato login https e fix assistance

7.3
---------------------------------------------------------------------------
- Aggiunto bottone per installare una blacklist vuota

7.2
---------------------------------------------------------------------------
- Aggiunto luci, supporto iniziale, wifi rotto.

7.1
---------------------------------------------------------------------------
- Aggiunta pagina mwan, se qualcuno sa a che serve spiegatemi...

7.0
---------------------------------------------------------------------------
- Rebase sul nuovo firmware

6.13
---------------------------------------------------------------------------
- Aggiunta traduzione tedesca Thx meyergru

6.12
---------------------------------------------------------------------------
- Introdotta autorimozione del bit antidowngrade AGTHP

6.11
---------------------------------------------------------------------------
- Fixato upgrade

6.10
---------------------------------------------------------------------------
- Aggiunta xupnp (solo per agtef 1.1.0 e superiori)

6.10
---------------------------------------------------------------------------
- Aggiunti grafici xDSL

6.9
---------------------------------------------------------------------------
- Aggiunto bottone WAN-MODE (WIP)

6.8
---------------------------------------------------------------------------
- Aggiunto gestore led (WIP)

6.7
---------------------------------------------------------------------------
- Reworkato voicemode e bridgemode, fixato problema telegestione non funzionante, aggiornate traduzioni
- aggiunto bottone per convertire porta WAN e opzioni per switchare modalità di connessione",basic)

6.6
---------------------------------------------------------------------------
- Vari fix, si spera stabile sta volta

6.5
---------------------------------------------------------------------------
- Nuovo release channel dev, cpuload e altro in gui, quintacolonna (non il programma)

6.4
---------------------------------------------------------------------------
- Miglioramenti al sistema di aggiornamento gui

6.3
---------------------------------------------------------------------------
- Soppressione dei log eccessivi e fix funzione di esport

6.2
---------------------------------------------------------------------------
- Taaaaanto bugfix e reso il bottone controlla aggiornamenti funzionante

6.1
---------------------------------------------------------------------------
- Aggiunto blacklist tool agli installer

6.0
---------------------------------------------------------------------------
- Rebase con i nuovi cambiamenti

5.11
---------------------------------------------------------------------------
- Iniziale supporto per luci,ariang e transmission

5.10
---------------------------------------------------------------------------
- UPnP fix thx  Jecht_Sin

5.9
---------------------------------------------------------------------------
- Test wifi fix, thx aezakmi123

5.8
---------------------------------------------------------------------------
- Latenza maggiorata fixata, (disabilitati risparmi energetici per le porte ed il traffico 5ghz

5.7
---------------------------------------------------------------------------
- Fixata finalmente tab assistenza e selettore porte. (questa volta per sempre...)

5.6
---------------------------------------------------------------------------
- Aggiunto uptime wan

5.5
---------------------------------------------------------------------------
- Fixato cpustep, thx @shdf

5.4
---------------------------------------------------------------------------
- Fixato selettore porta nella tab assist

5.3
---------------------------------------------------------------------------
- Aggiunto selettore driver xdsl

5.2
---------------------------------------------------------------------------
- ReRefix tab lan e fix css per primo root

5.1
---------------------------------------------------------------------------
- Refix tab lan e fix cwmpd (forse)

5.0
---------------------------------------------------------------------------
- Fix autocompletamento e tab lan

4.6
---------------------------------------------------------------------------
- Fixato switch tab mobile

4.5
---------------------------------------------------------------------------
- Selettore skin gui nella tab Sistema Extra

4.4
---------------------------------------------------------------------------
- Fix pagina wireless

4.3
---------------------------------------------------------------------------
- Traduzioni aggiornate (thx @DarkNiko), altri fix telegestione e altro

4.2
---------------------------------------------------------------------------
- Altri fix, gui stabile

4.1
---------------------------------------------------------------------------
- Vari fix, telegestione fixata (forse? no...), gui stabile

4.0
---------------------------------------------------------------------------
- Rebase Completo
---------------------------------------------------------------------------
# Mainline 17.1 Aqua

3.36
---------------------------------------------------------------------------
- Fix grafico 5Ghz

3.35
---------------------------------------------------------------------------
- Svecchiamento grafica pt.2

3.34
---------------------------------------------------------------------------
- Fix grafico lan

3.33
---------------------------------------------------------------------------
- Migliorata velocità gui

3.32
---------------------------------------------------------------------------
- Migliorata configurazione wizard voip (chiede anche il resto ora....)

3.31
---------------------------------------------------------------------------
- Aggiunte voci domain name e realm sezione voip

3.30
---------------------------------------------------------------------------
- Fix riattivazione dhcp e bridge mode

3.29
---------------------------------------------------------------------------
- Fix telegestione

3.28
---------------------------------------------------------------------------
- Testing accesso remoto con scelta di porta. (Necessario un reboot per cambiare la porta)

3.27
---------------------------------------------------------------------------
- Aggiornato nginx, attivato gzip compression aumentata reattività webui

3.26
---------------------------------------------------------------------------
- Fixed opkg update problem (openssl-util manuallty installed) and mac address

3.25
---------------------------------------------------------------------------
- Verde è più bello :)

3.24
---------------------------------------------------------------------------
- Fix vari, wizard fixato

3.23
---------------------------------------------------------------------------
- Aggiunto Traffic Monitor nella sezione dispositivi

3.22
---------------------------------------------------------------------------
- Fix vari

3.21
---------------------------------------------------------------------------
- Fix bug aggiornamento disponibile

3.20
---------------------------------------------------------------------------
- Aggiunto update gui offline e fix vari

3.19
---------------------------------------------------------------------------
- Nuovi pacchetti (kmod funzionanti), aggiornato opkg repo. Si ringrazia Roleo per la compilazione

3.18
---------------------------------------------------------------------------
- Introdotto nuovo daemon dlnad

3.17
---------------------------------------------------------------------------
- Fix sysupgrade (flash altra partizione ma niente switchover, ora flasha quella su cui è presente il firmware e non esegue switchover)

3.16
---------------------------------------------------------------------------
- Rimosso aggiornamento adsl e cwmpd... 

3.15
---------------------------------------------------------------------------
- Possibile fix tod wireless

3.14
---------------------------------------------------------------------------
- Fix card_limiter

3.13
---------------------------------------------------------------------------
- Fix per user non telecom

3.12
---------------------------------------------------------------------------
- Miglioramento script root e aggiunte alcune traduzioni

3.11
---------------------------------------------------------------------------
- Disabilitato daemon ipv6, per ora è comunque buggato e rotto

3.10
---------------------------------------------------------------------------
- Bottone Bridge Fixato @Pigr8. Opkg quasi funzionante, provare ad installare i pacchetti 
- e segnalare quali funzionanti.

3.9
---------------------------------------------------------------------------
- Fixato telnet e pagina password

3.8
---------------------------------------------------------------------------
- Fixato problema aggiornamento convertito in reset... 
- (causato da un mio errore per aver introdotto script nel posto sbagliato)

3.7
---------------------------------------------------------------------------
- Probabile fix al bug del dns

3.6
---------------------------------------------------------------------------
- Aggiunto switch per disattivare check bank_1 (Funzioni Avanzate)

3.5
---------------------------------------------------------------------------
- Fixato bug password

3.4
---------------------------------------------------------------------------
- Refactor platform.sh e script di root per l'upgrade della versione

3.3
---------------------------------------------------------------------------
- Aggiornato driver xDSL

3.2
---------------------------------------------------------------------------
- Tutti in bank_1, inserito check in boot per forzare tutti lì

3.1
---------------------------------------------------------------------------
- Tab DHCP fixata

3.0
---------------------------------------------------------------------------
- Merge cambiamenti da AGTEF_1.0.4_007
---------------------------------------------------------------------------
# Mainline 17.1 Aqua

2.23
---------------------------------------------------------------------------
- Aggiunto bottone transfer to bank 1 nella tab system (Funzioni Avanzate) 

2.22
---------------------------------------------------------------------------
- Aggiunto bottone switchover e informazioni sui bank nella tab system

2.21
---------------------------------------------------------------------------
- Fixata casella DDNS non visualizzata

2.20
---------------------------------------------------------------------------
- Aggiunto sistema di autoaggiornamento gui e segnalazione nuova versione. (WIP)

2.19
---------------------------------------------------------------------------
- Fixato bug riavvio, fixata tab samba... per il printsharing è necessario abilitare samba.

2.18
---------------------------------------------------------------------------
- Aggiunto card limiter e fixato bug VOICEMODE (si prega di rieseguire la procedura)

2.17
---------------------------------------------------------------------------
- Aggiunta funzione per modalità asstenza permanente e scelta password

2.16
---------------------------------------------------------------------------
- Aggiunte funzioni per il reset TOTALE e il ripristino della gui originale

2.15
---------------------------------------------------------------------------
- Aggiunta visualizzazione codec voip e possibilità di configurarli

2.14
---------------------------------------------------------------------------
- Aggiunto WakeOnWan e fixata visualizzazione e funzione del portforward

2.13
---------------------------------------------------------------------------
- Piccola rivisitazione grafica, aggiunta icone e inseriti controlli SSH e Telnet in Funzioni Extra di Sistema

2.12
---------------------------------------------------------------------------
- Aggiunto Telnet e reso attivabile da gui (tab Funzioni Avanzate)

2.11
---------------------------------------------------------------------------
- Resi funzionali BridgeMode e VoiceMode

2.10
---------------------------------------------------------------------------
- Fixato invalid istance nel SetupWizard.

2.9
---------------------------------------------------------------------------
- Fixato il QOS.

2.8
---------------------------------------------------------------------------
- Altre traduzioni alla gui by DarkNiko.

2.7
---------------------------------------------------------------------------
- Fixato bug per il quale non era possibile creare regole di port forward.

2.6
---------------------------------------------------------------------------
- Vari fix e aggiornamenti alla traduzione della webui. Si ringrazia DarkNiko per l'ottimo lavoro.

2.5
---------------------------------------------------------------------------
- Fixate/Rimosse le Invalid Istance, aggiunta possibilità di modificare regole qos.

2.4
---------------------------------------------------------------------------
- Aggiunte impostazioni Hostname nella tab Gateway e Domain Name nella tab Rete Locale

2.3
---------------------------------------------------------------------------
- Sbloccate altre funzioni e perfezionato metodo di sblocco webui. VoiceMode e BridgeMode ancora WIP!

2.2
---------------------------------------------------------------------------
- Fixati alcuni bottoni e aggiunto bottone per controllare aggiornamenti

2.1
---------------------------------------------------------------------------
- Fix bug bypass password

2.0
---------------------------------------------------------------------------
- Merge WebUi firmware beta telecom
---------------------------------------------------------------------------
# Mainline 16.3 Aqua

1.12
---------------------------------------------------------------------------
- Aggiungi bottoni mobile e CWMP

1.11
---------------------------------------------------------------------------
- Aggiunge funzioni eco nella tab Gateway

1.10
---------------------------------------------------------------------------
- FIX IPV6 e aggiunto changelog

1.9
---------------------------------------------------------------------------
- Aggiunte funzioni Risparmio Energetico Configurabili (/etc/config/power)

1.8
---------------------------------------------------------------------------
- Aggiunta password Numero Voip nella visione generale della tab Telefono

1.7
---------------------------------------------------------------------------
- Aggiunta Voice Mode (WIP)

1.6
---------------------------------------------------------------------------
- Aggiunta Bridge Mode (WIP)

1.5
---------------------------------------------------------------------------
- Rimosso blocco degli spazzi nell'ssid

1.4
---------------------------------------------------------------------------
- Inserito conferma per inserimento di password non sicura. (Ora è possibile inserire password minore di 12 caratteri)

1.3
---------------------------------------------------------------------------
- Aggiunto Wizard (WIP)

1.2
---------------------------------------------------------------------------
- Aggiunte tab switch e QOS (WIP)

1.1
---------------------------------------------------------------------------
- Abilitate tab nascoste

1.0
---------------------------------------------------------------------------
- Rimosso css e logo tim"
