

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "postgis" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."amenity_availability_status" AS ENUM (
    'available',
    'unavailable',
    'seasonal',
    'limited_hours'
);


ALTER TYPE "public"."amenity_availability_status" OWNER TO "postgres";


CREATE TYPE "public"."amenity_category" AS ENUM (
    'in_room',
    'property_wide',
    'service',
    'food_beverage',
    'leisure_wellness'
);


ALTER TYPE "public"."amenity_category" OWNER TO "postgres";


CREATE TYPE "public"."amenity_cost_type" AS ENUM (
    'included',
    'free',
    'paid_extra',
    'on_request'
);


ALTER TYPE "public"."amenity_cost_type" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bookings_initiate"("user_data" "jsonb", "cart" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql"
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
  v_offering_id uuid;
  v_price_per_night numeric;
  v_ticket_number text := 'BK-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 999999)::text, 6, '0');
  v_json jsonb;
begin
  -- Loop through each hotel booking in the cart
  for v_cart_item in select * from jsonb_array_elements(cart)
  loop
    v_hotel_id := (v_cart_item ->> 'hotel_id')::uuid;
    v_start := (v_cart_item ->> 'start_date')::date;
    v_end := (v_cart_item ->> 'end_date')::date;

    for v_item in select * from jsonb_array_elements(v_cart_item -> 'items')
    loop
      v_room_id := (v_item ->> 'room_id')::uuid;
      v_offering_id := (v_item ->> 'offering_id')::uuid;

      -- Get price from offerings table
      select price into v_price_per_night
      from offerings
      where id = v_offering_id;

      if v_price_per_night is null then
        raise exception 'Invalid offering ID: %', v_offering_id;
      end if;

      -- Check availability day by day
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

      -- Accumulate total price
      v_total_price := v_total_price + v_price_per_night * (v_end - v_start);
    end loop;
  end loop;

  -- If conflicts found, return them
  if jsonb_array_length(v_conflicts) > 0 then
    return jsonb_build_object(
      'success', false,
      'message', 'Some rooms are already booked for the selected dates.',
      'conflicts', v_conflicts
    );
  end if;

  -- Create booking record (anonymous or registered)
  insert into public.bookings (id, customer_name, customer_email, customer_phone, total_price, ticket_number, status, payment_status)
  values (
    v_booking_id,
    user_data ->> 'name',
    user_data ->> 'email',
    user_data ->> 'phone',
    v_total_price,
    v_ticket_number,
    'pending',
    'unpaid'
  );

  -- Insert room statuses and booking items
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

      -- Mark room as pending for each day
      for v_day in select generate_series(v_start, v_end - interval '1 day', interval '1 day')
      loop
        insert into room_statuses (room_id, date, status, booking_id)
        values (v_room_id, v_day::date, 'pending', v_booking_id);
      end loop;
    end loop;
  end loop;

  -- Build final response JSON
  v_json := jsonb_build_object(
    'id', v_booking_id,
    'user_data', user_data,
    'cart', (
      select jsonb_agg(
        jsonb_build_object(
          'hotel', (
            select row_to_json(h) from (
              select id, name, description, address, rating, images from hotels where id = (v_cart_item ->> 'hotel_id')::uuid
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


ALTER FUNCTION "public"."bookings_initiate"("user_data" "jsonb", "cart" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bookings_initiate"("user_data" "jsonb", "cart" "jsonb", "total_price" numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_booking_id UUID;
  v_booking JSONB;
  v_ticket TEXT;
  v_hotel_id UUID;
  v_booking_item JSONB;
  v_item JSONB;
  v_day DATE;
  v_room_id UUID;
  v_conflicts JSONB := '[]'::JSONB;
BEGIN
  -- 🏷 Generate ticket number
  v_ticket := 'TCK-' || encode(gen_random_bytes(4), 'hex');
  v_hotel_id := (cart->0->>'hotel_id')::UUID;

  -- 🧭 Step 1: Check for room conflicts
  FOR v_booking_item IN SELECT * FROM jsonb_array_elements(cart)
  LOOP
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_booking_item->'items')
    LOOP
      v_room_id := (v_item->>'room_id')::UUID;

      FOR v_day IN
        SELECT generate_series(
          (v_booking_item->>'start_date')::DATE,
          ((v_booking_item->>'end_date')::DATE - INTERVAL '1 day')::DATE,
          '1 day'::INTERVAL
        )::DATE
      LOOP
        IF EXISTS (
          SELECT 1 FROM room_statuses
          WHERE room_id = v_room_id
            AND date = v_day
            AND status IN ('booked', 'not_available')
        ) THEN
          v_conflicts := v_conflicts || jsonb_build_object(
          'room_id', v_room_id,
          'room_number', (SELECT room_number FROM hotel_rooms WHERE id = v_room_id),
          'date', v_day
        );
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  -- 🚧 Step 2: Return early if any conflict found
  IF jsonb_array_length(v_conflicts) > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Some rooms are not available for the selected dates.',
      'conflicts', v_conflicts
    );
  END IF;

  -- ✅ Step 3: Create booking
  INSERT INTO public.bookings (
    hotel_id,
    customer_name,
    customer_phone,
    customer_email,
    total_price,
    status,
    payment_status,
    ticket_number
  )
  VALUES (
    v_hotel_id,
    user_data->>'name',
    user_data->>'phone',
    user_data->>'email',
    total_price,
    'pending',
    'unpaid',
    v_ticket
  )
  RETURNING id INTO v_booking_id;

  -- 🧱 Step 4: Insert booking items + pending room statuses
  FOR v_booking_item IN SELECT * FROM jsonb_array_elements(cart)
  LOOP
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_booking_item->'items')
    LOOP
      v_room_id := (v_item->>'room_id')::UUID;

      INSERT INTO booking_items (
        booking_id, hotel_id, room_id, offering_id,
        start_date, end_date
      ) VALUES (
        v_booking_id,
        (v_booking_item->>'hotel_id')::UUID,
        v_room_id,
        (v_item->>'offering_id')::UUID,
        (v_booking_item->>'start_date')::DATE,
        (v_booking_item->>'end_date')::DATE
      );

      -- Create daily pending statuses
      FOR v_day IN
        SELECT generate_series(
          (v_booking_item->>'start_date')::DATE,
          ((v_booking_item->>'end_date')::DATE - INTERVAL '1 day')::DATE,
          '1 day'::INTERVAL
        )::DATE
      LOOP
        INSERT INTO room_statuses (room_id, date, status)
        VALUES (v_room_id, v_day, 'pending');
      END LOOP;
    END LOOP;
  END LOOP;

  -- 🪄 Step 5: Return booking record
  SELECT jsonb_build_object(
    'id', b.id,
    'success', true,
    'ticket_number', b.ticket_number,
    'status', b.status,
    'payment_status', b.payment_status,
    'total_price', b.total_price,
    'customer_name', b.customer_name,
    'items', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', bi.id,
          'room_id', bi.room_id,
          'offering_id', bi.offering_id,
          'hotel_id', bi.hotel_id,
          'start_date', bi.start_date,
          'end_date', bi.end_date
        )
      )
      FROM booking_items bi
      WHERE bi.booking_id = b.id
    )
  )
  INTO v_booking
  FROM bookings b
  WHERE b.id = v_booking_id;

  RETURN v_booking;
END;
$$;


ALTER FUNCTION "public"."bookings_initiate"("user_data" "jsonb", "cart" "jsonb", "total_price" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_old_unconfirmed_bookings"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
DECLARE
booking_ids uuid[];
fkey RECORD;
child_table REGCLASS;
column_name TEXT;
BEGIN
SELECT array_agg(id)
INTO booking_ids
FROM bookings
WHERE created_at < now() - interval '15 minutes'
AND status <> 'confirmed';

IF booking_ids IS NULL OR array_length(booking_ids, 1) = 0 THEN
    RETURN;
END IF;

FOR fkey IN
    SELECT
        c.conrelid,
        a.attname AS column_name
    FROM pg_constraint c
    JOIN LATERAL (
        SELECT unnest(c.conkey) AS ill
    ) AS k ON true
    JOIN pg_attribute a
        ON a.attrelid = c.conrelid
       AND a.attnum = (k.ill)
    WHERE c.contype = 'f'
      AND c.confrelid = 'public.bookings'::regclass
LOOP
    child_table := fkey.conrelid;
    column_name := fkey.column_name;

    -- Defensive: ensure we have a column name
    IF column_name IS NULL THEN
        CONTINUE;
    END IF;

    EXECUTE format('DELETE FROM %s WHERE %I = ANY ($1)', child_table, column_name)
    USING booking_ids;
END LOOP;

DELETE FROM bookings WHERE id = ANY (booking_ids);
END;
$_$;


ALTER FUNCTION "public"."cleanup_old_unconfirmed_bookings"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_booking"("cart" "jsonb", "user_data" "jsonb", "p_session_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
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
  v_offering_id uuid;
  v_price_per_night numeric;
  v_ticket_number text := 'BK-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 999999)::text, 6, '0');
  v_json jsonb;
  v_previous_booking_ids uuid[];
begin
  ---------------------------------------------------------------------------
  -- 1. CLEANUP: Release holds from this specific session (The Retry Fix)
  ---------------------------------------------------------------------------
  -- Find any previous bookings by this session that are still 'pending'
  select array_agg(id) into v_previous_booking_ids
  from bookings 
  where session_id = p_session_id 
  and status = 'pending';

  if v_previous_booking_ids is not null then
    -- Clear room locks for the previous attempt
    delete from room_statuses 
    where booking_id = any(v_previous_booking_ids);

    -- Mark previous booking as abandoned
    update bookings 
    set status = 'abandoned' 
    where id = any(v_previous_booking_ids);
  end if;

  ---------------------------------------------------------------------------
  -- 2. VALIDATION & PRICING
  ---------------------------------------------------------------------------
  for v_cart_item in select * from jsonb_array_elements(cart)
  loop
    v_hotel_id := (v_cart_item ->> 'hotel_id')::uuid;
    v_start := (v_cart_item ->> 'start_date')::date;
    v_end := (v_cart_item ->> 'end_date')::date;

    for v_item in select * from jsonb_array_elements(v_cart_item -> 'items')
    loop
      v_room_id := (v_item ->> 'room_id')::uuid;
      v_offering_id := (v_item ->> 'offering_id')::uuid;

      -- Get price
      select price into v_price_per_night
      from offerings
      where id = v_offering_id;

      if v_price_per_night is null then
        raise exception 'Invalid offering ID: %', v_offering_id;
      end if;

      -- Check availability (ignoring our own just-cleared holds)
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

  -- Return conflicts if any
  if jsonb_array_length(v_conflicts) > 0 then
    return jsonb_build_object(
      'success', false,
      'message', 'Some rooms are already booked for the selected dates.',
      'conflicts', v_conflicts
    );
  end if;

  ---------------------------------------------------------------------------
  -- 3. INSERT BOOKING & ITEMS
  ---------------------------------------------------------------------------
  insert into public.bookings (
    id, customer_name, customer_email, customer_phone, 
    total_price, ticket_number, status, payment_status, session_id
  )
  values (
    v_booking_id,
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

  ---------------------------------------------------------------------------
  -- 4. BUILD RESPONSE (Your Specific Format)
  ---------------------------------------------------------------------------
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
              -- Fix: Use 'cart_item' (the SQL alias), not 'v_cart_item' (the loop variable)
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
    'payment_status', (select payment_status from bookings where id = v_booking_id::uuid)
  );

  return jsonb_build_object(
    'success', true,
    'booking', v_json
  );
end;
$$;


ALTER FUNCTION "public"."create_booking"("cart" "jsonb", "user_data" "jsonb", "p_session_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."hotel_rooms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "hotel_id" "uuid",
    "offering_id" "uuid",
    "room_number" "text",
    "description" "text",
    "capacity" integer,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."hotel_rooms" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_available_rooms"("p_hotel_id" "uuid", "p_offering_id" "uuid", "p_start" "date", "p_end" "date") RETURNS SETOF "public"."hotel_rooms"
    LANGUAGE "sql"
    AS $$
  select r.*
  from hotel_rooms r
  where
    r.hotel_id = p_hotel_id
    and r.offering_id = p_offering_id
    and r.is_active = true
    and not exists (
      select 1
      from room_statuses s
      join generate_series(p_start, p_end - interval '1 day', interval '1 day') g(day)
        on s.date = g.day::date
      where s.room_id = r.id
        and s.status in ('booked', 'pending', 'not_available')
    )
  order by r.room_number;
$$;


ALTER FUNCTION "public"."get_available_rooms"("p_hotel_id" "uuid", "p_offering_id" "uuid", "p_start" "date", "p_end" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_booking_details"("p_booking_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$declare
  v_booking record;
  v_json jsonb;
begin
  -- Fetch booking
  select *
  into v_booking
  from public.bookings
  where id = p_booking_id;

  if not found then
    return jsonb_build_object(
      'success', false,
      'message', 'Booking not found'
    );
  end if;

  v_json := jsonb_build_object(
    'id', v_booking.id,
    'user_data', jsonb_build_object(
      'name', v_booking.customer_name,
      'email', v_booking.customer_email,
      'phone', v_booking.customer_phone
    ),
    'cart', (
      select jsonb_agg(
        jsonb_build_object(
          'hotel', (
            select row_to_json(h)
            from (
              select id, name, description, address, rating, images
              from hotels
              where id = bi.hotel_id
            ) h
          ),
          'start_date', bi.start_date,
          'end_date', bi.end_date,
          'items', (
            select jsonb_agg(
              jsonb_build_object(
                'offering', (
                  select row_to_json(o)
                  from (
                    select id, title, price, description, max_guests
                    from offerings
                    where id = bi2.offering_id
                  ) o
                ),
                'room', (
                  select row_to_json(r)
                  from (
                    select id, room_number, description, capacity, is_active, offering_id, hotel_id
                    from hotel_rooms
                    where id = bi2.room_id
                  ) r
                ),
                'price_per_night', bi2.price_per_night
              )
            )
            from booking_items bi2
            where bi2.booking_id = v_booking.id
              and bi2.hotel_id = bi.hotel_id
              and bi2.start_date = bi.start_date
              and bi2.end_date = bi.end_date
          )
        )
      )
      from booking_items bi
      where bi.booking_id = v_booking.id
      group by bi.hotel_id, bi.start_date, bi.end_date
    ),
    'ticket_number', v_booking.ticket_number,
    'total_price', v_booking.total_price,
    'status', v_booking.status,
    'payment_status', v_booking.payment_status,
    'created_at', v_booking.created_at,
    'expires_at', v_booking.created_at + interval '15 minutes'
  );

  return jsonb_build_object(
    'success', true,
    'booking', v_json
  );
end;$$;


ALTER FUNCTION "public"."get_booking_details"("p_booking_id" "uuid") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."hotels" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "manager_user_id" "uuid",
    "location" "extensions"."geography"(Point,4326),
    "address" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "images" character varying,
    "rating" real,
    "total_rooms" integer,
    "region" "text",
    "city" "text",
    "country" "text",
    "phone_number" "text",
    "email" "text",
    "website" "text",
    "lat" double precision GENERATED ALWAYS AS ("extensions"."st_y"(("location")::"extensions"."geometry")) STORED,
    "lng" double precision GENERATED ALWAYS AS ("extensions"."st_x"(("location")::"extensions"."geometry")) STORED,
    "search_vector" "tsvector" GENERATED ALWAYS AS (((((("setweight"("to_tsvector"('"simple"'::"regconfig", COALESCE("name", ''::"text")), 'A'::"char") || "setweight"("to_tsvector"('"simple"'::"regconfig", COALESCE("address", ''::"text")), 'B'::"char")) || "setweight"("to_tsvector"('"simple"'::"regconfig", COALESCE("city", ''::"text")), 'B'::"char")) || "setweight"("to_tsvector"('"simple"'::"regconfig", COALESCE("region", ''::"text")), 'C'::"char")) || "setweight"("to_tsvector"('"simple"'::"regconfig", COALESCE("country", ''::"text")), 'C'::"char")) || "setweight"("to_tsvector"('"simple"'::"regconfig", COALESCE("description", ''::"text")), 'D'::"char"))) STORED
);


ALTER TABLE "public"."hotels" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_hotels_in_bounding_box"("north" double precision, "south" double precision, "east" double precision, "west" double precision) RETURNS SETOF "public"."hotels"
    LANGUAGE "plpgsql" STABLE
    AS $$
begin
    return query
    select *
    from public.hotels
    where st_contains(st_makeenvelope(west, south, east, north, 4326), location::geometry);
end;
$$;


ALTER FUNCTION "public"."get_hotels_in_bounding_box"("north" double precision, "south" double precision, "east" double precision, "west" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_manager_deletion"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Delete hotels owned by this manager
  -- This will further cascade to 'rooms' if you have 'ON DELETE CASCADE' on your foreign keys
  DELETE FROM public.hotels WHERE manager_id = OLD.id;
  RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."handle_manager_deletion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  user_role_id uuid;
begin
  -- Get the role name from the user's metadata (passed during signup)
  --the default role is 'authenticated' if not provider_id
  -- The _>> operator extracts the value as string

  -- Find the role_id from the public.roles table
  select id into user_role_id
  from public.roles
  where name = new.raw_user_meta_data->>'role'
  limit 1;

  -- If a matching role_id is found, insert it into the user_roles table
  if user_role_id is not null then
    insert into public.user_roles(user_id, role_id)
    values (new.id, user_role_id);
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_hotels_advanced"("search_query" "text" DEFAULT ''::"text", "region_filter" "text" DEFAULT ''::"text", "city_filter" "text" DEFAULT ''::"text", "min_price" numeric DEFAULT NULL::numeric, "max_price" numeric DEFAULT NULL::numeric, "guests" integer DEFAULT NULL::integer, "start_date" "date" DEFAULT NULL::"date", "end_date" "date" DEFAULT NULL::"date", "sort_option" "text" DEFAULT 'relevance'::"text", "limit_count" integer DEFAULT 20, "offset_count" integer DEFAULT 0) RETURNS TABLE("hotel_id" "uuid", "hotel_name" "text", "hotel_address" "text", "city" "text", "region" "text", "country" "text", "rating" numeric, "images" character varying, "available_rooms" integer, "cheapest_price" numeric, "relevance" numeric)
    LANGUAGE "sql"
    AS $$WITH matched_hotels AS (
    SELECT
        h.*,
        (
            0.5 * ts_rank(h.search_vector, plainto_tsquery('simple', search_query)) +
            0.3 * similarity(h.name, search_query) +
            0.2 * similarity(h.address, search_query)
        ) AS relevance
    FROM hotels h
    WHERE
        (
            search_query IS NULL OR search_query = '' OR
            h.search_vector @@ plainto_tsquery('simple', search_query) OR
            h.name ILIKE '%' || search_query || '%' OR
            h.address ILIKE '%' || search_query || '%' OR
            h.name % search_query OR
            h.address % search_query
        )
        AND (
            region_filter = '' OR region_filter IS NULL OR
            h.region ILIKE '%' || region_filter || '%'
        )
        AND (
            city_filter = '' OR city_filter IS NULL OR
            h.city ILIKE '%' || city_filter || '%'
        )
),

matched_offerings AS (
    SELECT o.*
    FROM offerings o
    WHERE (min_price IS NULL OR o.price >= min_price)
      AND (max_price IS NULL OR o.price <= max_price)
      AND (guests IS NULL OR o.max_guests >= guests)
),

available_rooms AS (
    SELECT
        hr.hotel_id,
        COUNT(*) AS available_count
    FROM hotel_rooms hr
    LEFT JOIN room_statuses rs
        ON rs.room_id = hr.id
        AND rs.status IN ('booked', 'pending', 'not_available')
        AND rs.date BETWEEN COALESCE(start_date, rs.date)
                        AND COALESCE(end_date, rs.date)
    WHERE rs.id IS NULL
    GROUP BY hr.hotel_id
),

cheapest_prices AS (
    SELECT
        o.hotel_id,
        MIN(o.price) AS cheapest_price
    FROM matched_offerings o
    GROUP BY o.hotel_id
),

base_result AS (
    SELECT
        mh.id AS hotel_id,
        mh.name AS hotel_name,
        mh.address AS hotel_address,
        mh.city AS city,
        mh.region AS region,
        mh.country AS country,
        mh.rating::numeric AS rating,
        mh.images AS images,
        COALESCE(ar.available_count, 0)::integer AS available_rooms,
        cp.cheapest_price AS cheapest_price,
        mh.relevance::numeric AS relevance
    FROM matched_hotels mh
    LEFT JOIN cheapest_prices cp ON cp.hotel_id = mh.id
    LEFT JOIN available_rooms ar ON ar.hotel_id = mh.id
    WHERE cp.cheapest_price IS NOT NULL
)

SELECT *
FROM base_result
ORDER BY
    CASE WHEN sort_option = 'price_asc' THEN cheapest_price END ASC,
    CASE WHEN sort_option = 'price_desc' THEN cheapest_price END DESC,
    CASE WHEN sort_option = 'rating_asc' THEN rating END ASC,
    CASE WHEN sort_option = 'rating_desc' THEN rating END DESC,
    CASE WHEN sort_option = 'rooms_asc' THEN available_rooms END ASC,
    CASE WHEN sort_option = 'rooms_desc' THEN available_rooms END DESC,
    CASE WHEN sort_option = 'name_asc' THEN hotel_name END ASC,
    CASE WHEN sort_option = 'name_desc' THEN hotel_name END DESC,
    CASE WHEN sort_option = 'relevance' THEN relevance END DESC,
    hotel_id ASC
LIMIT limit_count
OFFSET offset_count;$$;


ALTER FUNCTION "public"."search_hotels_advanced"("search_query" "text", "region_filter" "text", "city_filter" "text", "min_price" numeric, "max_price" numeric, "guests" integer, "start_date" "date", "end_date" "date", "sort_option" "text", "limit_count" integer, "offset_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_payments_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."update_payments_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_room_statuses"("p_room_id" "uuid", "p_status" "text", "p_note" "text" DEFAULT NULL::"text", "p_start_date" "date" DEFAULT NULL::"date", "p_end_date" "date" DEFAULT NULL::"date", "p_dates" "date"[] DEFAULT NULL::"date"[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
    v_dates date[];
begin
    -- Determine the dates to process
    if p_dates is not null then
        -- Explicit list of dates
        v_dates := p_dates;
    elsif p_start_date is not null and p_end_date is not null then
        -- Date range
        select array_agg(d) into v_dates
        from generate_series(p_start_date, p_end_date, '1 day'::interval) as d;
    elsif p_start_date is not null then
        -- Single date
        v_dates := array[p_start_date];
    else
        raise exception 'No valid date(s) provided';
    end if;

    -- Optional: remove existing statuses for these dates
    delete from public.room_statuses
    where room_id = p_room_id
      and date = any(v_dates);

    -- Insert new statuses
    insert into public.room_statuses (room_id, status, note, date)
    select p_room_id, p_status, p_note, unnest(v_dates);

end;
$$;


ALTER FUNCTION "public"."upsert_room_statuses"("p_room_id" "uuid", "p_status" "text", "p_note" "text", "p_start_date" "date", "p_end_date" "date", "p_dates" "date"[]) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."amenities" (
    "amenity_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "category" "public"."amenity_category" NOT NULL,
    "short_description" "text",
    "detailed_description" "text",
    "availability_status" "public"."amenity_availability_status" NOT NULL,
    "operating_hours" "text",
    "seasonal_dates" "text",
    "cost_type" "public"."amenity_cost_type" NOT NULL,
    "cost_amount" numeric(10,2),
    "currency" "text",
    "location_description" "text",
    "capacity" integer,
    "requirements_restrictions" "text",
    "specifications" "jsonb",
    "icon_url" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "amenities_currency_check" CHECK (("char_length"("currency") = 3))
);


ALTER TABLE "public"."amenities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."azampay_tokens" (
    "id" integer NOT NULL,
    "token" "text" NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."azampay_tokens" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."azampay_tokens_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."azampay_tokens_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."azampay_tokens_id_seq" OWNED BY "public"."azampay_tokens"."id";



CREATE TABLE IF NOT EXISTS "public"."booking_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid",
    "room_id" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "start_date" "date",
    "end_date" "date",
    "hotel_id" "uuid",
    "offering_id" "uuid",
    "price_per_night" bigint
);


ALTER TABLE "public"."booking_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bookings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "hotel_id" "uuid",
    "customer_name" "text",
    "customer_phone" "text",
    "customer_email" "text",
    "total_price" numeric(10,2),
    "status" "text",
    "payment_status" "text",
    "payment_type" "text",
    "receipt_url" "text",
    "ticket_number" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "session_id" "uuid"
);


ALTER TABLE "public"."bookings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."financial_ledger" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "hotel_id" "uuid",
    "type" "text",
    "amount" numeric(10,2),
    "source" "text",
    "reference_id" "uuid",
    "description" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."financial_ledger" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."hotel_amenities" (
    "amenity_id" "uuid" NOT NULL,
    "hotel_id" "uuid" NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "public"."hotel_amenities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."offerings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "hotel_id" "uuid",
    "title" "text" NOT NULL,
    "description" "text",
    "price" numeric(10,2) NOT NULL,
    "max_guests" integer,
    "is_available" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."offerings" OWNER TO "postgres";


CREATE MATERIALIZED VIEW "public"."hotel_min_price" AS
 SELECT "hotel_id",
    "min"("price") AS "min_price"
   FROM "public"."offerings"
  GROUP BY "hotel_id"
  WITH NO DATA;


ALTER MATERIALIZED VIEW "public"."hotel_min_price" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "amount" numeric(10,2) NOT NULL,
    "external_id" "text",
    "currency" "text" DEFAULT 'TZS'::"text",
    "checkout_url" "text",
    "payment_gateway_ref" "text",
    "metadata" "jsonb",
    "azampay_response" "jsonb",
    "type" "text",
    "status" "text" DEFAULT 'pending'::"text",
    "verified_by" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "idempotency_key" "text"
);


ALTER TABLE "public"."payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."settlements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "payment_id" "uuid" NOT NULL,
    "booking_item_id" "uuid" NOT NULL,
    "hotel_id" "uuid" NOT NULL,
    "amount_allocated" numeric(10,2) NOT NULL,
    "status" "text" DEFAULT 'pending'::"text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."settlements" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."hotel_payment_report" AS
 SELECT "h"."id" AS "hotel_id",
    "b"."customer_name",
    "b"."customer_phone",
    "bi"."room_id",
    "bi"."start_date" AS "check_in",
    "bi"."end_date" AS "check_out",
    ("bi"."end_date" - "bi"."start_date") AS "nights",
    (("bi"."end_date" - "bi"."start_date") * "bi"."price_per_night") AS "calculated_total",
    "p"."status" AS "payment_status",
    "p"."payment_gateway_ref",
    "s"."amount_allocated" AS "amount_settled",
    "s"."created_at" AS "settled_at"
   FROM (((("public"."settlements" "s"
     JOIN "public"."booking_items" "bi" ON (("s"."booking_item_id" = "bi"."id")))
     JOIN "public"."bookings" "b" ON (("bi"."booking_id" = "b"."id")))
     JOIN "public"."payments" "p" ON (("s"."payment_id" = "p"."id")))
     JOIN "public"."hotels" "h" ON (("s"."hotel_id" = "h"."id")));


ALTER VIEW "public"."hotel_payment_report" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."hotel_payments_view" AS
 SELECT "p"."id" AS "payment_id",
    "p"."amount",
    "p"."currency",
    "p"."status" AS "payment_status",
    "p"."type" AS "payment_type",
    "p"."external_id",
    "p"."payment_gateway_ref",
    "p"."created_at" AS "payment_created_at",
    "p"."updated_at" AS "payment_updated_at",
    "p"."metadata" AS "payment_metadata",
    "p"."azampay_response",
    "p"."verified_by",
    "b"."id" AS "booking_id",
    "b"."hotel_id",
    "b"."ticket_number",
    "b"."customer_name",
    "b"."customer_phone",
    "b"."customer_email",
    "b"."total_price" AS "booking_total_price",
    "b"."status" AS "booking_status"
   FROM ("public"."payments" "p"
     JOIN "public"."bookings" "b" ON (("p"."booking_id" = "b"."id")));


ALTER VIEW "public"."hotel_payments_view" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."manager_hotel_payments_view" AS
 SELECT "s"."id" AS "settlement_id",
    "s"."hotel_id",
    "s"."amount_allocated" AS "settled_amount",
    "s"."status" AS "settlement_status",
    "s"."created_at" AS "settled_at",
    "bi"."id" AS "booking_item_id",
    "hr"."room_number",
    "bi"."price_per_night",
    "bi"."start_date",
    "bi"."end_date",
    ("bi"."end_date" - "bi"."start_date") AS "total_nights",
    "b"."id" AS "booking_id",
    "b"."customer_name",
    "b"."customer_phone",
    "b"."customer_email",
    "b"."ticket_number",
    "p"."id" AS "payment_id",
    "p"."status" AS "payment_status",
    "p"."payment_gateway_ref",
    "p"."external_id",
    "p"."type" AS "payment_method"
   FROM (((("public"."settlements" "s"
     JOIN "public"."booking_items" "bi" ON (("s"."booking_item_id" = "bi"."id")))
     JOIN "public"."hotel_rooms" "hr" ON (("bi"."room_id" = "hr"."id")))
     JOIN "public"."bookings" "b" ON (("bi"."booking_id" = "b"."id")))
     JOIN "public"."payments" "p" ON (("s"."payment_id" = "p"."id")));


ALTER VIEW "public"."manager_hotel_payments_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."offering_amenities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "offering_id" "uuid",
    "amenity_id" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."offering_amenities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payment_logs" (
    "id" integer NOT NULL,
    "level" "text",
    "message" "text",
    "payload" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "booking_id" "uuid"
);


ALTER TABLE "public"."payment_logs" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."payment_logs_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."payment_logs_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."payment_logs_id_seq" OWNED BY "public"."payment_logs"."id";



CREATE TABLE IF NOT EXISTS "public"."reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "hotel_id" "uuid",
    "report_type" "text",
    "report_url" "text",
    "generated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid",
    "rating" integer,
    "comment" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."roles" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL
);


ALTER TABLE "public"."roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."room_statuses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "room_id" "uuid",
    "date" "date",
    "status" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "booking_id" "uuid",
    "note" "text"
);


ALTER TABLE "public"."room_statuses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "hotel_id" "uuid",
    "name" "text" NOT NULL,
    "email" "text",
    "phone" "text",
    "role" "text",
    "is_active" boolean DEFAULT true,
    "user_id" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."staff" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_roles" (
    "user_id" "uuid" NOT NULL,
    "role_id" "uuid" NOT NULL
);


