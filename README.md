# SQLite CLI Frontend

Allows the user to:

- define a data-schema
- along with "computed columns"
- and "interesting aggregations" (or charts)

in a (relatively) simple TOML config, in order to get:

- an auto-generated binary application
- that's portable to any* OS
- and facilitates:
    - manual data CRUD
    - queries/views
    - auto-backup
    - and data-schema version migration (though this one may require more work on the user's part)

The interface (to the built application) on the CLI should look like:

```
$ myprogram subcommand param1 param2 ...
OK
$
```

OR like (and this is the more interesting thing, for hand-holding and actual UI that's not programmery)

```
$ myprogram
[switch to alt fullscreen buffer like vim does]

$ myprogram X_____
         1. subcommand1
         2. subcommand2
         3. subcommand3
```

where the ui hand-holds you through building a valid command by showing/filtering menu options, and giving you a form to fill where appropriate, but always showing the "programmer-y" full command equivalent at the top of the screen
