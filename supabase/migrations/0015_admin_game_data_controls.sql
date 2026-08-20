create or replace function public.admin_get_game_data(p_game uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare result jsonb;
begin
  perform public._assert_is_admin();
  select jsonb_build_object(
    'game', (select to_jsonb(g) from public.games g where g.id=p_game),
    'players', coalesce((select jsonb_agg(to_jsonb(x) order by x.display_name nulls last,x.id) from (select p.id,p.user_id,p.display_name,p.avatar_url,p.metadata,p.is_admin,p.created_at,p.updated_at from public.players p join public.game_players gp on gp.player_id=p.id where gp.game_id=p_game) x),'[]'::jsonb),
    'game_players', coalesce((select jsonb_agg(to_jsonb(gp) order by gp.joined_at,gp.id) from public.game_players gp where gp.game_id=p_game),'[]'::jsonb),
    'countries', coalesce((select jsonb_agg(to_jsonb(c) order by c.name,c.id) from public.countries c where c.game_id=p_game),'[]'::jsonb),
    'building_types', coalesce((select jsonb_agg(to_jsonb(bt) order by bt.id) from public.building_types bt),'[]'::jsonb),
    'country_buildings', coalesce((select jsonb_agg(to_jsonb(cb) order by cb.installed_at,cb.id) from public.country_buildings cb join public.countries c on c.id=cb.country_id where c.game_id=p_game),'[]'::jsonb),
    'wallets', coalesce((select jsonb_agg(to_jsonb(w) order by w.player_id,w.currency) from public.wallets w join public.players p on p.id=w.player_id join public.game_players gp on gp.player_id=p.id where gp.game_id=p_game),'[]'::jsonb),
    'listings', coalesce((select jsonb_agg(to_jsonb(cl) order by cl.created_at desc) from public.country_listings cl join public.countries c on c.id=cl.country_id where c.game_id=p_game),'[]'::jsonb),
    'bids', coalesce((select jsonb_agg(to_jsonb(b) order by b.created_at desc) from public.bids b join public.country_listings cl on cl.id=b.listing_id join public.countries c on c.id=cl.country_id where c.game_id=p_game),'[]'::jsonb)
  ) into result;
  if result->'game' is null then raise exception 'game_not_found'; end if;
  return result;
end;
$$;

create or replace function public.admin_update_game(p_game uuid,p_patch jsonb)
returns void language plpgsql security definer set search_path=public as $$
begin
  perform public._assert_is_admin();
  update public.games set name=case when p_patch?'name' then p_patch->>'name' else name end, slug=case when p_patch?'slug' then p_patch->>'slug' else slug end, config=case when p_patch?'config' then p_patch->'config' else config end, tick_interval_seconds=case when p_patch?'tick_interval_seconds' then greatest(1,(p_patch->>'tick_interval_seconds')::int) else tick_interval_seconds end, current_tick=case when p_patch?'current_tick' then greatest(0,(p_patch->>'current_tick')::int) else current_tick end, updated_at=now() where id=p_game;
  if not found then raise exception 'game_not_found'; end if;
end;
$$;

create or replace function public.admin_update_entity(p_entity text,p_id text,p_patch jsonb)
returns void language plpgsql security definer set search_path=public as $$
declare allowed boolean:=false;
begin
  perform public._assert_is_admin();
  if p_entity='players' then
    allowed:=p_patch ?| array['display_name','avatar_url','metadata','is_admin'];
    update public.players set display_name=case when p_patch?'display_name' then nullif(p_patch->>'display_name','') else display_name end, avatar_url=case when p_patch?'avatar_url' then nullif(p_patch->>'avatar_url','') else avatar_url end, metadata=case when p_patch?'metadata' then p_patch->'metadata' else metadata end, is_admin=case when p_patch?'is_admin' then (p_patch->>'is_admin')::boolean else is_admin end, updated_at=now() where id=p_id::uuid;
  elsif p_entity='game_players' then
    allowed:=p_patch ?| array['status','metadata']; update public.game_players set status=case when p_patch?'status' then p_patch->>'status' else status end, metadata=case when p_patch?'metadata' then p_patch->'metadata' else metadata end where id=p_id::uuid;
  elsif p_entity='countries' then
    allowed:=p_patch ?| array['name','code','population','resources','owner_player_id','metadata']; update public.countries set name=case when p_patch?'name' then p_patch->>'name' else name end, code=case when p_patch?'code' then nullif(p_patch->>'code','') else code end, population=case when p_patch?'population' then greatest(0,(p_patch->>'population')::bigint) else population end, resources=case when p_patch?'resources' then p_patch->'resources' else resources end, owner_player_id=case when p_patch?'owner_player_id' and nullif(p_patch->>'owner_player_id','') is not null then (p_patch->>'owner_player_id')::uuid when p_patch?'owner_player_id' then null else owner_player_id end, metadata=case when p_patch?'metadata' then p_patch->'metadata' else metadata end, updated_at=now() where id=p_id::uuid;
  elsif p_entity='building_types' then
    allowed:=p_patch ?| array['slug','name','base_cost','base_income','maintenance_cost','max_level','metadata']; update public.building_types set slug=case when p_patch?'slug' then p_patch->>'slug' else slug end, name=case when p_patch?'name' then p_patch->>'name' else name end, base_cost=case when p_patch?'base_cost' then greatest(0,(p_patch->>'base_cost')::bigint) else base_cost end, base_income=case when p_patch?'base_income' then greatest(0,(p_patch->>'base_income')::bigint) else base_income end, maintenance_cost=case when p_patch?'maintenance_cost' then greatest(0,(p_patch->>'maintenance_cost')::bigint) else maintenance_cost end, max_level=case when p_patch?'max_level' then greatest(1,(p_patch->>'max_level')::int) else max_level end, metadata=case when p_patch?'metadata' then p_patch->'metadata' else metadata end, updated_at=now() where id=p_id::int;
  elsif p_entity='country_buildings' then
    allowed:=p_patch ?| array['building_type_id','level','count','metadata']; update public.country_buildings set building_type_id=case when p_patch?'building_type_id' then (p_patch->>'building_type_id')::int else building_type_id end, level=case when p_patch?'level' then greatest(1,(p_patch->>'level')::int) else level end, count=case when p_patch?'count' then greatest(1,(p_patch->>'count')::int) else count end, metadata=case when p_patch?'metadata' then p_patch->'metadata' else metadata end, updated_at=now() where id=p_id::uuid;
  elsif p_entity='country_listings' then
    allowed:=p_patch ?| array['price','currency','status','expires_at']; update public.country_listings set price=case when p_patch?'price' then greatest(1,(p_patch->>'price')::bigint) else price end, currency=case when p_patch?'currency' then p_patch->>'currency' else currency end, status=case when p_patch?'status' then p_patch->>'status' else status end, expires_at=case when p_patch?'expires_at' and nullif(p_patch->>'expires_at','') is not null then (p_patch->>'expires_at')::timestamptz when p_patch?'expires_at' then null else expires_at end, updated_at=now() where id=p_id::uuid;
  elsif p_entity='bids' then
    allowed:=p_patch ?| array['amount','currency','status']; update public.bids set amount=case when p_patch?'amount' then greatest(1,(p_patch->>'amount')::bigint) else amount end, currency=case when p_patch?'currency' then p_patch->>'currency' else currency end, status=case when p_patch?'status' then p_patch->>'status' else status end where id=p_id::uuid;
  else raise exception 'unsupported_admin_entity'; end if;
  if not allowed then raise exception 'no_editable_fields'; end if;
  insert into public.admin_actions(admin_user_id,action_type,target_table,target_id,details) values(auth.uid(),'update_entity',p_entity,case when p_id~*'^[0-9a-f-]{36}$' then p_id::uuid else null end,jsonb_build_object('patch',p_patch));
end;
$$;

create or replace function public.admin_adjust_balance(p_player uuid,p_amount bigint,p_currency text default 'USD',p_reason text default 'admin_adjustment')
returns uuid language plpgsql security definer set search_path=public as $$
declare w_id uuid; before_balance bigint; tx_id uuid:=gen_random_uuid();
begin
  perform public._assert_is_admin();
  select id,balance into w_id,before_balance from public.wallets where player_id=p_player and currency=p_currency limit 1 for update;
  if w_id is null then insert into public.wallets(player_id,currency,balance) values(p_player,p_currency,0) returning id,balance into w_id,before_balance; end if;
  update public.wallets set balance=balance+p_amount,updated_at=now() where id=w_id;
  insert into public.wallet_transactions(wallet_id,amount,balance_before,balance_after,event_type,reference_id,metadata) values(w_id,p_amount,before_balance,before_balance+p_amount,'admin_adjustment',tx_id,jsonb_build_object('reason',p_reason,'admin_user',auth.uid()));
  insert into public.admin_actions(admin_user_id,action_type,target_table,target_id,details) values(auth.uid(),'balance_adjustment','wallets',w_id,jsonb_build_object('player_id',p_player,'amount',p_amount,'currency',p_currency,'reason',p_reason,'before',before_balance,'after',before_balance+p_amount));
  return tx_id;
end;
$$;

revoke all on function public.admin_get_game_data(uuid) from public,anon,authenticated;
revoke all on function public.admin_update_game(uuid,jsonb) from public,anon,authenticated;
revoke all on function public.admin_update_entity(text,text,jsonb) from public,anon,authenticated;
revoke all on function public.admin_adjust_balance(uuid,bigint,text,text) from public,anon,authenticated;
grant execute on function public.admin_get_game_data(uuid) to authenticated;
grant execute on function public.admin_update_game(uuid,jsonb) to authenticated;
grant execute on function public.admin_update_entity(text,text,jsonb) to authenticated;
grant execute on function public.admin_adjust_balance(uuid,bigint,text,text) to authenticated;
