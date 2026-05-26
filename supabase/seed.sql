-- Test password for every seeded auth user: SetLoop123!

with seed_users(id, email, display_name, role, city) as (
    values
        ('9a8a0e21-4b40-496b-9032-950baea3d6fa'::uuid, 'host@salanorte.setloop.test', 'Sala Norte', 'venue', 'Madrid'),
        ('15e1b845-8f2b-4ea9-8fa4-f54b3c0c7972'::uuid, 'host@eltaller.setloop.test', 'El Taller Live', 'venue', 'Barcelona'),
        ('b5c7619f-13a4-44b8-b0b8-699d89a21182'::uuid, 'host@clubprisma.setloop.test', 'Club Prisma', 'venue', 'Valencia'),
        ('7827a22a-38cb-4c02-8d2d-c0828c0d9e3c'::uuid, 'luna@example.com', 'Luna Roja', 'musician', 'Madrid'),
        ('5c0b2e72-fb1b-4664-955b-8a6c8f8cb437'::uuid, 'sara@example.com', 'Sara Valls', 'musician', 'Barcelona'),
        ('ee8d95c9-0d0d-45c7-9f33-08281c68fa26'::uuid, 'marcos@example.com', 'Marcos Vidal DJ Set', 'dj', 'Barcelona'),
        ('be2f12fd-5c33-4218-8f89-3d03008bae8f'::uuid, 'noa@example.com', 'NOA / VINYL', 'dj', 'Valencia')
)
insert into auth.users (
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
)
select
    id,
    'authenticated',
    'authenticated',
    email,
    extensions.crypt('SetLoop123!', extensions.gen_salt('bf')),
    now(),
    jsonb_build_object('provider', 'email', 'providers', array['email']),
    jsonb_build_object('display_name', display_name, 'role', role, 'city', city),
    now(),
    now()
from seed_users
on conflict (id) do update
set email = excluded.email,
    raw_user_meta_data = excluded.raw_user_meta_data,
    updated_at = now();

with seed_users(id, email) as (
    values
        ('9a8a0e21-4b40-496b-9032-950baea3d6fa'::uuid, 'host@salanorte.setloop.test'),
        ('15e1b845-8f2b-4ea9-8fa4-f54b3c0c7972'::uuid, 'host@eltaller.setloop.test'),
        ('b5c7619f-13a4-44b8-b0b8-699d89a21182'::uuid, 'host@clubprisma.setloop.test'),
        ('7827a22a-38cb-4c02-8d2d-c0828c0d9e3c'::uuid, 'luna@example.com'),
        ('5c0b2e72-fb1b-4664-955b-8a6c8f8cb437'::uuid, 'sara@example.com'),
        ('ee8d95c9-0d0d-45c7-9f33-08281c68fa26'::uuid, 'marcos@example.com'),
        ('be2f12fd-5c33-4218-8f89-3d03008bae8f'::uuid, 'noa@example.com')
)
insert into auth.identities (
    provider_id,
    user_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
)
select
    id::text,
    id,
    jsonb_build_object('sub', id::text, 'email', email, 'email_verified', true),
    'email',
    now(),
    now(),
    now()
from seed_users
on conflict (provider_id, provider) do nothing;

