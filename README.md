# Operations

## 1. Running Agency

### Building Custom Messages

#### Query to get leads to contact using cold email

```sql
SELECT distinct
	l.id,
	--t.name as tag_name,
    l.first_name, 
    l.last_name,
    l.job_title,
    l.linkedin,
    c."name",
    c.domain,
    l.email,
    l.email_verification_result,
    e.content,
  	-- no more than one outgoing email has been delivered to this lead
	(
		select count(*)
		from "outreach" o
		where o.id_lead = l.id
		and o.direction = 0
		and o.id_outreach_type = '6e48cb7c-3aeb-4adf-b06f-7d88f5f778ee' -- GMail_DirectMessage 
		and o.status in (0,2) -- pending or performed
	) as emails_sent

FROM "lead" l
join lead_tag lt on l.id=lt.id_lead
join "tag" t on (t.id=lt.id_tag and t.name='efficiency' and t.delete_time is null)
JOIN "country" y ON y.id = l.id_country
JOIN "company" c ON c.id = l.id_company
JOIN "headcount" h ON h.id = c.id_headcount
JOIN LATERAL (
    SELECT e.content
    FROM "event" e
    WHERE e.id_lead = l.id
    AND e.create_time > current_timestamp - interval '7 day' -- recent events only
/*
    AND (
        e."content" ILIKE '%boost%' OR
        e."content" ILIKE '%operations%' OR
        e."content" ILIKE '%optimization%' OR
        e."content" ILIKE '%efficiency%'
    )
*/
    ORDER BY e.create_time DESC
    LIMIT 1
) e ON TRUE
WHERE l.email IS NOT NULL
  AND l.email_verification_result = 2
  --AND h.min > 10
  AND y.name ILIKE 'United States'
  AND (
    l.job_title ILIKE '%owner%' OR
    l.job_title ILIKE '%founder%' OR
    l.job_title ILIKE '%CEO%' OR
    l.job_title ILIKE '%president%'
  )

AND (
	select count(*)
	from "outreach" o
	where o.id_lead = l.id
	and o.direction = 0
	and o.id_outreach_type = '6e48cb7c-3aeb-4adf-b06f-7d88f5f778ee' -- GMail_DirectMessage 
	and o.status in (0,2) -- pending or performed
) < 1

--and l.id='7369a648-bd0a-4e96-80dd-897c412f997a'
  
ORDER BY l.first_name, l.last_name, l.job_title;
```

#### Query to send LinkedIn message to LinkedIn accepters

```sql
SELECT DISTINCT
    l.id,
    l.first_name, 
    l.last_name,
    l.job_title,
    l.linkedin,
    c."name",
    c.domain,
    l.email,
    l.email_verification_result,
    e.content,
  	-- no more than one outgoing message has been delivered to this lead
	(
		select count(*)
		from "outreach" o
		where o.id_lead = l.id
		and o.direction = 0
		and o.id_outreach_type = '0b0110b9-cbef-4c22-b4a8-3a0cfdfbe863' -- LinkedIn_DirectMessage 
		and o.status in (0,2) -- pending or performed
	) as emails_sent

FROM "lead" l
join lead_tag lt on l.id=lt.id_lead
join "tag" t on (t.id=lt.id_tag and t.name='efficiency' and t.delete_time is null)
JOIN "country" y ON y.id = l.id_country
JOIN "company" c ON c.id = l.id_company
JOIN "headcount" h ON h.id = c.id_headcount

-- sent a linkedin connection request
join "outreach" o1 on (l.id=o1.id_lead and o1.status=2 and o1.direction=0 and o1.id_outreach_type='d866a830-0697-4102-91c0-e8186c3eb612')

-- the linkedin connection has been accepted
join "outreach" o2 on (l.id=o2.id_lead and o1.id_profile=o2.id_profile and o2.status=2 and o2.direction=2)

JOIN LATERAL (
    SELECT e.content
    FROM "event" e
    WHERE e.id_lead = l.id
    --AND e.create_time > current_timestamp - interval '7 day' -- recent events only
    /*
    AND (
        e."content" ILIKE '%boost%' OR
        e."content" ILIKE '%operations%' OR
        e."content" ILIKE '%optimization%' OR
        e."content" ILIKE '%efficiency%'
    )
    */
    ORDER BY e.create_time DESC
    LIMIT 1
) e ON TRUE
WHERE l.email IS NOT NULL
--AND l.email_verification_result = 2
and l.linkedin is not null
--AND h.min > 10
AND y.name ILIKE 'United States'
/*
AND (
    l.job_title ILIKE '%owner%' OR
    l.job_title ILIKE '%founder%' OR
    l.job_title ILIKE '%CEO%' OR
    l.job_title ILIKE '%president%'
)
*/
-- no more than one outgoing message has been delivered to this lead
AND (
	select count(*)
	from "outreach" o
	where o.id_lead = l.id
	and o.direction = 0
	and o.id_outreach_type = '0b0110b9-cbef-4c22-b4a8-3a0cfdfbe863' -- LinkedIn_DirectMessage 
	and o.status in (0,2) -- pending or performed
) < 1
  
ORDER BY l.first_name, l.last_name, l.job_title;
```

#### Check outreaches created by mass-copilot

