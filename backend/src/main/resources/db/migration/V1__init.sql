CREATE TABLE organizations (
                               id         UUID        PRIMARY KEY,
                               slug       TEXT        NOT NULL UNIQUE,
                               name       TEXT        NOT NULL,
                               timezone   TEXT        NOT NULL DEFAULT 'America/Argentina/Buenos_Aires',
                               locale     TEXT        NOT NULL DEFAULT 'es-AR',
                               settings   JSONB       NOT NULL DEFAULT '{}'::jsonb,
                               created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO organizations (id, slug, name)
VALUES ('00000000-0000-0000-0000-000000000001', 'repelentes', 'Los Repelentes');