insert into public.profiles (
    id,
    email,
    display_name,
    role,
    city,
    venue_address,
    bio,
    genres,
    instruments,
    instrument_counts,
    venue_capacity,
    is_premium
)
values
    (
        '9a8a0e21-4b40-496b-9032-950baea3d6fa',
        'host@salanorte.setloop.test',
        'Sala Norte',
        'venue',
        'Madrid',
        'Calle Fuencarral 88',
        'Club mediano con agenda indie y electronica y equipo tecnico estable.',
        array['Indie', 'Pop'],
        array['House', 'Disco'],
        '{}'::jsonb,
        220,
        false
    ),
    (
        '15e1b845-8f2b-4ea9-8fa4-f54b3c0c7972',
        'host@eltaller.setloop.test',
        'El Taller Live',
        'venue',
        'Barcelona',
        'Carrer de la Industria 12',
        'Formato cercano para jazz, soul y proyectos hibridos.',
        array['Jazz', 'Soul', 'Acustico'],
        array[]::text[],
        '{}'::jsonb,
        140,
        false
    ),
    (
        'b5c7619f-13a4-44b8-b0b8-699d89a21182',
        'host@clubprisma.setloop.test',
        'Club Prisma',
        'venue',
        'Valencia',
        'Gran Via 14',
        'Programacion nocturna para DJs open format y house de fin de semana.',
        array[]::text[],
        array['House', 'Disco', 'Tech House', 'Open Format'],
        '{}'::jsonb,
        320,
        false
    ),
    (
        '7827a22a-38cb-4c02-8d2d-c0828c0d9e3c',
        'luna@example.com',
        'Luna Roja',
        'musician',
        'Madrid',
        null,
        'Trio indie pop con set de 60-90 minutos y equipo tecnico cerrado.',
        array['Indie', 'Pop'],
        array['Trio', 'Voz', 'Guitarra', 'Bateria'],
        '{}'::jsonb,
        null,
        true
    ),
    (
        '5c0b2e72-fb1b-4664-955b-8a6c8f8cb437',
        'sara@example.com',
        'Sara Valls',
        'musician',
        'Barcelona',
        null,
        'Soul y jazz en formato duo o banda reducida para salas y eventos.',
        array['Soul', 'Jazz'],
        array['Duo', 'Voz', 'Teclado'],
        '{}'::jsonb,
        null,
        false
    ),
    (
        'ee8d95c9-0d0d-45c7-9f33-08281c68fa26',
        'marcos@example.com',
        'Marcos Vidal DJ Set',
        'dj',
        'Barcelona',
        null,
        'DJ open format con foco en warm up, disco y house elegante.',
        array[]::text[],
        array['Open Format', 'CDJ', 'Controller'],
        '{}'::jsonb,
        null,
        false
    ),
    (
        'be2f12fd-5c33-4218-8f89-3d03008bae8f',
        'noa@example.com',
        'NOA / VINYL',
        'dj',
        'Valencia',
        null,
        'Selector en vinilo para sesiones disco, funk y club sets prolongados.',
        array[]::text[],
        array['Club Set', 'Vinilo', 'Hybrid'],
        '{}'::jsonb,
        null,
        true
    )
on conflict (id) do update
set email = excluded.email,
    display_name = excluded.display_name,
    role = excluded.role,
    city = excluded.city,
    venue_address = excluded.venue_address,
    bio = excluded.bio,
    genres = excluded.genres,
    instruments = excluded.instruments,
    instrument_counts = excluded.instrument_counts,
    venue_capacity = excluded.venue_capacity,
    is_premium = excluded.is_premium;

insert into public.venues (
    id,
    owner_id,
    name,
    city,
    address,
    capacity,
    description,
    genres,
    is_verified
)
values
    (
        'bfe14314-26b8-4c68-96d6-737ba6f53c16',
        '9a8a0e21-4b40-496b-9032-950baea3d6fa',
        'Sala Norte',
        'Madrid',
        'Calle Fuencarral 88',
        220,
        'Club mediano con agenda indie y electronica y equipo tecnico estable.',
        array['Indie', 'Pop', 'House', 'Disco'],
        true
    ),
    (
        '4d23dd03-081d-4f58-8a68-08e26f1d50c7',
        '15e1b845-8f2b-4ea9-8fa4-f54b3c0c7972',
        'El Taller Live',
        'Barcelona',
        'Carrer de la Industria 12',
        140,
        'Formato cercano para jazz, soul y proyectos hibridos.',
        array['Jazz', 'Soul', 'Acustico'],
        true
    ),
    (
        'b2dd8f89-bbf6-4c8d-8501-6cb9e3e82c2b',
        'b5c7619f-13a4-44b8-b0b8-699d89a21182',
        'Club Prisma',
        'Valencia',
        'Gran Via 14',
        320,
        'Programacion nocturna para DJs open format y house de fin de semana.',
        array['House', 'Disco', 'Tech House', 'Open Format'],
        true
    )
