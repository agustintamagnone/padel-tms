-- =====================================================================
-- 0. Normalización de la convención de nombres
-- =====================================================================

ALTER TABLE organizations RENAME COLUMN id TO org_id;


-- =====================================================================
-- 1. IDENTIDAD — cómo entrás al sistema. GLOBAL, sin org_id.
-- =====================================================================

CREATE TABLE users (
                       user_id       UUID        PRIMARY KEY,
                       email         TEXT        NOT NULL,          -- username
                       display_name  TEXT        NOT NULL,          -- nombre para mostrar por defecto
                       first_name    TEXT        NOT NULL,
                       last_name     TEXT        NOT NULL,
                       phone_number  TEXT        NULL,              -- E.164: +5491122334455
                       avatar_url    TEXT        NULL,
                       google_sub    TEXT        UNIQUE,            -- id estable de Google
                       last_login_at TIMESTAMPTZ NULL,
                       created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
                       updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_users_email ON users (lower(email));


-- =====================================================================
-- 2. PERTENENCIA — quién sos DENTRO de un club.
--    user_id NULL = jugador sin cuenta (invitado o importado del histórico)
-- =====================================================================

CREATE TABLE players (
                         player_id      UUID        PRIMARY KEY,
                         org_id         UUID        NOT NULL REFERENCES organizations (org_id),
                         user_id        UUID        NULL REFERENCES users (user_id) ON DELETE SET NULL,
                         display_name   TEXT        NOT NULL,   -- el apodo en ESTE club: "Agus"
                         role           TEXT        NOT NULL CHECK (role IN ('OWNER','ADMIN','MEMBER','GUEST')),
                         status         TEXT        NOT NULL DEFAULT 'ACTIVE'
                             CHECK (status IN ('ACTIVE','INACTIVE')),
                         preferred_side TEXT        NULL CHECK (preferred_side IN ('DRIVE','REVES','BOTH')),
                         skillful_hand  TEXT        NULL CHECK (skillful_hand IN ('LEFT','RIGHT','AMBIDEXTROUS')),
                         racket         TEXT        NULL,
                         favorite_player TEXT       NULL,
                         joined_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                         created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
                         updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),

                         UNIQUE (org_id, player_id),   -- blanco de las FKs compuestas
                         UNIQUE (org_id, user_id)      -- una persona = un player por club
);

CREATE INDEX idx_players_org ON players (org_id, status);


-- =====================================================================
-- 3. TORNEOS
--    DRAFT → REGISTRATION → PAIRING → IN_PROGRESS → FINISHED
-- =====================================================================

CREATE TABLE tournaments (
                             tournament_id UUID        PRIMARY KEY,
                             org_id        UUID        NOT NULL REFERENCES organizations (org_id),
                             name          TEXT        NOT NULL,
                             slug          TEXT        NOT NULL,
                             starts_at     TIMESTAMPTZ NOT NULL,
                             status        TEXT        NOT NULL CHECK (status IN
                                                                       ('DRAFT','REGISTRATION','PAIRING','IN_PROGRESS','FINISHED','CANCELLED')),
                             fee_cents     BIGINT      NULL,        -- costo de inscripción; NULL = gratis
                             currency      TEXT        NOT NULL DEFAULT 'ARS',
                             max_pairs     INT         NULL,        -- cupo; NULL = sin límite
                             config        JSONB       NOT NULL DEFAULT '{}'::jsonb,
                             created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
                             updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

                             UNIQUE (org_id, tournament_id),
                             UNIQUE (org_id, slug)
);

CREATE INDEX idx_tournaments_org_starts ON tournaments (org_id, starts_at DESC);


-- =====================================================================
-- 4. INSCRIPCIONES — la intención de jugar, con o sin pareja.
--    Es también donde se engancha el pago (por persona, no por pareja).
-- =====================================================================

