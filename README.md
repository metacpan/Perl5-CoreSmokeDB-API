# NAME

Perl5::CoreSmokeDB - API server for the VueJS frontend
[Perl5-CoreSmokeDB-Web](https://github.com/abeltje/Perl5-CoreSmokeDB-Web#name)

# DESCRIPTION

This software is the backend for the Single Page Application frontend written
in VueJS 3.

# INSTALLING

Basic installation for try-out:

```bash
git clone https://github.com/abeltje/Perl5-CoreSmokeDB-API.git
cd Perl5-CoreSmokeDB-API
carton install
carton exec -- local/bin/plackup -s Starman bin/app.psgi -E try-out --port 5050
```

On a clean Ubuntu 22.04 install you will also need these packages before you
start: `build-essential` `cpanminus` `carton` `sqlite3` `libpq-dev`
`libxml2-dev` `libexpat1-dev` `jq`

# THE API

The api supports 2 protocols: REST and JSONRPC. This document shows some
examples of both, The complete interface is to be found in the
`lib/Perl5/CoresSmokeDB/API/` directory.

## Example: server status

```bash
curl -s -XGET http://localhost:5050/system/status | jq
```

## Example: application versions

```bash
curl -s -XGET http://localhost:5050/api/version | jq
```
or with JSONRPC:
```bash
curl -s -XPOST -H'Content-type: application/json' http://localhost:5050/api \
  -d'{"jsonrpc":"2.0", "id":"request42", "method":"version"}' | jq
```

## Example: the latest report for each host

```bash
curl -s -XGET http://localhost:5050/api/latest | jq -C | less -R
```

## Example: search results

```bash
curl -s -XGET 'http://localhost:5050/api/searchresults?selected_arch=amd64&selected_osnm=MSWin32' \
  | jq -C | less -R
  ```
  or with JSONRPC:
  ```bash
  curl -s -XPOST -H'Content-type: application/json' http://localhost:5050/api \
    -d'{"jsonrpc":"2.0", "id":"request42", "method":"searchresults", "params":
    {"selected_arch":"amd64","selected_osnm":"MSWin32"}}' | jq -C | less -R
```

## Example: post report (from existing json)

If one is running the
[Test::Smoke](https://metacpan.org/pod/Test::Smoke)-suite, one will have an
archive of `jsn<git-sha>.jsn` files that can be used to post to the database.
For this example I'll call the json-file `mktest.jsn`.
```bash
curl -s -XPOST -H'Content-type: application/json' http://localhost:5050/api/report \
  -d"{"\""report_data"\"":$(cat mktest.json)}" | jq
```

## Example: get the OpenAPI/Swagger YAML

```bash
curl -s -XGET http://localhost:5050/api/openapi/web | less
```

# DATABASE

## Deploy the database schema

For the try-out, we use a SQLite database, but the software also supports
PostgreSQL, just set the `dsn` and user information in this perl statement:

```bash
carton exec -- perl -MPerl5::CoreSmokeDB::Schema -wE \
    'my $s = Perl5::CoreSmokeDB::Schema->connect(
      "dbi:Pg:dbname=coresmokedb;host=dbserver","coresmokedb","Secret++",{ignore_version => 1}
    );
    $s->deploy'
```

## Change the `environments/try-out.yml` configuration

Change the `plugins.DBIC` section:
```yaml
plugins:
  DBIC:
    # keep the try_out section
    postgresql: &pg
      schema_class: Perl5::CoreSmokeDB::Schema
      dsn: 'dbi:Pg:dbname=coresmokedb;host=dbserver'
      user: coresmokedb
      password: Secret++
      options:
        RaiseError: 1
        PrintError: 1
    default: *pg
```

# COPYRIGHT

&copy; MMXXII - Abe Timmerman <abeltje@cpan.org>

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