ALTER TABLE "public"."user_roles" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."user_roles_view" AS
 SELECT "ur"."user_id",
    "r"."name" AS "role"
   FROM ("public"."user_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."role_id" = "r"."id")));


ALTER VIEW "public"."user_roles_view" OWNER TO "postgres";


ALTER TABLE ONLY "public"."azampay_tokens" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."azampay_tokens_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."payment_logs" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."payment_logs_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."amenities"
    ADD CONSTRAINT "amenities_pkey" PRIMARY KEY ("amenity_id");



ALTER TABLE ONLY "public"."azampay_tokens"
    ADD CONSTRAINT "azampay_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."booking_items"
    ADD CONSTRAINT "booking_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_ticket_number_key" UNIQUE ("ticket_number");



ALTER TABLE ONLY "public"."financial_ledger"
    ADD CONSTRAINT "financial_ledger_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."hotel_amenities"
    ADD CONSTRAINT "hotel_amenities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."hotel_rooms"
    ADD CONSTRAINT "hotel_rooms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."hotels"
    ADD CONSTRAINT "hotels_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."offering_amenities"
    ADD CONSTRAINT "offering_amenities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."offerings"
    ADD CONSTRAINT "offerings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payment_logs"
    ADD CONSTRAINT "payment_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_external_id_key" UNIQUE ("external_id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_idempotency_key_key" UNIQUE ("idempotency_key");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."room_statuses"
    ADD CONSTRAINT "room_statuses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."settlements"
    ADD CONSTRAINT "settlements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff"
    ADD CONSTRAINT "staff_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff"
    ADD CONSTRAINT "staff_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_pkey" PRIMARY KEY ("user_id", "role_id");



CREATE UNIQUE INDEX "hotel_min_price_hotel_id_idx" ON "public"."hotel_min_price" USING "btree" ("hotel_id");



CREATE INDEX "hotel_search_idx" ON "public"."hotels" USING "gin" ("search_vector");



CREATE INDEX "idx_bookings_hotel_created" ON "public"."bookings" USING "btree" ("hotel_id", "created_at");



CREATE INDEX "idx_bookings_session_status" ON "public"."bookings" USING "btree" ("session_id", "status");



CREATE INDEX "idx_payments_booking_id" ON "public"."payments" USING "btree" ("booking_id");



CREATE INDEX "idx_payments_external_id" ON "public"."payments" USING "btree" ("external_id");



CREATE INDEX "idx_payments_status_created" ON "public"."payments" USING "btree" ("status", "created_at");



CREATE INDEX "idx_room_statuses_room_date" ON "public"."room_statuses" USING "btree" ("room_id", "date");



CREATE INDEX "idx_room_statuses_room_date_status" ON "public"."room_statuses" USING "btree" ("room_id", "date", "status");



CREATE OR REPLACE TRIGGER "trg_update_payments_timestamp" BEFORE UPDATE ON "public"."payments" FOR EACH ROW EXECUTE FUNCTION "public"."update_payments_timestamp"();



CREATE OR REPLACE TRIGGER "update_amenities_updated_at" BEFORE UPDATE ON "public"."amenities" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."booking_items"
    ADD CONSTRAINT "booking_items_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id");



ALTER TABLE ONLY "public"."booking_items"
    ADD CONSTRAINT "booking_items_hotel_id_fkey" FOREIGN KEY ("hotel_id") REFERENCES "public"."hotels"("id");



ALTER TABLE ONLY "public"."booking_items"
    ADD CONSTRAINT "booking_items_offering_id_fkey" FOREIGN KEY ("offering_id") REFERENCES "public"."offerings"("id");



ALTER TABLE ONLY "public"."booking_items"
    ADD CONSTRAINT "booking_items_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "public"."hotel_rooms"("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_hotel_id_fkey" FOREIGN KEY ("hotel_id") REFERENCES "public"."hotels"("id");



ALTER TABLE ONLY "public"."financial_ledger"
    ADD CONSTRAINT "financial_ledger_hotel_id_fkey" FOREIGN KEY ("hotel_id") REFERENCES "public"."hotels"("id");



ALTER TABLE ONLY "public"."hotel_amenities"
    ADD CONSTRAINT "hotel_amenities_amenity_id_fkey" FOREIGN KEY ("amenity_id") REFERENCES "public"."amenities"("amenity_id");



ALTER TABLE ONLY "public"."hotel_amenities"
    ADD CONSTRAINT "hotel_amenities_hotel_id_fkey" FOREIGN KEY ("hotel_id") REFERENCES "public"."hotels"("id");



ALTER TABLE ONLY "public"."hotel_rooms"
    ADD CONSTRAINT "hotel_rooms_hotel_id_fkey" FOREIGN KEY ("hotel_id") REFERENCES "public"."hotels"("id");



ALTER TABLE ONLY "public"."hotel_rooms"
    ADD CONSTRAINT "hotel_rooms_offering_id_fkey" FOREIGN KEY ("offering_id") REFERENCES "public"."offerings"("id");



ALTER TABLE ONLY "public"."hotels"
    ADD CONSTRAINT "hotels_manager_user_id_fkey" FOREIGN KEY ("manager_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."offering_amenities"
    ADD CONSTRAINT "offering_amenities_amenity_id_fkey" FOREIGN KEY ("amenity_id") REFERENCES "public"."amenities"("amenity_id");



ALTER TABLE ONLY "public"."offering_amenities"
    ADD CONSTRAINT "offering_amenities_offering_id_fkey" FOREIGN KEY ("offering_id") REFERENCES "public"."offerings"("id");



ALTER TABLE ONLY "public"."offerings"
    ADD CONSTRAINT "offerings_hotel_id_fkey" FOREIGN KEY ("hotel_id") REFERENCES "public"."hotels"("id");



ALTER TABLE ONLY "public"."payment_logs"
    ADD CONSTRAINT "payment_logs_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_verified_by_fkey" FOREIGN KEY ("verified_by") REFERENCES "public"."staff"("id");



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_hotel_id_fkey" FOREIGN KEY ("hotel_id") REFERENCES "public"."hotels"("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id");



ALTER TABLE ONLY "public"."room_statuses"
    ADD CONSTRAINT "room_statuses_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."room_statuses"
    ADD CONSTRAINT "room_statuses_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "public"."hotel_rooms"("id");



ALTER TABLE ONLY "public"."settlements"
    ADD CONSTRAINT "settlements_hotel_fkey" FOREIGN KEY ("hotel_id") REFERENCES "public"."hotels"("id");



ALTER TABLE ONLY "public"."settlements"
    ADD CONSTRAINT "settlements_item_fkey" FOREIGN KEY ("booking_item_id") REFERENCES "public"."booking_items"("id");



ALTER TABLE ONLY "public"."settlements"
    ADD CONSTRAINT "settlements_payment_fkey" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."staff"
    ADD CONSTRAINT "staff_hotel_id_fkey" FOREIGN KEY ("hotel_id") REFERENCES "public"."hotels"("id");



ALTER TABLE ONLY "public"."staff"
    ADD CONSTRAINT "staff_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "public"."roles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."bookings";






GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";




































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































GRANT ALL ON FUNCTION "public"."bookings_initiate"("user_data" "jsonb", "cart" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."bookings_initiate"("user_data" "jsonb", "cart" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."bookings_initiate"("user_data" "jsonb", "cart" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."bookings_initiate"("user_data" "jsonb", "cart" "jsonb", "total_price" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."bookings_initiate"("user_data" "jsonb", "cart" "jsonb", "total_price" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."bookings_initiate"("user_data" "jsonb", "cart" "jsonb", "total_price" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_old_unconfirmed_bookings"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_old_unconfirmed_bookings"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_old_unconfirmed_bookings"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_booking"("cart" "jsonb", "user_data" "jsonb", "p_session_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_booking"("cart" "jsonb", "user_data" "jsonb", "p_session_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_booking"("cart" "jsonb", "user_data" "jsonb", "p_session_id" "uuid") TO "service_role";



GRANT ALL ON TABLE "public"."hotel_rooms" TO "anon";
GRANT ALL ON TABLE "public"."hotel_rooms" TO "authenticated";
GRANT ALL ON TABLE "public"."hotel_rooms" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_available_rooms"("p_hotel_id" "uuid", "p_offering_id" "uuid", "p_start" "date", "p_end" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_available_rooms"("p_hotel_id" "uuid", "p_offering_id" "uuid", "p_start" "date", "p_end" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_available_rooms"("p_hotel_id" "uuid", "p_offering_id" "uuid", "p_start" "date", "p_end" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_booking_details"("p_booking_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_booking_details"("p_booking_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_booking_details"("p_booking_id" "uuid") TO "service_role";



GRANT ALL ON TABLE "public"."hotels" TO "anon";
GRANT ALL ON TABLE "public"."hotels" TO "authenticated";
GRANT ALL ON TABLE "public"."hotels" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_hotels_in_bounding_box"("north" double precision, "south" double precision, "east" double precision, "west" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."get_hotels_in_bounding_box"("north" double precision, "south" double precision, "east" double precision, "west" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_hotels_in_bounding_box"("north" double precision, "south" double precision, "east" double precision, "west" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_manager_deletion"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_manager_deletion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_manager_deletion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."search_hotels_advanced"("search_query" "text", "region_filter" "text", "city_filter" "text", "min_price" numeric, "max_price" numeric, "guests" integer, "start_date" "date", "end_date" "date", "sort_option" "text", "limit_count" integer, "offset_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."search_hotels_advanced"("search_query" "text", "region_filter" "text", "city_filter" "text", "min_price" numeric, "max_price" numeric, "guests" integer, "start_date" "date", "end_date" "date", "sort_option" "text", "limit_count" integer, "offset_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_hotels_advanced"("search_query" "text", "region_filter" "text", "city_filter" "text", "min_price" numeric, "max_price" numeric, "guests" integer, "start_date" "date", "end_date" "date", "sort_option" "text", "limit_count" integer, "offset_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_payments_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_payments_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_payments_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_room_statuses"("p_room_id" "uuid", "p_status" "text", "p_note" "text", "p_start_date" "date", "p_end_date" "date", "p_dates" "date"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_room_statuses"("p_room_id" "uuid", "p_status" "text", "p_note" "text", "p_start_date" "date", "p_end_date" "date", "p_dates" "date"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_room_statuses"("p_room_id" "uuid", "p_status" "text", "p_note" "text", "p_start_date" "date", "p_end_date" "date", "p_dates" "date"[]) TO "service_role";























































































GRANT ALL ON TABLE "public"."amenities" TO "anon";
GRANT ALL ON TABLE "public"."amenities" TO "authenticated";
GRANT ALL ON TABLE "public"."amenities" TO "service_role";



GRANT ALL ON TABLE "public"."azampay_tokens" TO "anon";
GRANT ALL ON TABLE "public"."azampay_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."azampay_tokens" TO "service_role";



GRANT ALL ON SEQUENCE "public"."azampay_tokens_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."azampay_tokens_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."azampay_tokens_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."booking_items" TO "anon";
GRANT ALL ON TABLE "public"."booking_items" TO "authenticated";
GRANT ALL ON TABLE "public"."booking_items" TO "service_role";



GRANT ALL ON TABLE "public"."bookings" TO "anon";
GRANT ALL ON TABLE "public"."bookings" TO "authenticated";
GRANT ALL ON TABLE "public"."bookings" TO "service_role";



GRANT ALL ON TABLE "public"."financial_ledger" TO "anon";
GRANT ALL ON TABLE "public"."financial_ledger" TO "authenticated";
GRANT ALL ON TABLE "public"."financial_ledger" TO "service_role";



GRANT ALL ON TABLE "public"."hotel_amenities" TO "anon";
GRANT ALL ON TABLE "public"."hotel_amenities" TO "authenticated";
GRANT ALL ON TABLE "public"."hotel_amenities" TO "service_role";



GRANT ALL ON TABLE "public"."offerings" TO "anon";
GRANT ALL ON TABLE "public"."offerings" TO "authenticated";
GRANT ALL ON TABLE "public"."offerings" TO "service_role";



GRANT ALL ON TABLE "public"."hotel_min_price" TO "anon";
GRANT ALL ON TABLE "public"."hotel_min_price" TO "authenticated";
GRANT ALL ON TABLE "public"."hotel_min_price" TO "service_role";



GRANT ALL ON TABLE "public"."payments" TO "anon";
GRANT ALL ON TABLE "public"."payments" TO "authenticated";
GRANT ALL ON TABLE "public"."payments" TO "service_role";



GRANT ALL ON TABLE "public"."settlements" TO "anon";
GRANT ALL ON TABLE "public"."settlements" TO "authenticated";
GRANT ALL ON TABLE "public"."settlements" TO "service_role";



GRANT ALL ON TABLE "public"."hotel_payment_report" TO "anon";
GRANT ALL ON TABLE "public"."hotel_payment_report" TO "authenticated";
GRANT ALL ON TABLE "public"."hotel_payment_report" TO "service_role";



GRANT ALL ON TABLE "public"."hotel_payments_view" TO "anon";
GRANT ALL ON TABLE "public"."hotel_payments_view" TO "authenticated";
GRANT ALL ON TABLE "public"."hotel_payments_view" TO "service_role";



GRANT ALL ON TABLE "public"."manager_hotel_payments_view" TO "anon";
GRANT ALL ON TABLE "public"."manager_hotel_payments_view" TO "authenticated";
GRANT ALL ON TABLE "public"."manager_hotel_payments_view" TO "service_role";



GRANT ALL ON TABLE "public"."offering_amenities" TO "anon";
GRANT ALL ON TABLE "public"."offering_amenities" TO "authenticated";
GRANT ALL ON TABLE "public"."offering_amenities" TO "service_role";



GRANT ALL ON TABLE "public"."payment_logs" TO "anon";
GRANT ALL ON TABLE "public"."payment_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."payment_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."payment_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."payment_logs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."reports" TO "anon";
GRANT ALL ON TABLE "public"."reports" TO "authenticated";
GRANT ALL ON TABLE "public"."reports" TO "service_role";



GRANT ALL ON TABLE "public"."reviews" TO "anon";
GRANT ALL ON TABLE "public"."reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."reviews" TO "service_role";



GRANT ALL ON TABLE "public"."roles" TO "anon";
GRANT ALL ON TABLE "public"."roles" TO "authenticated";
GRANT ALL ON TABLE "public"."roles" TO "service_role";



GRANT ALL ON TABLE "public"."room_statuses" TO "anon";
GRANT ALL ON TABLE "public"."room_statuses" TO "authenticated";
GRANT ALL ON TABLE "public"."room_statuses" TO "service_role";



GRANT ALL ON TABLE "public"."staff" TO "anon";
GRANT ALL ON TABLE "public"."staff" TO "authenticated";
GRANT ALL ON TABLE "public"."staff" TO "service_role";



GRANT ALL ON TABLE "public"."user_roles" TO "anon";
GRANT ALL ON TABLE "public"."user_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_roles" TO "service_role";



GRANT ALL ON TABLE "public"."user_roles_view" TO "anon";
GRANT ALL ON TABLE "public"."user_roles_view" TO "authenticated";
GRANT ALL ON TABLE "public"."user_roles_view" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";




