on conflict (id) do update
set owner_id = excluded.owner_id,
    name = excluded.name,
    city = excluded.city,
    address = excluded.address,
    capacity = excluded.capacity,
    description = excluded.description,
    genres = excluded.genres,
    is_verified = excluded.is_verified;

insert into public.gigs (
    id,
    venue_id,
    host_user_id,
    title,
    venue_name,
    city,
    performance_date,
    duration_minutes,
    budget_min,
    budget_max,
    currency,
    role_needed,
    required_genres,
    description,
    status
)
values
    (
        '44282c35-233b-4e98-93d5-8e2572dd1451',
        'bfe14314-26b8-4c68-96d6-737ba6f53c16',
        '9a8a0e21-4b40-496b-9032-950baea3d6fa',
        'Banda indie para viernes noche',
        'Sala Norte',
        'Madrid',
        date_trunc('day', now()) + interval '8 days 22 hours',
        75,
        450,
        700,
        'EUR',
        'musician',
        array['Indie', 'Pop'],
        'Buscamos banda con repertorio propio, prueba de sonido simple y actitud profesional.',
        'open'
    ),
    (
        'a7b54c32-3507-4ea4-927e-0a9967a858f1',
        'bfe14314-26b8-4c68-96d6-737ba6f53c16',
        '9a8a0e21-4b40-496b-9032-950baea3d6fa',
        'DJ selector para warm up de sabado',
        'Sala Norte',
        'Madrid',
        date_trunc('day', now()) + interval '15 days',
        90,
        180,
        260,
        'EUR',
        'dj',
        array['House', 'Disco'],
        'Buscamos DJ con criterio para warm up elegante y transicion a headliner.',
        'open'
    ),
    (
        'c8a0f81d-6e7c-45b3-bdf1-bd1a7309f22b',
        '4d23dd03-081d-4f58-8a68-08e26f1d50c7',
        '15e1b845-8f2b-4ea9-8fa4-f54b3c0c7972',
        'Trio soul para afterwork',
        'El Taller Live',
        'Barcelona',
        date_trunc('day', now()) + interval '12 days 20 hours',
        60,
        320,
        480,
        'EUR',
        'musician',
        array['Soul', 'Jazz'],
        'Set elegante para formato afterwork con montaje reducido.',
        'open'
    ),
    (
        'f24d0ac4-4f54-44d9-a6c8-9340d1651a7a',
        'b2dd8f89-bbf6-4c8d-8501-6cb9e3e82c2b',
        'b5c7619f-13a4-44b8-b0b8-699d89a21182',
        'Open format para noche de club',
        'Club Prisma',
        'Valencia',
        date_trunc('day', now()) + interval '18 days 1 hour',
        120,
        240,
        380,
        'EUR',
        'dj',
        array['Open Format', 'House'],
        'Sesion principal con cabina CDJ y tecnico de sala durante toda la noche.',
        'open'
    ),
    (
        '70ae1cc7-4d37-4c20-9bb4-6c9a9d13be38',
        '4d23dd03-081d-4f58-8a68-08e26f1d50c7',
        '15e1b845-8f2b-4ea9-8fa4-f54b3c0c7972',
        'Cantautor para ciclo acustico',
        'El Taller Live',
        'Barcelona',
        date_trunc('day', now()) + interval '4 days 21 hours',
        50,
        150,
        220,
        'EUR',
        'musician',
        array['Acustico', 'Pop'],
        'Fecha ya cerrada para validar estados.',
        'booked'
    )
on conflict (id) do update
set venue_id = excluded.venue_id,
    host_user_id = excluded.host_user_id,
    title = excluded.title,
    venue_name = excluded.venue_name,
    city = excluded.city,
    performance_date = excluded.performance_date,
    duration_minutes = excluded.duration_minutes,
    budget_min = excluded.budget_min,
    budget_max = excluded.budget_max,
    currency = excluded.currency,
    role_needed = excluded.role_needed,
    required_genres = excluded.required_genres,
    description = excluded.description,
    status = excluded.status;