CREATE TABLE registrations (
                               registration_id            UUID        PRIMARY KEY,
                               org_id                     UUID        NOT NULL,
                               tournament_id              UUID        NOT NULL,
                               player_id                  UUID        NOT NULL,
                               status                     TEXT        NOT NULL DEFAULT 'PENDING' CHECK (status IN
                                                                                                        ('PENDING','PAIRED','WAITLISTED','WITHDRAWN')),
                               preferred_partner_player_id UUID       NULL,   -- "quiero jugar con X"
                               payment_status             TEXT        NOT NULL DEFAULT 'NOT_REQUIRED'
                                   CHECK (payment_status IN
                                          ('NOT_REQUIRED','PENDING','PAID','WAIVED','REFUNDED')),
                               paid_at                    TIMESTAMPTZ NULL,
                               registered_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
                               updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),

                               UNIQUE (tournament_id, player_id),   -- no te podés anotar dos veces
                               FOREIGN KEY (org_id, tournament_id)
                                   REFERENCES tournaments (org_id, tournament_id) ON DELETE CASCADE,
                               FOREIGN KEY (org_id, player_id)
                                   REFERENCES players (org_id, player_id),
                               FOREIGN KEY (org_id, preferred_partner_player_id)
                                   REFERENCES players (org_id, player_id)
);

CREATE INDEX idx_registrations_tournament ON registrations (tournament_id, status);


-- =====================================================================
-- 5. PAREJAS
-- =====================================================================

CREATE TABLE pairs (
                       pair_id           UUID        PRIMARY KEY,
                       org_id            UUID        NOT NULL,
                       tournament_id     UUID        NOT NULL,
                       player_a_id       UUID        NOT NULL,   -- tier A (mejor nivel)
                       player_b_id       UUID        NOT NULL,   -- tier B
                       rating_a_snapshot INT         NOT NULL,   -- congelado: el Elo de ESE día
                       rating_b_snapshot INT         NOT NULL,
                       seed              INT         NULL,
                       display_name      TEXT        NOT NULL,   -- "Agus / Juan"
                       created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
                       updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

                       CHECK (player_a_id <> player_b_id),
                       UNIQUE (org_id, pair_id),
                       UNIQUE (tournament_id, player_a_id),
                       UNIQUE (tournament_id, player_b_id),
                       FOREIGN KEY (org_id, tournament_id)
                           REFERENCES tournaments (org_id, tournament_id) ON DELETE CASCADE,
                       FOREIGN KEY (org_id, player_a_id) REFERENCES players (org_id, player_id),
                       FOREIGN KEY (org_id, player_b_id) REFERENCES players (org_id, player_id)
);


-- =====================================================================
-- 6. ETAPAS — un torneo es una secuencia ordenada de etapas.
--    Tu formato del sábado = [GROUP, KNOCKOUT] = dos filas.
-- =====================================================================

CREATE TABLE stages (
                        stage_id      UUID        PRIMARY KEY,
                        org_id        UUID        NOT NULL,
                        tournament_id UUID        NOT NULL,
                        ordinal       INT         NOT NULL,   -- 0 = grupos, 1 = llave
                        type          TEXT        NOT NULL CHECK (type IN ('GROUP','KNOCKOUT')),
                        status        TEXT        NOT NULL DEFAULT 'PENDING'
                            CHECK (status IN ('PENDING','IN_PROGRESS','COMPLETED')),
                        match_rules   JSONB       NOT NULL,   -- {"scoringType":"SET_BASED","setsToWin":1,...}
                        tie_breaks    JSONB       NOT NULL DEFAULT '[]'::jsonb,
                        config        JSONB       NOT NULL DEFAULT '{}'::jsonb,
                        created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
                        updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

                        UNIQUE (org_id, stage_id),
                        UNIQUE (tournament_id, ordinal),
                        FOREIGN KEY (org_id, tournament_id)
                            REFERENCES tournaments (org_id, tournament_id) ON DELETE CASCADE
);


CREATE TABLE stage_groups (
                              group_id   UUID        PRIMARY KEY,
                              org_id     UUID        NOT NULL,
                              stage_id   UUID        NOT NULL,
                              name       TEXT        NOT NULL,   -- 'A', 'B'
                              ordinal    INT         NOT NULL,
                              created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

                              UNIQUE (org_id, group_id),
                              UNIQUE (stage_id, name),
                              FOREIGN KEY (org_id, stage_id) REFERENCES stages (org_id, stage_id) ON DELETE CASCADE
);


