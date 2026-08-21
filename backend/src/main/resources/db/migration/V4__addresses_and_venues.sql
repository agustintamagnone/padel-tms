-- =====================================================================
-- V4 — Dirección y contacto del club; sede y canchas del torneo.
--      Address se modela como VALUE OBJECT: columnas inline con prefijo,
--      reutilizadas vía @Embeddable en el dominio (sin join, sin tabla aparte).
-- =====================================================================

ALTER TABLE organizations
    ADD COLUMN address_line1       TEXT          NULL,   -- calle y número
    ADD COLUMN address_line2       TEXT          NULL,   -- piso, depto, referencia
    ADD COLUMN address_city        TEXT          NULL,   -- localidad
    ADD COLUMN address_state       TEXT          NULL,   -- provincia
    ADD COLUMN address_postal_code TEXT          NULL,
    ADD COLUMN address_country     TEXT          NOT NULL DEFAULT 'AR',  -- ISO 3166-1 alpha-2
    ADD COLUMN address_latitude    NUMERIC(10,7) NULL,
    ADD COLUMN address_longitude   NUMERIC(10,7) NULL,
    ADD COLUMN contact_email       TEXT          NULL,
    ADD COLUMN contact_phone       TEXT          NULL,   -- E.164
    ADD COLUMN website_url         TEXT          NULL,
    ADD COLUMN updated_at          TIMESTAMPTZ   NOT NULL DEFAULT now();


-- Si la dirección del torneo queda vacía, se hereda la del club.
-- Por eso address_country acá es NULL y no tiene default: permite
-- distinguir "no tiene dirección propia" de "tiene dirección propia".
ALTER TABLE tournaments
    ADD COLUMN venue               TEXT          NULL,   -- "Padel Club Norte"
    ADD COLUMN courts_count        INT           NULL CHECK (courts_count > 0),
    ADD COLUMN address_line1       TEXT          NULL,
    ADD COLUMN address_line2       TEXT          NULL,
    ADD COLUMN address_city        TEXT          NULL,
    ADD COLUMN address_state       TEXT          NULL,
    ADD COLUMN address_postal_code TEXT          NULL,
    ADD COLUMN address_country     TEXT          NULL,
    ADD COLUMN address_latitude    NUMERIC(10,7) NULL,
    ADD COLUMN address_longitude   NUMERIC(10,7) NULL;