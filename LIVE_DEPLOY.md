# Live Deploy

Current deployment details for https://perl5.test-smoke.org/ are as follows, this project is
currently hosted by the MetaCPAN team.

## Contacts:

- irc.perl.org - #smoke and #metacpan channels

## K8s setup

- [K8s setup](https://github.com/metacpan/metacpan-k8s/tree/main/apps/test-smoke)
  - [Container deployments](https://github.com/metacpan/metacpan-k8s/blob/main/apps/test-smoke/base/deployment.yaml), one for `API` and one for `web` front end.
    - Github actions build the containers from the relevant web/api repo
  - [Ingress setup](https://github.com/metacpan/metacpan-k8s/blob/main/apps/test-smoke/environments/prod/ingress.yaml) notes:
    - Special `proxy-body-size: 8m` rule to allow up to 8mg report payloads, otherwise nginx returns a 413 (Content too large)
    - `/api/` url used to send to API service/deployment

## Important Notes:

### SQL:

- DB name: coresmokedb
- DB user: coresmokedb
- Schema: public

Deploy a fresh DB from either the backup
or [coresmokedb.sql](https://github.com/metacpan/Perl5-CoreSmokeDB/blob/main/coresmokedb.sql) - you should make sure to use the latter to create the indexes

### Old API /reports vs new api /api/reports

Most users are on versions of [Test::Smoke](https://metacpan.org/pod/Test::Smoke)
less than 1.81 (released 2023-10-27) with no way to contact them. This means they 
use the old `/report` URL and not `/api/report`.

This was a problem because the way we direct traffic to the API
container in k8s is by looking for `/api` in the url path. This is solved by using Fastly CDN and the following VCL snippet:

```vcl
# Backwards compatability with old clients
if (req.url.path ~ "^/report" && req.method == "POST") {
  set req.url = regsub(req.url, "^/report", "/api/old_format_reports");
}
```

If this service is deployed in any other way this issue will have to be resolved differently. 

### Database Backups

- The MetaCPAN team takes nightly database backups and saves to https://backblaze.com - storing the last 5 days before rotating.

### Logs

- Fastly (CDN) logs are streamed to [Honeycomb](https://ui.honeycomb.io/metacpan/environments/testsmoke/datasets/testsmokelivedata/overview) which the MetaCPAN team has access to. NOTE: we can see which version of `Test::Smoke` is submitting each request, and indeed it's logged in the DB as well.
