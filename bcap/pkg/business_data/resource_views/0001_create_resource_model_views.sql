select __arches_create_resource_model_views(graphid)
from graphs
where isresource = true
  and publicationid is not null
  and name->>'en' != 'Arches System Settings';

-- Can these go in as migrations? When does that run WRT model creation?
create or replace function get_uuid_lookup_table(parent_name text, language_code text[] default array['en', 'en-US'])
    returns table(parent_label text, parent_concept_uuid uuid, parent_value_uuid uuid, child_label text, child_concept_uuid uuid, child_value_uuid uuid) as
$$
declare
begin
    return query with recursive concept_hierarchy as (
        select null parent_value, null::uuid parent_concept_uuid, null::uuid parent_value_uuid,
               v.value child_value, v.conceptid child_concept_uuid, v.valueid child_value_uuid
        from concepts c,
             values v,
             relations r
        where c.conceptid = v.conceptid
          and r.conceptidto = c.conceptid
          and nodetype = 'Concept'
          and v.value = parent_name
          and v.languageid = any(language_code)
          and r.relationtype = 'hasTopConcept'
        UNION ALL
        select parent_v.value    parent_value,
               parent_v.conceptid  parent_concept_uuid,
               parent_v.valueid  parent_value_uuid,
               child_v.value     child_value,
               child_v.conceptid child_concept_uuid,
               child_v.valueid child_value_uuid
        from relations child
                 JOIN concept_hierarchy hier on hier.child_concept_uuid = child.conceptidfrom,
             concepts child_c,
             values child_v,
             values parent_v
        where child_c.conceptid = child_v.conceptid
          and child.conceptidto = child_c.conceptid
          and nodetype = 'Concept'
          and hier.child_concept_uuid = parent_v.conceptid
          and child.relationtype in ('member','narrower')
          and child_v.valuetype = 'prefLabel'
          and parent_v.valuetype = 'prefLabel'
          and child_v.languageid = parent_v.languageid
          and parent_v.languageid = any (language_code)
    )
                 select distinct *
                 from concept_hierarchy order by parent_value, child_value;
end $$
    language plpgsql;

drop function if exists bcap_build_image_caption;
create or replace function bcap_build_image_caption(image_view text, image_features text, image_date timestamp) returns text as $$
begin
    return image_view || case when image_features is not null and image_features <> '' then ' - '||image_features else '' end ||
    case when image_date is not null then ', '||to_char(image_date,'yyyy') else '' end;
end $$
    language plpgsql;