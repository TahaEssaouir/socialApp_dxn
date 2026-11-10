-- 0014_service_center_contacts.sql — plusieurs téléphones / emails par centre.
-- Colonnes phones/emails (tableaux) ; les anciennes valeurs texte sont
-- séparées en éléments distincts (séparateurs « / », « , », « ; »).

alter table public.service_centers
  add column if not exists phones text[];

alter table public.service_centers
  add column if not exists emails text[];

update public.service_centers
set phones = (
  select array_agg(btrim(part))
  from unnest(
    string_to_array(
      replace(replace(btrim(phone), ',', '/'), ';', '/'), '/'
    )
  ) as part
  where btrim(part) <> ''
)
where phone is not null and btrim(phone) <> '';

update public.service_centers
set emails = (
  select array_agg(btrim(part))
  from unnest(
    string_to_array(
      replace(replace(btrim(email), ',', '/'), ';', '/'), '/'
    )
  ) as part
  where btrim(part) <> ''
)
where email is not null and btrim(email) <> '';

alter table public.service_centers drop column if exists phone;
alter table public.service_centers drop column if exists email;

-- Les éléments vides sont interdits (l'app filtre déjà les champs vides).
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'service_centers_phones_no_empty'
  ) then
    alter table public.service_centers
      add constraint service_centers_phones_no_empty
      check (phones is null or not ('' = any (phones)));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'service_centers_emails_no_empty'
  ) then
    alter table public.service_centers
      add constraint service_centers_emails_no_empty
      check (emails is null or not ('' = any (emails)));
  end if;
end;
$$;
