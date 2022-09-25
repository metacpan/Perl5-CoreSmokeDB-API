# NAME

Perl5::CoreSmokeDB - API server for the VueJS frontend

# INSTALLING

Basic installation for try-out:

```bash
git clone https://github.com/abeltje/Perl5-CoreSmokeDB-API.git
cd Perl5-CoreSmokeDB-API
carton install
carton exec -- local/bin/plackup -S Starman bin/app.psgi -E try-out --port 5050
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
