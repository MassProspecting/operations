## OPERATIONS

1. hire leasers
2. hire mtas: get phone numbers for app password generation, 
3. developers payments management
4. proxies payments management
5. leasers payments management
6. mta payments management: gsuite, postmark
7. customer support FAQs
8. balance mensual
9. planificacion de recursos: decidir si comprar o no mtas y rpas
10. allocacion y desalocacion de recursos a un cliente
11. workflow setup to a client: guarantee finding accurate results enough

## ENGINEERING

1. hire developers
2. train developers
3. write requirements to developers
4. check browser leaks
5. check mta blacklisting: gsuite, postmark
6. monitor nodes performance: memory, CPU, disk, postgres
7. check processing glitches: jobs status, logs, requests, rule_instances
8. fix glitches
9. backup production databases
10. split move subaccount
11. drain subaccount
12. upgrade worker nodes
13. upgrade master/slave nodes

## SALES

1. followup leads
2. content: script, video production, publication yt, tt, facebook, bhw, reddit
3. cold messaging
4. email marketing

---

_This is the old documentation_

# Operations

## 1. BackUps

Before starting, switch to the user `blackstack` in your environment:

```
su - blackstack
```

### 1.1. BackUp Production Database

You can create a backup of a production database from your local computer.

```
TIMESTAMP=$(date +"%Y%m%d.%H%M") && \
pg_dump -h massprospecting.com -p 5432 -U blackstack -W blackstack | tee master.$TIMESTAMP.sql && \
pg_dump -h free01.massprospecting.com -p 5432 -U blackstack -W blackstack | tee free01.$TIMESTAMP.sql
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

## 4. Reprocessing

### Jobs Reprocessing

After deploying a fix-patch, you should restart all the failed jobs.

```sql
update "job" set status=0 where status=3; 
update "enrichment" set status=0 where status=3; 
update "outreach" set status=0 where status=3; 
update "inboxcheck" set status=0 where status=3; 
update "connectioncheck" set status=0 where status=3; 
```

### Jobs Restarting

If you shuted down servers, many jobs may have been interrupted while they were running.

```sql
update job set status=0 where status=1;
update inboxcheck set status=0 where status=1;
update connectioncheck set status=0 where status=1;
update enrichment set status=0 where status=1;
update outreach set status=0 where status=1;
```

### Timeline Reprocessing

After restarting jobs, you should reprocess the timeline.

```sql
truncate table timeline;
update job set summarize_creation_to_timeline=null, summarize_status_to_timeline=null;
update enrichment set summarize_creation_to_timeline=null, summarize_status_to_timeline=null;
update outreach set summarize_creation_to_timeline=null, summarize_status_to_timeline=null;
update click set summarize_creation_to_timeline=null;
update unsubscribe set summarize_creation_to_timeline=null;
update "open" set summarize_creation_to_timeline=null;
```

## 5. Get Report of Nodes Occupancy

```sql
select p.hostname, t.access, count(p.id)
from "profile" p
join "profile_type" t on t.id=p.id_profile_type
where p.delete_time is null
group by p.hostname, t.access
order by p.hostname, t.access
```

## 6. Downalod HTYML and Extract Leads with GPT

Download result pages of LinkedIn free search, and parse them using [`attendees.rb`](./assets/scripts/attendees.rb).

## 7. Check if Emails Have Been Delivered

Get emails delivered by profiles using this query:

```sql
select l.first_name, l.last_name, l.email, l.email_verification_result, o.done_time, o.body
from "rule" r
join rule_instance i on r.id=i.id_rule
join outreach o on i.id=o.id_rule_instance
join lead l on l.id=o.id_lead
where r.name='optimally-b-6'
and o.status=2
--and o.body ilike '%B2%'
order by l.first_name, l.last_name --l.email_verification_result
```

Run [`imap.rb`](./assets/scripts/imap.rb) to find such email in the real outbox of the profile.

## 8. Reports

### 8.1. Clickers

```sql
select k.url, l.first_name, l.last_name
from "click" c
join "link" k on k.id=c.id_link
join "outreach" o on o.id=c.id_outreach
join "lead" l on l.id=o.id_lead
order by k.create_time desc
```

### 8.2. Openers

```sql
select l.email, l.first_name, l.last_name, count(*)
from "open" c
join "outreach" o on o.id=c.id_outreach
join "lead" l on l.id=o.id_lead
group by l.email, l.first_name, l.last_name
order by l.email
```

### 8.3. Unsubscribers

```sql
select * from "unsubscribe"
```

### 8.4. Repliers

```sql
SELECT r.name, l.first_name, l.last_name, count(response.id)
from "rule" r
join "action" a on a.id=r.id_action
join "outreach" o on a.id=o.id_action
join "lead" l on l.id=o.id_lead
left join outreach response on (
	response.id_lead=o.id_lead and
	response.id_profile=o.id_profile and
	response.direction = 1 -- incoming
)
--where r.id='b44bf664-347c-46aa-bf2b-5a49252874e9'
group by r.name, l.first_name, l.last_name
having count(response.id) > 0
order by count(response.id) desc
```

## 9. Fix Facebook PIN Issue

Sometimes, the **Check Inbox** of Facebook profiles fails with this error message: `element click intercepted`, and a screenshot like below:

![Facebook PIN issue](./assets/images/facebook-pin-issue.png).

Accessing the profile manually doesn't have such a problem, but running the profile in headliness mode in production raises that error.

Here are the steps to fix this glitch:

1. Stop the profile in production.
2. In your local computer, open the profile manually, access the inbox, and enter the PIN if it is required.
3. In the same local computer, run the `inboxcheck` command in headless model.

After this, you can start again the profile in production, and the issue may be fixed.
