CREATE OR REPLACE FUNCTION public.create_booking(cart jsonb, user_data jsonb, p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_booking_id uuid := gen_random_uuid();
  v_total_price numeric := 0;
  v_conflicts jsonb := '[]'::jsonb;
  v_cart_item jsonb;
  v_item jsonb;
  v_room_id uuid;
  v_day date;
  v_start date;
  v_end date;
  v_hotel_id uuid;
  v_booking_hotel_id uuid := null;
  v_offering_id uuid;
  v_price_per_night numeric;
  v_ticket_number text := 'BK-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 999999)::text, 6, '0');
  v_json jsonb;
  v_previous_booking_ids uuid[];
begin
  select array_agg(id) into v_previous_booking_ids
  from bookings
  where session_id = p_session_id
    and status = 'pending';

  if v_previous_booking_ids is not null then
    delete from room_statuses
    where booking_id = any(v_previous_booking_ids);

    update bookings
    set status = 'abandoned'
    where id = any(v_previous_booking_ids);
  end if;

  for v_cart_item in select * from jsonb_array_elements(cart)
  loop
    v_hotel_id := (v_cart_item ->> 'hotel_id')::uuid;

    if v_booking_hotel_id is null then
      v_booking_hotel_id := v_hotel_id;
    elsif v_hotel_id <> v_booking_hotel_id then
      return jsonb_build_object(
        'success', false,
        'message', 'All rooms in one booking must belong to the same hotel.'
      );
    end if;

    v_start := (v_cart_item ->> 'start_date')::date;
    v_end := (v_cart_item ->> 'end_date')::date;

    for v_item in select * from jsonb_array_elements(v_cart_item -> 'items')
    loop
      v_room_id := (v_item ->> 'room_id')::uuid;
      v_offering_id := (v_item ->> 'offering_id')::uuid;

      select price into v_price_per_night
      from offerings
      where id = v_offering_id;

      if v_price_per_night is null then
        raise exception 'Invalid offering ID: %', v_offering_id;
      end if;

      for v_day in select generate_series(v_start, v_end - interval '1 day', interval '1 day')
      loop
        if exists (
          select 1 from room_statuses
          where room_id = v_room_id
            and status in ('booked', 'pending', 'not_available')
            and date = v_day::date
        ) then
          v_conflicts := v_conflicts || jsonb_build_object(
            'room_id', v_room_id,
            'room_number', (select room_number from hotel_rooms where id = v_room_id),
            'date', v_day::date
          );
        end if;
      end loop;

      v_total_price := v_total_price + v_price_per_night * (v_end - v_start);
    end loop;
  end loop;

  if jsonb_array_length(v_conflicts) > 0 then
    return jsonb_build_object(
      'success', false,
      'message', 'Some rooms are already booked for the selected dates.',
      'conflicts', v_conflicts
    );
  end if;

  insert into public.bookings (
    id,
    hotel_id,
    customer_name,
    customer_email,
    customer_phone,
    total_price,
    ticket_number,
    status,
    payment_status,
    session_id
  )
  values (
    v_booking_id,
    v_booking_hotel_id,
    user_data ->> 'name',
    user_data ->> 'email',
    user_data ->> 'phone',
    v_total_price,
    v_ticket_number,
    'pending',
    'unpaid',
    p_session_id
  );

  for v_cart_item in select * from jsonb_array_elements(cart)
  loop
    v_hotel_id := (v_cart_item ->> 'hotel_id')::uuid;
    v_start := (v_cart_item ->> 'start_date')::date;
    v_end := (v_cart_item ->> 'end_date')::date;

    for v_item in select * from jsonb_array_elements(v_cart_item -> 'items')
    loop
      v_room_id := (v_item ->> 'room_id')::uuid;
      v_offering_id := (v_item ->> 'offering_id')::uuid;

      select price into v_price_per_night
      from offerings
      where id = v_offering_id;

      insert into booking_items (booking_id, hotel_id, room_id, offering_id, price_per_night, start_date, end_date)
      values (v_booking_id, v_hotel_id, v_room_id, v_offering_id, v_price_per_night, v_start, v_end);

      for v_day in select generate_series(v_start, v_end - interval '1 day', interval '1 day')
      loop
        insert into room_statuses (room_id, date, status, booking_id)
        values (v_room_id, v_day::date, 'pending', v_booking_id);
      end loop;
    end loop;
  end loop;

  v_json := jsonb_build_object(
    'id', v_booking_id,
    'user_data', user_data,
    'cart', (
      select jsonb_agg(
        jsonb_build_object(
          'hotel', (
            select row_to_json(h) from (
              select id, name, description, address, rating, images
              from hotels
              where id = (cart_item ->> 'hotel_id')::uuid
            ) h
          ),
          'start_date', cart_item ->> 'start_date',
          'end_date', cart_item ->> 'end_date',
          'items', (
            select jsonb_agg(
              jsonb_build_object(
                'offering', (
                  select row_to_json(o) from (
                    select id, title, price, description, max_guests
                    from offerings
                    where id = (item ->> 'offering_id')::uuid
                  ) o
                ),
                'room', (
                  select row_to_json(r) from (
                    select id, room_number, description, capacity, is_active, offering_id, hotel_id
                    from hotel_rooms
                    where id = (item ->> 'room_id')::uuid
                  ) r
                ),
                'price_per_night', (
                  select price from offerings where id = (item ->> 'offering_id')::uuid
                )
              )
            )
            from jsonb_array_elements(cart_item -> 'items') as item
          )
        )
      )
      from jsonb_array_elements(cart) as cart_item
    ),
    'ticket_number', v_ticket_number,
    'total_price', v_total_price,
    'status', (select status from bookings where id = v_booking_id::uuid),
    'payment_status', (select payment_status from bookings where id = v_booking_id::uuid),
    'created_at', (select created_at from bookings where id = v_booking_id::uuid),
    'expires_at', (select created_at + interval '15 minutes' from bookings where id = v_booking_id::uuid)
  );

  return jsonb_build_object(
    'success', true,
    'booking', v_json
  );
end;
$$;
