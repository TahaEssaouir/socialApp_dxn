-- 0014_service_centers_array_contacts.sql
-- Codifie la gestion multi-contacts : phones/emails text[] (un contact par élément).
-- Remplace (et supprime) les anciennes colonnes texte phone/email si elles existent.

alter table public.service_centers
  add column if not exists phones text[],
  add column if not exists emails text[];

-- Reprise des anciens contacts texte (un contact par ligne).
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'service_centers'
      and column_name = 'phone'
  ) then
    update public.service_centers
    set phones = coalesce(
      phones,
      array_remove(string_to_array(phone, chr(10)), '')
    )
    where phones is null
      and phone is not null
      and btrim(phone) <> '';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'service_centers'
      and column_name = 'email'
  ) then
    update public.service_centers
    set emails = coalesce(
      emails,
      array_remove(string_to_array(email, chr(10)), '')
    )
    where emails is null
      and email is not null
      and btrim(email) <> '';
  end if;
end $$;

-- Pas d'éléments vides dans les tableaux de contacts (idempotent).
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
end $$;

-- Les anciennes colonnes texte sont retirées.
alter table public.service_centers drop column if exists phone;
alter table public.service_centers drop column if exists email;
