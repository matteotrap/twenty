# Twenty CRM su Fly.io

Installazione di **Twenty v2.57.1** per un solo utente, pubblicata come `twenty-trap` nell'organizzazione Fly.io Trapstudio (`personal`).

## Risorse

| Risorsa | Nome | Configurazione |
| --- | --- | --- |
| App | `twenty-trap` | Regione `fra`, processi `server` e `worker`, una VM `shared-cpu-1x` da 1 GB ciascuno |
| PostgreSQL | `twenty-trap-db` | PostgreSQL 18.1, una VM `shared-cpu-1x` da 512 MB, volume crittografato da 3 GB |
| Redis | `twenty-trap-redis` | Upstash pay-as-you-go, regione `fra`, eviction disabilitata, nessuna replica |
| File | `twenty-trap-files` | Bucket Tigris privato, endpoint `https://t3.storage.dev` |
| Backup PostgreSQL | `twenty-trap-db-postgres` | Bucket Tigris, backup completi ogni 24 ore e retention WAL di 7 giorni |

L'URL di destinazione è `https://crm.trapstudio.it`. L'URL tecnico è `https://twenty-trap.fly.dev`.

> PostgreSQL è unmanaged, senza alta disponibilità e senza supporto operativo da parte di Fly.io. I backup sono abilitati, ma restore e aggiornamenti restano responsabilità del proprietario dell'installazione.

## File di configurazione

- `fly.toml`: processi, VM, variabili non sensibili, health check e timeout di deploy.
- `Dockerfile`: fissa la versione dell'immagine Twenty e installa il wrapper di avvio.
- `fly-entrypoint.sh`: avvia il server normalmente; per il processo `worker` disabilita migrazioni e registrazione dei cron prima di chiamare l'entrypoint ufficiale.

I secret sono conservati soltanto in Fly.io: `PG_DATABASE_URL`, `REDIS_URL`, `ENCRYPTION_KEY` e le credenziali Tigris (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`). Non salvarli nel repository.

## Deploy e monitoraggio

```sh
fly config validate --strict
fly deploy --ha=false
fly status --app twenty-trap
fly checks list --app twenty-trap
fly logs --app twenty-trap
```

Con queste VM minime l'avvio a freddo può richiedere più di venti minuti: migrazioni, controlli e registrazione dei cron inizializzano l'applicazione Node più volte. Il timeout è quindi impostato a 45 minuti. L'auto-stop è intenzionalmente disattivato per evitare che la VM venga spenta durante l'inizializzazione.

Non aumentare il numero di macchine: il deploy usa `--ha=false` e la configurazione prevede un solo server e un solo worker. La registrazione dei cron e le migrazioni devono restare esclusive del server.

Per verificare l'applicazione:

```sh
curl --fail https://twenty-trap.fly.dev/healthz
curl --fail https://crm.trapstudio.it/healthz
```

Il secondo comando funziona dopo la configurazione DNS e l'emissione del certificato.

## Dominio

Il certificato Fly per `crm.trapstudio.it` è già registrato. Configurare questi record nel DNS di `trapstudio.it`:

| Tipo | Nome | Valore |
| --- | --- | --- |
| `A` | `crm` | `66.241.124.16` |
| `AAAA` | `crm` | `2a09:8280:1::1f7:bbb4:0` |

In alternativa è disponibile il CNAME `crm` → `r8k61x6.twenty-trap.fly.dev`. Se si usa Cloudflare con proxy attivo, aggiungere anche il record TXT `_fly-ownership` mostrato da `fly certs setup` e usare SSL **Full (Strict)**.

```sh
fly certs setup crm.trapstudio.it --app twenty-trap
fly certs check crm.trapstudio.it --app twenty-trap
```

Al primo accesso registrare immediatamente l'utente amministratore e attivare il 2FA. In modalità single-workspace le nuove registrazioni vengono disabilitate dopo la creazione del primo workspace. SMTP può essere configurato successivamente da **Settings → Admin Panel → Configuration Variables**.

## Backup e aggiornamenti

Controllare o creare un backup PostgreSQL:

```sh
fly postgres backup config show --app twenty-trap-db
fly postgres backup list --app twenty-trap-db
fly postgres backup create --app twenty-trap-db
```

Se `backup create` scade mentre attende la risposta della VM, controllare `backup list` prima di riprovarlo: durante i test il backup è stato avviato e completato comunque.

Prima di ogni aggiornamento:

1. Creare un backup e verificarne il completamento.
2. Consultare la [guida ufficiale agli aggiornamenti](https://docs.twenty.com/developers/self-host/capabilities/upgrade-guide).
3. Sostituire il tag `v2.57.1` nel `Dockerfile` con una release stabile completa, senza usare `latest`.
4. Eseguire `fly deploy --ha=false`.
5. Controllare health check e log; il server esegue automaticamente le migrazioni necessarie.