insert into public.applications (
    id,
    gig_id,
    applicant_user_id,
    message
)
values
    (
        '27dd2d1f-600f-4db9-8d5b-9e455f53fd5e',
        '44282c35-233b-4e98-93d5-8e2572dd1451',
        '7827a22a-38cb-4c02-8d2d-c0828c0d9e3c',
        'Hola, encajamos con la fecha y podemos adaptar el set a 75 minutos.'
    ),
    (
        '8b44b7fd-b2e5-46b9-a6d9-cf208b58d28a',
        'c8a0f81d-6e7c-45b3-bdf1-bd1a7309f22b',
        '5c0b2e72-fb1b-4664-955b-8a6c8f8cb437',
        'Podemos llevar formato duo con voz y teclado para el afterwork.'
    )
on conflict (gig_id, applicant_user_id) do nothing;

insert into public.invites (
    id,
    gig_id,
    host_user_id,
    talent_user_id,
    message
)
values
    (
        '3eda55d1-f2eb-4ad0-bcf5-078d48de6841',
        'a7b54c32-3507-4ea4-927e-0a9967a858f1',
        '9a8a0e21-4b40-496b-9032-950baea3d6fa',
        'ee8d95c9-0d0d-45c7-9f33-08281c68fa26',
        'Nos interesa tu enfoque para el warm up. Si te encaja, compartimos briefing.'
    ),
    (
        '9392c5ac-8744-4272-82b4-dfb4461fa3ea',
        'f24d0ac4-4f54-44d9-a6c8-9340d1651a7a',
        'b5c7619f-13a4-44b8-b0b8-699d89a21182',
        'be2f12fd-5c33-4218-8f89-3d03008bae8f',
        'Buscamos una sesion de club con criterio disco y house. Te interesa?'
    )
on conflict (gig_id, host_user_id, talent_user_id) do nothing;

insert into public.reviews (
    id,
    reviewer_id,
    reviewee_id,
    gig_id,
    rating,
    comment
)
values
    (
        'e9860b6c-0286-4aa0-8e70-239e6578f38d',
        '9a8a0e21-4b40-496b-9032-950baea3d6fa',
        '7827a22a-38cb-4c02-8d2d-c0828c0d9e3c',
        '44282c35-233b-4e98-93d5-8e2572dd1451',
        5,
        'Llegaron preparados, buen trato y un directo muy solido.'
    ),
    (
        '69bfbc71-e722-4d0b-8998-6ebda61ebd4e',
        '15e1b845-8f2b-4ea9-8fa4-f54b3c0c7972',
        '7827a22a-38cb-4c02-8d2d-c0828c0d9e3c',
        null,
        4,
        'Comunicacion rapida y material promocional bien presentado.'
    ),
    (
        '35e130ef-dceb-43c0-a2d3-e53e85797e34',
        '9a8a0e21-4b40-496b-9032-950baea3d6fa',
        'ee8d95c9-0d0d-45c7-9f33-08281c68fa26',
        'a7b54c32-3507-4ea4-927e-0a9967a858f1',
        5,
        'Muy buen warm up y lectura de sala impecable.'
    ),
    (
        '7d889061-3190-4141-9644-b736e5c631fb',
        'ee8d95c9-0d0d-45c7-9f33-08281c68fa26',
        '9a8a0e21-4b40-496b-9032-950baea3d6fa',
        'a7b54c32-3507-4ea4-927e-0a9967a858f1',
        5,
        'Cabina cuidada, briefing claro y pago resuelto sin friccion.'
    )
on conflict (id) do update
set reviewer_id = excluded.reviewer_id,
    reviewee_id = excluded.reviewee_id,
    gig_id = excluded.gig_id,
    rating = excluded.rating,
    comment = excluded.comment;