```sql 
select o.create_time, email, first_name, last_name, job_title, linkedin, email_verification_result, subject, body
from "lead" l
join "outreach" o on (l.id=o.id_lead and o.create_time > current_timestamp - interval '60 minute')
--where id='e23c222a-f212-4429-9f25-7b36e8729cf6'
--where email ilike '%example%'
order by o.create_time desc
```

#### Prompts Generator

[spreadhseet_formula_1](spreadsheet_formula_1.txt)

[spreadhseet_formula_2](spreadsheet_formula_2.txt)

[spreadhseet_formula_3](spreadsheet_formula_3.txt)

### Draining Old Jobs

```sql
delete from event_job;
delete from job_screenshot;

delete from enrichment_screenshot;
delete from enrichment_snapshot;

delete from inboxcheck where id in (
	select id
	--select count(*)
	from inboxcheck 
	where create_time < current_timestamp - interval '12 hours'
	and status <> 0
	limit 100000
);

delete from connectioncheck where id in (
	select id
	--select count(*)
	from connectioncheck
	where create_time < current_timestamp - interval '12 hours'
	and status <> 0
	limit 10000
);
```

### Cancel old pending jobs at the starting of a new day.

Perform this task daily, until we develop ["prioritize newer" parameter to the rules engine](https://github.com/MassProspecting/docs/issues/336).

```sql
-- Cancel old pending jobs at the starting of a new day.
--
update "enrichment" set status=5 where status=0 and id in (
	select e.id
	--select count(*)
	from "enrichment" e
	join "lead" l on l.id=e.id_lead
	where e.status=0
	and e.create_time < current_timestamp - interval '12 hours'
);
```

### Cancel old failed jobs at the starting of a new day.

```sql
-- Cancel old failed jobs at the starting of a new day.
--
update "job" set status=5 where status=3;
update "inboxcheck" set status=5 where status=3;
update "connectioncheck" set status=5 where status=3;
update "enrichment" set status=5 where status=3;
update "outreach" set status=5 where status=3;
```

### Cancel jobs that started time ago and never finished.

```sql
-- Cancel jobs that started time ago and never finished.
--
update "job" set status=0 where status=1 and update_time<current_timestamp - interval '45 minutes';
update inboxcheck set status=0 where status=1 and update_time<current_timestamp - interval '45 minutes';
update connectioncheck set status=0 where status=1 and update_time<current_timestamp - interval '45 minutes';
update "job" set status=0 where status=1 and update_time<current_timestamp - interval '45 minutes';
update "enrichment" set status=0 where status=1 and update_time<current_timestamp - interval '45 minutes';
update "outreach" set status=0 where status=1 and update_time<current_timestamp - interval '45 minutes';
```

### Add the `target` tag to enriched leads.

Run the `insert` setnences generated by the query below.

```sql
-- Enriched leads to add the `target` tag.
--
select '
	insert into lead_tag (id, id_account, create_time, update_time, id_lead, id_tag) values (
		uuid_generate_v4(),
		''87a65cf4-c11d-4700-b266-58361ca14b8e'', -- my-agency
		current_timestamp,
		current_timestamp,
		'''||cast(e.id_lead as varchar(500))||''',
		''d94f69a1-1ef1-417c-bac2-ff0f2921f1f8'' -- target
	);	
', l.create_time, l.first_name, l.last_name, l.job_title, h."name", y.name
from enrichment e
join rule_instance i on (i.id=e.id_rule_instance and i.id_rule='0968b2ee-3998-49e4-b2fc-b3ca28dbe5e8')
join "lead" l on l.id=e.id_lead
join "company" c on c.id=l.id_company
left join headcount h on h.id=c.id_headcount 
left join country y on y.id=c.id_country 
where l.id not in (
	select x.id_lead
	from lead_tag x
	where x.id_tag='d94f69a1-1ef1-417c-bac2-ff0f2921f1f8' -- target
)
and l.create_time > current_timestamp - interval '24 hours' -- prioritize recent enrichments 
and y.name = 'United States'
and h.min >= 4
and (
	l.job_title ilike '%expert%' or
	l.job_title ilike '%help%' or
	l.job_title ilike '%owner%' or
	l.job_title ilike '%CEO%' or
	l.job_title ilike '%founder%' or
	l.job_title ilike '%president%'
)
--order by h.min desc, l.create_time desc
order by l.create_time desc
```

### Monitoring Enrichment Performance

Use this query until the `timeline` is working perfectly.

```sql
-- Enricment Performance
-- 
select e.update_time, e.hit, i.id_rule
from enrichment e 
left join rule_instance i on i.id=e.id_rule_instance 
where e.status=2 
and e.update_time>current_timestamp - interval '30 minutes' 
order by e.hit, e.update_time desc
```

### Verified emails to export to Instanctly.

_pending_


## 2. Development

1. I want to connect a remote postgresql server and generate a backup in my local computer using an SQL sentence

```
pg_dump -h s01.massprospecting.com -p 5432 -U blackstack -W blackstack > backup.sql
```

2. Restore the database in your local computer.

```
psql -U blackstack -d mass.slave -f ./backup.sql
```

**Note:** For running the command above, you have to 

1. edit the file `/etc/postgresql/<version>/main/pg_hba.conf`;
2. replace the line 

```
local   all             all                                     peer
``` 

by 

```
local   all             all                                     md5
```

and

3. restart PostgreSQL

```
sudo systemctl restart postgresql
```