CREATE TABLE group_pairs (
                             org_id   UUID NOT NULL,
                             group_id UUID NOT NULL,
                             pair_id  UUID NOT NULL,

                             PRIMARY KEY (group_id, pair_id),
                             FOREIGN KEY (org_id, group_id) REFERENCES stage_groups (org_id, group_id) ON DELETE CASCADE,
                             FOREIGN KEY (org_id, pair_id)  REFERENCES pairs (org_id, pair_id) ON DELETE CASCADE
);


-- =====================================================================
-- 7. PARTIDOS
--    Los slots permiten dibujar la llave completa ANTES de que
--    existan los clasificados: "1° del grupo A" vs "2° del grupo B".
-- =====================================================================

CREATE TABLE matches (
                         match_id         UUID        PRIMARY KEY,
                         org_id           UUID        NOT NULL,
                         stage_id         UUID        NOT NULL,
                         group_id         UUID        NULL,   -- solo en fase de grupos
                         round            INT         NULL,   -- 0=cuartos, 1=semis... en llave
                         bracket_position INT         NULL,
                         home_slot        JSONB       NOT NULL,
                         away_slot        JSONB       NOT NULL,
                         home_pair_id     UUID        NULL,   -- se completa al resolver el slot
                         away_pair_id     UUID        NULL,
                         status           TEXT        NOT NULL DEFAULT 'PENDING' CHECK (status IN
                                                                                        ('PENDING','SCHEDULED','IN_PROGRESS','COMPLETED','WALKOVER','CANCELLED')),
                         court            TEXT        NULL,
                         play_order       INT         NOT NULL,
                         created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
                         updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

                         UNIQUE (org_id, match_id),
                         FOREIGN KEY (org_id, stage_id)     REFERENCES stages (org_id, stage_id) ON DELETE CASCADE,
                         FOREIGN KEY (org_id, group_id)     REFERENCES stage_groups (org_id, group_id),
                         FOREIGN KEY (org_id, home_pair_id) REFERENCES pairs (org_id, pair_id),
                         FOREIGN KEY (org_id, away_pair_id) REFERENCES pairs (org_id, pair_id)
);

CREATE INDEX idx_matches_stage_order ON matches (org_id, stage_id, play_order);
CREATE INDEX idx_matches_group       ON matches (org_id, group_id) WHERE group_id IS NOT NULL;


-- =====================================================================
-- 8. RESULTADOS — append-only. Corregir = insertar y supersedir.
--    Todo lo demás (tabla, llave, campeón, Elo) se DERIVA de acá.
-- =====================================================================

CREATE TABLE match_results (
                               match_result_id       UUID        PRIMARY KEY,
                               org_id                UUID        NOT NULL,
                               match_id              UUID        NOT NULL,
                               scoring_type          TEXT        NOT NULL DEFAULT 'SET_BASED',
                               payload               JSONB       NOT NULL,   -- {"sets":[{"home":6,"away":4}]}
                               outcome               TEXT        NOT NULL
                                   CHECK (outcome IN ('PLAYED','WALKOVER','CANCELLED')),
                               winner_pair_id        UUID        NULL,       -- NULL si se canceló sin ganador
                               home_score            INT         NOT NULL,   -- games hoy; puntos en Americano
                               away_score            INT         NOT NULL,
                               recorded_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
                               recorded_by_player_id UUID        NULL,
                               superseded_by_id      UUID        NULL REFERENCES match_results (match_result_id),

                               FOREIGN KEY (org_id, match_id)
                                   REFERENCES matches (org_id, match_id) ON DELETE CASCADE,
                               FOREIGN KEY (org_id, winner_pair_id)
                                   REFERENCES pairs (org_id, pair_id),
                               FOREIGN KEY (org_id, recorded_by_player_id)
                                   REFERENCES players (org_id, player_id)
);

-- Un único resultado VIGENTE por partido; el resto queda como historia auditable.
CREATE UNIQUE INDEX uq_match_results_active
    ON match_results (match_id) WHERE superseded_by_id IS NULL;

CREATE INDEX idx_match_results_match
    ON match_results (org_id, match_id, recorded_at DESC);