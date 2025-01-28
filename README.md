# Operations

## 1. BackUps

### 1.1. BackUp Production Database

You can create a backup of a production database from your local computer.

```
pg_dump -h s01.massprospecting.com -p 5432 -U blackstack -W blackstack > backup.sql
```

### 1.2. Restoring Database in Your Local Environment

Restorning a real-life database in your local environment is good for an effective code and testing:

Before restoring the database into your `mass.slave`, you have to close all existing connections.
So, stop the slave services:

```
cd ~/code1/blackops/cli
ruby stop.rb --node=localslave --root
```

Now, you are good to go:

1. In your local database, delete your existing mass.slave database.

```
psql -U blackstack -d postgres -c 'DROP DATABASE "mass.slave";'
```

2. Create a new and fresh `mass.salve` database owned by the Postgres user `blackstack`:

```
psql -U blackstack -d postgres -c 'CREATE DATABASE "mass.slave" OWNER blackstack;'
```

3. Restore the database `backup.sql`

```
psql -U blackstack -d mass.slave -f ./backup.sql
```

**Note:** For running the command above, you have to edit the file `/etc/postgresql/<version>/main/pg_hba.conf`, and replace the line

```
local   all             all                                     peer
```

by

```
local   all             all                                     md5
```

Then, you have to restart PostgreSQL too.

```
sudo systemctl restart postgresql
```

## 2. Demo Pages Documentation

- Use [this prompt](./gpt-demo-markdown-generation.txt) to generate markdown documentation from an HTML demo.

- Use [this prompt](./gpt-demo-html-generation.txt) to show more features in the demo page.

- Always use `gpt-4o` model.

## 3. Subaccounts and Profiles Re-Allocation

```sql
-- request all submaccounts to be re-allocated
UPDATE subaccount SET allocation_success=null WHERE allocation_success IS NOT NULL;
```

```sql
-- request all profiles to be re-allocated
INSERT INTO allocation (
    id,
    id_account,
    id_user,
    create_time,
    id_profile,
    id_subaccount_remove_from,
    id_subaccount_add_to
)
SELECT
    uuid_generate_v4(),       -- Generates a unique GUID for the `id` field
    s.id_account,		      -- This request is owned by the owner of the subaccount.
    NULL,           		  -- No user has requested this re-allocation.
    CURRENT_TIMESTAMP,		  -- Sets the current timestamp for `create_time`
    p.id,                     -- Maps `profile.id` to `id_profile`
    NULL,                     -- Sets `id_subaccount_remove_from` to NULL
    p.id_subaccount           -- Maps `profile.id_subaccount` to `id_subaccount_add_to`
FROM
    profile p
    join "subaccount" s on s.id=p.id_subaccount
WHERE
    p.delete_time IS NULL
    AND p.id_subaccount IS NOT NULL;
```

## 4. Timeline Reprocessing

```sql
truncate table timeline;
update job set summarize_creation_to_timeline=null, summarize_status_to_timeline=null;
update enrichment set summarize_creation_to_timeline=null, summarize_status_to_timeline=null;
update outreach set summarize_creation_to_timeline=null, summarize_status_to_timeline=null;
update click set summarize_creation_to_timeline=null;
update unsubscribe set summarize_creation_to_timeline=null;
update "open" set summarize_creation_to_timeline=null;
```
