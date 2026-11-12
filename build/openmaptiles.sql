-- This SQL code should be executed first

CREATE OR REPLACE FUNCTION slice_language_tags(tags hstore)
RETURNS hstore AS $$
    SELECT delete_empty_keys(slice(tags, ARRAY['name:af', 'name:am', 'name:ar', 'name:az', 'name:be', 'name:bg', 'name:bn', 'name:br', 'name:bs', 'name:ca', 'name:co', 'name:cs', 'name:cy', 'name:da', 'name:de', 'name:el', 'name:en', 'name:eo', 'name:es', 'name:et', 'name:eu', 'name:fa', 'name:fi', 'name:fr', 'name:fy', 'name:ga', 'name:gd', 'name:he', 'name:hi', 'name:hr', 'name:hu', 'name:hy', 'name:id', 'name:is', 'name:it', 'name:ja', 'name:ja_kana', 'name:ja_rm', 'name:ja-Latn', 'name:ja-Hira', 'name:ka', 'name:kk', 'name:kn', 'name:ko', 'name:ko-Latn', 'name:ku', 'name:la', 'name:lb', 'name:lt', 'name:lv', 'name:mk', 'name:mt', 'name:ml', 'name:nl', 'name:no', 'name:oc', 'name:pa', 'name:pnb', 'name:pl', 'name:pt', 'name:rm', 'name:ro', 'name:ru', 'name:sk', 'name:sl', 'name:sq', 'name:sr', 'name:sr-Latn', 'name:sv', 'name:ta', 'name:te', 'name:th', 'name:tok', 'name:tr', 'name:uk', 'name:ur', 'name:vi', 'name:zh', 'name:zh-Hant', 'name:zh-Hans', 'int_name', 'loc_name', 'name', 'wikidata', 'wikipedia']))
$$ LANGUAGE SQL IMMUTABLE;

DO $$ BEGIN RAISE NOTICE 'Processing layer water'; END$$;

DO $$ BEGIN
    PERFORM 'ne_10m_lakes'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "water"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_10m_ocean'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "water"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_110m_lakes'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "water"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_110m_ocean'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "water"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_50m_lakes'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "water"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_50m_ocean'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "water"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'osm_ocean_polygon'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "water"';
END;
$$ LANGUAGE 'plpgsql';

-- Layer water - ./update_water.sql

-- Recreate ocean layer by union regular squares into larger polygons
-- etldoc: osm_ocean_polygon -> osm_ocean_polygon_union
CREATE TABLE IF NOT EXISTS osm_ocean_polygon_union AS
    (
    SELECT (ST_Dump(ST_Union(ST_MakeValid(geometry)))).geom::geometry(Polygon, 3857) AS geometry 
    FROM osm_ocean_polygon
    --for union select just full square (not big triangles)
    WHERE ST_Area(geometry) > 100000000 AND 
          ST_NPoints(geometry) = 5
    UNION ALL
    SELECT geometry 
    FROM osm_ocean_polygon
    -- as 321 records have less then 5 coordinates (triangle)
    -- bigger then 5 coordinates have squares with holes from island and coastline
    WHERE ST_NPoints(geometry) <> 5
    );

CREATE INDEX IF NOT EXISTS osm_ocean_polygon_union_geom_idx
  ON osm_ocean_polygon_union
  USING GIST (geometry);

--Drop data from original table but keep table as `CREATE TABLE IF NOT EXISTS` still test if query is valid
TRUNCATE TABLE osm_ocean_polygon;

-- This statement can be deleted after the water importer image stops creating this object as a table
DO
$$
    BEGIN
        DROP TABLE IF EXISTS osm_ocean_polygon_gen_z11 CASCADE;
    EXCEPTION
        WHEN wrong_object_type THEN
    END;
$$ LANGUAGE plpgsql;

-- etldoc: osm_ocean_polygon_union -> osm_ocean_polygon_gen_z11
DROP MATERIALIZED VIEW IF EXISTS osm_ocean_polygon_gen_z11 CASCADE;
CREATE MATERIALIZED VIEW osm_ocean_polygon_gen_z11 AS
(
SELECT ST_Simplify(geometry, ZRes(13)) AS geometry
FROM osm_ocean_polygon_union
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_ocean_polygon_gen_z11_idx ON osm_ocean_polygon_gen_z11 USING gist (geometry);


-- This statement can be deleted after the water importer image stops creating this object as a table
DO
$$
    BEGIN
        DROP TABLE IF EXISTS osm_ocean_polygon_gen_z10 CASCADE;
    EXCEPTION
        WHEN wrong_object_type THEN
    END;
$$ LANGUAGE plpgsql;

-- etldoc: osm_ocean_polygon_gen_z11 -> osm_ocean_polygon_gen_z10
DROP MATERIALIZED VIEW IF EXISTS osm_ocean_polygon_gen_z10 CASCADE;
CREATE MATERIALIZED VIEW osm_ocean_polygon_gen_z10 AS
(
SELECT ST_Simplify(geometry, ZRes(12)) AS geometry
FROM osm_ocean_polygon_gen_z11
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_ocean_polygon_gen_z10_idx ON osm_ocean_polygon_gen_z10 USING gist (geometry);


-- This statement can be deleted after the water importer image stops creating this object as a table
DO
$$
    BEGIN
        DROP TABLE IF EXISTS osm_ocean_polygon_gen_z9 CASCADE;
    EXCEPTION
        WHEN wrong_object_type THEN
    END;
$$ LANGUAGE plpgsql;

-- etldoc: osm_ocean_polygon_gen_z10 -> osm_ocean_polygon_gen_z9
DROP MATERIALIZED VIEW IF EXISTS osm_ocean_polygon_gen_z9 CASCADE;
CREATE MATERIALIZED VIEW osm_ocean_polygon_gen_z9 AS
(
SELECT ST_Simplify(geometry, ZRes(11)) AS geometry
FROM osm_ocean_polygon_gen_z10
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_ocean_polygon_gen_z9_idx ON osm_ocean_polygon_gen_z9 USING gist (geometry);


-- This statement can be deleted after the water importer image stops creating this object as a table
DO
$$
    BEGIN
        DROP TABLE IF EXISTS osm_ocean_polygon_gen_z8 CASCADE;
    EXCEPTION
        WHEN wrong_object_type THEN
    END;
$$ LANGUAGE plpgsql;

-- etldoc: osm_ocean_polygon_gen_z9 -> osm_ocean_polygon_gen_z8
DROP MATERIALIZED VIEW IF EXISTS osm_ocean_polygon_gen_z8 CASCADE;
CREATE MATERIALIZED VIEW osm_ocean_polygon_gen_z8 AS
(
SELECT ST_Simplify(geometry, ZRes(10)) AS geometry
FROM osm_ocean_polygon_gen_z9
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_ocean_polygon_gen_z8_idx ON osm_ocean_polygon_gen_z8 USING gist (geometry);


-- This statement can be deleted after the water importer image stops creating this object as a table
DO
$$
    BEGIN
        DROP TABLE IF EXISTS osm_ocean_polygon_gen_z7 CASCADE;
    EXCEPTION
        WHEN wrong_object_type THEN
    END;
$$ LANGUAGE plpgsql;

-- etldoc: osm_ocean_polygon_gen_z8 -> osm_ocean_polygon_gen_z7
DROP MATERIALIZED VIEW IF EXISTS osm_ocean_polygon_gen_z7 CASCADE;
CREATE MATERIALIZED VIEW osm_ocean_polygon_gen_z7 AS
(
SELECT ST_Simplify(geometry, ZRes(9)) AS geometry
FROM osm_ocean_polygon_gen_z8
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_ocean_polygon_gen_z7_idx ON osm_ocean_polygon_gen_z7 USING gist (geometry);


-- This statement can be deleted after the water importer image stops creating this object as a table
DO
$$
    BEGIN
        DROP TABLE IF EXISTS osm_ocean_polygon_gen_z6 CASCADE;
    EXCEPTION
        WHEN wrong_object_type THEN
    END;
$$ LANGUAGE plpgsql;

-- etldoc: osm_ocean_polygon_gen_z7 -> osm_ocean_polygon_gen_z6
DROP MATERIALIZED VIEW IF EXISTS osm_ocean_polygon_gen_z6 CASCADE;
CREATE MATERIALIZED VIEW osm_ocean_polygon_gen_z6 AS
(
SELECT ST_Simplify(geometry, ZRes(8)) AS geometry
FROM osm_ocean_polygon_gen_z7
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_ocean_polygon_gen_z6_idx ON osm_ocean_polygon_gen_z6 USING gist (geometry);

-- Layer water - ./water.sql

CREATE OR REPLACE FUNCTION water_class(waterway text, water text, leisure text) RETURNS text AS
$$
SELECT CASE
           WHEN water IN ('river', 'canal', 'stream', 'ditch', 'drain') THEN 'river'
           WHEN "waterway" = 'dock' THEN 'dock'
           WHEN "water" IN ('river', 'stream', 'canal', 'ditch', 'drain') THEN 'river'
           WHEN "water" IN ('pond', 'basin', 'wastewater', 'salt_pond') THEN 'pond'
           WHEN "leisure" = 'swimming_pool' THEN 'swimming_pool'
           ELSE 'lake'
           END;
$$ LANGUAGE SQL IMMUTABLE
                PARALLEL SAFE;


CREATE OR REPLACE FUNCTION waterway_brunnel(is_bridge bool, is_tunnel bool) RETURNS text AS
$$
SELECT CASE
           WHEN is_bridge THEN 'bridge'
           WHEN is_tunnel THEN 'tunnel'
           END;
$$ LANGUAGE SQL IMMUTABLE
                STRICT
                PARALLEL SAFE;


-- Get matching osm id for natural earth id.
DROP MATERIALIZED VIEW IF EXISTS match_osm_ne_id CASCADE;
CREATE MATERIALIZED VIEW match_osm_ne_id AS
(
WITH name_match AS
    (
        -- Distinct on keeps just the first occurence -> order by 'area_ratio DESC'.
    SELECT DISTINCT ON (ne.ne_id) 
        ne.ne_id,
        osm.osm_id,
        (ST_Area(ST_Intersection(ne.geometry, osm.geometry))/ST_Area(ne.geometry)) AS area_ratio
    FROM ne_10m_lakes ne, osm_water_polygon_gen_z6 osm
    WHERE ne.name = osm.name 
        AND ST_Intersects(ne.geometry, osm.geometry)
    ORDER BY ne_id,
             area_ratio DESC
    ),
        -- Add lakes which are not match by name, but intersects. 
        -- Duplicity solves 'DISTICT ON' with 'area_ratio'.
    geom_match AS
    (SELECT DISTINCT ON (ne.ne_id) 
        ne.ne_id,
        osm.osm_id,
        (ST_Area(ST_Intersection(ne.geometry, osm.geometry))/ST_Area(ne.geometry)) AS area_ratio
	FROM ne_10m_lakes ne, osm_water_polygon_gen_z6 osm
	WHERE ST_Intersects(ne.geometry, osm.geometry)
        AND ne.ne_id NOT IN 
            (   SELECT ne_id 
                FROM name_match
            )
    ORDER BY ne_id,
             area_ratio DESC
    )
 
SELECT  ne_id,
        osm_id 
FROM name_match

UNION

SELECT  ne_id,
        osm_id 
FROM geom_match
);

-- ne_10m_ocean
-- etldoc:  ne_10m_ocean ->  ne_10m_ocean_gen_z5
DROP MATERIALIZED VIEW IF EXISTS ne_10m_ocean_gen_z5 CASCADE;
CREATE MATERIALIZED VIEW ne_10m_ocean_gen_z5 AS
(
SELECT  NULL::integer AS id,
       (ST_Dump(ST_Simplify(geometry, ZRes(7)))).geom AS geometry,
       'ocean'::text AS class,
       NULL::boolean AS is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM ne_10m_ocean
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_10m_ocean_gen_z5_idx ON ne_10m_ocean_gen_z5 USING gist (geometry);

-- ne_10m_lakes
-- etldoc:  ne_10m_lakes ->  ne_10m_lakes_gen_z5
DROP MATERIALIZED VIEW IF EXISTS ne_10m_lakes_gen_z5 CASCADE;
CREATE MATERIALIZED VIEW ne_10m_lakes_gen_z5 AS
(
SELECT COALESCE(osm.osm_id, ne_id) AS id,
        -- Union fixing e.g. Lake Huron and Georgian Bay duplicity 
       (ST_Dump(ST_MakeValid(ST_Simplify(ST_Union(geometry), ZRes(7))))).geom AS geometry,
       'lake'::text AS class,
       NULL::boolean AS is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM ne_10m_lakes
LEFT JOIN match_osm_ne_id osm USING (ne_id)
GROUP BY COALESCE(osm.osm_id, ne_id), is_intermittent, is_bridge, is_tunnel
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_10m_lakes_gen_z5_idx ON ne_10m_lakes_gen_z5 USING gist (geometry);

-- etldoc:  ne_10m_lakes_gen_z5 ->  ne_10m_lakes_gen_z4
DROP MATERIALIZED VIEW IF EXISTS ne_10m_lakes_gen_z4 CASCADE;
CREATE MATERIALIZED VIEW ne_10m_lakes_gen_z4 AS
(
SELECT id,
       (ST_Dump(ST_MakeValid(ST_Simplify(geometry, ZRes(6))))).geom AS geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_10m_lakes_gen_z5
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_10m_lakes_gen_z4_idx ON ne_10m_lakes_gen_z4 USING gist (geometry);

-- ne_50m_ocean
-- etldoc:  ne_50m_ocean ->  ne_50m_ocean_gen_z4
DROP MATERIALIZED VIEW IF EXISTS ne_50m_ocean_gen_z4 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_ocean_gen_z4 AS
(
SELECT NULL::integer AS id,
       (ST_Dump(ST_Simplify(geometry, ZRes(6)))).geom AS geometry,
       'ocean'::text AS class,
       NULL::boolean AS is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM ne_50m_ocean
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_ocean_gen_z4_idx ON ne_50m_ocean_gen_z4 USING gist (geometry);

-- etldoc:  ne_50m_ocean_gen_z4 ->  ne_50m_ocean_gen_z3
DROP MATERIALIZED VIEW IF EXISTS ne_50m_ocean_gen_z3 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_ocean_gen_z3 AS
(
SELECT id,
       ST_Simplify(geometry, ZRes(5)) AS geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_50m_ocean_gen_z4
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_ocean_gen_z3_idx ON ne_50m_ocean_gen_z3 USING gist (geometry);

-- etldoc:  ne_50m_ocean_gen_z3 ->  ne_50m_ocean_gen_z2
DROP MATERIALIZED VIEW IF EXISTS ne_50m_ocean_gen_z2 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_ocean_gen_z2 AS
(
SELECT id,
       ST_Simplify(geometry, ZRes(4)) AS geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_50m_ocean_gen_z3
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_ocean_gen_z2_idx ON ne_50m_ocean_gen_z2 USING gist (geometry);

-- ne_50m_lakes
-- etldoc:  ne_50m_lakes ->  ne_50m_lakes_gen_z3
DROP MATERIALIZED VIEW IF EXISTS ne_50m_lakes_gen_z3 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_lakes_gen_z3 AS
(
SELECT COALESCE(osm.osm_id, ne_id) AS id,
       (ST_Dump(ST_MakeValid(ST_Simplify(geometry, ZRes(5))))).geom AS geometry,
       'lake'::text AS class,
       NULL::boolean AS is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM ne_50m_lakes
LEFT JOIN match_osm_ne_id osm USING (ne_id)
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_lakes_gen_z3_idx ON ne_50m_lakes_gen_z3 USING gist (geometry);

-- etldoc:  ne_50m_lakes_gen_z3 ->  ne_50m_lakes_gen_z2
DROP MATERIALIZED VIEW IF EXISTS ne_50m_lakes_gen_z2 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_lakes_gen_z2 AS
(
SELECT id,
       (ST_Dump(ST_MakeValid(ST_Simplify(geometry, ZRes(4))))).geom AS geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_50m_lakes_gen_z3
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_lakes_gen_z2_idx ON ne_50m_lakes_gen_z2 USING gist (geometry);

--ne_110m_ocean
-- etldoc:  ne_110m_ocean ->  ne_110m_ocean_gen_z1
DROP MATERIALIZED VIEW IF EXISTS ne_110m_ocean_gen_z1 CASCADE;
CREATE MATERIALIZED VIEW ne_110m_ocean_gen_z1 AS
(
SELECT NULL::integer AS id,
       ST_Simplify(geometry, ZRes(3)) AS geometry,
       'ocean'::text AS class,
       NULL::boolean AS is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM ne_110m_ocean
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_110m_ocean_gen_z1_idx ON ne_110m_ocean_gen_z1 USING gist (geometry);

-- etldoc:  ne_110m_ocean_gen_z1 ->  ne_110m_ocean_gen_z0
DROP MATERIALIZED VIEW IF EXISTS ne_110m_ocean_gen_z0 CASCADE;
CREATE MATERIALIZED VIEW ne_110m_ocean_gen_z0 AS
(
SELECT id,
       ST_Simplify(geometry, ZRes(2)) AS geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_110m_ocean_gen_z1
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_110m_ocean_gen_z0_idx ON ne_110m_ocean_gen_z0 USING gist (geometry);


-- ne_110m_lakes
-- etldoc:  ne_110m_lakes ->  ne_110m_lakes_gen_z1
DROP MATERIALIZED VIEW IF EXISTS ne_110m_lakes_gen_z1 CASCADE;
CREATE MATERIALIZED VIEW ne_110m_lakes_gen_z1 AS
(
SELECT COALESCE(osm.osm_id, ne_id) AS id,
       (ST_Dump(ST_Simplify(geometry, ZRes(3)))).geom AS geometry,
       'lake'::text AS class,
       NULL::boolean AS is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM ne_110m_lakes
LEFT JOIN match_osm_ne_id osm USING (ne_id)
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_110m_lakes_gen_z1_idx ON ne_110m_lakes_gen_z1 USING gist (geometry);

-- etldoc:  ne_110m_lakes_gen_z1 ->  ne_110m_lakes_gen_z0
DROP MATERIALIZED VIEW IF EXISTS ne_110m_lakes_gen_z0 CASCADE;
CREATE MATERIALIZED VIEW ne_110m_lakes_gen_z0 AS
(
SELECT id,
       (ST_Dump(ST_Simplify(geometry, ZRes(2)))).geom AS geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_110m_lakes_gen_z1
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_110m_lakes_gen_z0_idx ON ne_110m_lakes_gen_z0 USING gist (geometry);

DROP MATERIALIZED VIEW IF EXISTS water_z6;
DROP MATERIALIZED VIEW IF EXISTS water_z7;
DROP MATERIALIZED VIEW IF EXISTS water_z8;
DROP MATERIALIZED VIEW IF EXISTS water_z9;
DROP MATERIALIZED VIEW IF EXISTS water_z10;
DROP MATERIALIZED VIEW IF EXISTS water_z11;
DROP MATERIALIZED VIEW IF EXISTS water_z12;

CREATE OR REPLACE VIEW water_z0 AS
(
-- etldoc:  ne_110m_ocean_gen_z0 ->  water_z0
SELECT id,
       geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_110m_ocean_gen_z0
UNION ALL
-- etldoc:  ne_110m_lakes_gen_z0 ->  water_z0
SELECT id,
       geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_110m_lakes_gen_z0
    );

CREATE OR REPLACE VIEW water_z1 AS
(
-- etldoc:  ne_110m_ocean_gen_z1 ->  water_z1
SELECT id,
       geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_110m_ocean_gen_z1
UNION ALL
-- etldoc:  ne_110m_lakes_gen_z1 ->  water_z1
SELECT id,
       geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_110m_lakes_gen_z1
    );

CREATE OR REPLACE VIEW water_z2 AS
(
-- etldoc:  ne_50m_ocean_gen_z2 ->  water_z2
SELECT id,
       geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_50m_ocean_gen_z2
UNION ALL
-- etldoc:  ne_50m_lakes_gen_z2 ->  water_z2
SELECT id,
       geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_50m_lakes_gen_z2
    );

CREATE OR REPLACE VIEW water_z3 AS
(
-- etldoc:  ne_50m_ocean_gen_z3 ->  water_z3
SELECT id,
       geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_50m_ocean_gen_z3
UNION ALL
-- etldoc:  ne_50m_lakes_gen_z3 ->  water_z3
SELECT id, 
       geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_50m_lakes_gen_z3
    );

CREATE OR REPLACE VIEW water_z4 AS
(
-- etldoc:  ne_50m_ocean_gen_z4 ->  water_z4
SELECT id,
       geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_50m_ocean_gen_z4
UNION ALL
-- etldoc:  ne_10m_lakes_gen_z4 ->  water_z4
SELECT id,
       geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_10m_lakes_gen_z4
    );


CREATE OR REPLACE VIEW water_z5 AS
(
-- etldoc:  ne_10m_ocean_gen_z5 ->  water_z5
SELECT id,
       geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_10m_ocean_gen_z5
UNION ALL
-- etldoc:  ne_10m_lakes_gen_z5 ->  water_z5
SELECT id,
       geometry,
       class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM ne_10m_lakes_gen_z5
    );

CREATE MATERIALIZED VIEW water_z6 AS
(
-- etldoc:  osm_ocean_polygon_gen_z6 ->  water_z6
SELECT NULL::integer AS id,
       (ST_Dump(geometry)).geom AS geometry,
       'ocean'::text AS class,
       NULL::boolean AS is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM osm_ocean_polygon_gen_z6
UNION ALL
-- etldoc:  osm_water_polygon_gen_z6 ->  water_z6
SELECT osm_id AS id,
       (ST_Dump(geometry)).geom AS geometry,
       water_class(waterway, water, leisure) AS class,
       is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM osm_water_polygon_gen_z6
WHERE "natural" != 'bay'
    );
CREATE INDEX ON water_z6 USING gist(geometry);

CREATE MATERIALIZED VIEW water_z7 AS
(
-- etldoc:  osm_ocean_polygon_gen_z7 ->  water_z7
SELECT NULL::integer AS id,
       (ST_Dump(geometry)).geom AS geometry,
       'ocean'::text AS class,
       NULL::boolean AS is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM osm_ocean_polygon_gen_z7
UNION ALL
-- etldoc:  osm_water_polygon_gen_z7 ->  water_z7
SELECT osm_id AS id,
       (ST_Dump(geometry)).geom AS geometry,
       water_class(waterway, water, leisure) AS class,
       is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM osm_water_polygon_gen_z7
WHERE "natural" != 'bay'
    );
CREATE INDEX ON water_z7 USING gist(geometry);

CREATE MATERIALIZED VIEW water_z8 AS
(
-- etldoc:  osm_ocean_polygon_gen_z8 ->  water_z8
SELECT NULL::integer AS id,
       (ST_Dump(geometry)).geom AS geometry,
       'ocean'::text AS class,
       NULL::boolean AS is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM osm_ocean_polygon_gen_z8
UNION ALL
-- etldoc:  osm_water_polygon_gen_z8 ->  water_z8
SELECT osm_id AS id,
       (ST_Dump(geometry)).geom AS geometry,
       water_class(waterway, water, leisure) AS class,
       is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM osm_water_polygon_gen_z8
WHERE "natural" != 'bay'
    );
CREATE INDEX ON water_z8 USING gist(geometry);

CREATE MATERIALIZED VIEW water_z9 AS
(
-- etldoc:  osm_ocean_polygon_gen_z9 ->  water_z9
SELECT NULL::integer AS id,
       (ST_Dump(geometry)).geom AS geometry,
       'ocean'::text AS class,
       NULL::boolean AS is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM osm_ocean_polygon_gen_z9
UNION ALL
-- etldoc:  osm_water_polygon_gen_z9 ->  water_z9
SELECT osm_id AS id,
       (ST_Dump(geometry)).geom AS geometry,
       water_class(waterway, water, leisure) AS class,
       is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM osm_water_polygon_gen_z9
WHERE "natural" != 'bay'
    );
CREATE INDEX ON water_z9 USING gist(geometry);

CREATE MATERIALIZED VIEW water_z10 AS
(
-- etldoc:  osm_ocean_polygon_gen_z10 ->  water_z10
SELECT NULL::integer AS id,
       (ST_Dump(geometry)).geom AS geometry,
       'ocean'::text AS class,
       NULL::boolean AS is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM osm_ocean_polygon_gen_z10
UNION ALL
-- etldoc:  osm_water_polygon_gen_z10 ->  water_z10
SELECT osm_id AS id,
       (ST_Dump(geometry)).geom AS geometry,
       water_class(waterway, water, leisure) AS class,
       is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM osm_water_polygon_gen_z10
WHERE "natural" != 'bay'
    );
CREATE INDEX ON water_z10 USING gist(geometry);

CREATE MATERIALIZED VIEW water_z11 AS
(
-- etldoc:  osm_ocean_polygon_gen_z11 ->  water_z11
SELECT NULL::integer AS id,
       (ST_Dump(geometry)).geom AS geometry,
       'ocean'::text AS class,
       NULL::boolean AS is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM osm_ocean_polygon_gen_z11
UNION ALL
-- etldoc:  osm_water_polygon_gen_z11 ->  water_z11
SELECT osm_id AS id,
       (ST_Dump(geometry)).geom AS geometry,
       water_class(waterway, water, leisure) AS class,
       is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM osm_water_polygon_gen_z11
WHERE "natural" != 'bay'
    );
CREATE INDEX ON water_z11 USING gist(geometry);

CREATE MATERIALIZED VIEW water_z12 AS
(
-- etldoc:  osm_ocean_polygon_union ->  water_z12
SELECT NULL::integer AS id,
       (ST_Dump(geometry)).geom AS geometry,
       'ocean'::text AS class,
       NULL::boolean AS is_intermittent,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel
FROM osm_ocean_polygon_union
UNION ALL
-- etldoc:  osm_water_polygon ->  water_z12
SELECT osm_id AS id,
       (ST_Dump(geometry)).geom AS geometry,
       water_class(waterway, water, leisure) AS class,
       is_intermittent,
       is_bridge,
       is_tunnel
FROM osm_water_polygon
WHERE "natural" != 'bay'
    );
CREATE INDEX ON water_z12 USING gist(geometry);

-- etldoc: layer_water [shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="layer_water |<z0> z0|<z1>z1|<z2>z2|<z3>z3 |<z4> z4|<z5>z5|<z6>z6|<z7>z7| <z8> z8 |<z9> z9 |<z10> z10 |<z11> z11 |<z12> z12+" ] ;

CREATE OR REPLACE FUNCTION layer_water(bbox geometry, zoom_level int)
    RETURNS TABLE
            (
                id           bigint,
                geometry     geometry,
                class        text,
                brunnel      text,
                intermittent int
            )
AS
$$
SELECT id,
       geometry,
       class::text,
       waterway_brunnel(is_bridge, is_tunnel) AS brunnel,
       is_intermittent::int AS intermittent
FROM (
         -- etldoc: water_z0 ->  layer_water:z0
         SELECT *
         FROM water_z0
         WHERE zoom_level = 0
         UNION ALL
         -- etldoc: water_z1 ->  layer_water:z1
         SELECT *
         FROM water_z1
         WHERE zoom_level = 1
         UNION ALL
         -- etldoc: water_z2 ->  layer_water:z2
         SELECT *
         FROM water_z2
         WHERE zoom_level = 2
         UNION ALL
         -- etldoc: water_z3 ->  layer_water:z3
         SELECT *
         FROM water_z3
         WHERE zoom_level = 3
         UNION ALL
         -- etldoc: water_z4 ->  layer_water:z4
         SELECT *
         FROM water_z4
         WHERE zoom_level = 4
         UNION ALL
         -- etldoc: water_z5 ->  layer_water:z5
         SELECT *
         FROM water_z5
         WHERE zoom_level = 5
         UNION ALL
         -- etldoc: water_z6 ->  layer_water:z6
         SELECT *
         FROM water_z6
         WHERE zoom_level = 6
         UNION ALL
         -- etldoc: water_z7 ->  layer_water:z7
         SELECT *
         FROM water_z7
         WHERE zoom_level = 7
         UNION ALL
         -- etldoc: water_z8 ->  layer_water:z8
         SELECT *
         FROM water_z8
         WHERE zoom_level = 8
         UNION ALL
         -- etldoc: water_z9 ->  layer_water:z9
         SELECT *
         FROM water_z9
         WHERE zoom_level = 9
         UNION ALL
         -- etldoc: water_z10 ->  layer_water:z10
         SELECT *
         FROM water_z10
         WHERE zoom_level = 10
         UNION ALL
         -- etldoc: water_z11 ->  layer_water:z11
         SELECT *
         FROM water_z11
         WHERE zoom_level = 11
         UNION ALL
         -- etldoc: water_z12 ->  layer_water:z12
         SELECT *
         FROM water_z12
         WHERE zoom_level >= 12
     ) AS zoom_levels
WHERE geometry && bbox;
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;

DO $$ BEGIN RAISE NOTICE 'Finished layer water'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer waterway'; END$$;

DO $$ BEGIN
    PERFORM 'ne_110m_rivers_lake_centerlines'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "waterway"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_50m_rivers_lake_centerlines'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "waterway"';
END;
$$ LANGUAGE 'plpgsql';

-- Layer waterway - ./update_waterway_linestring.sql

DROP TRIGGER IF EXISTS trigger_flag ON osm_waterway_linestring;
DROP TRIGGER IF EXISTS trigger_refresh ON osm_waterway_linestring;

DO
$$
    BEGIN
        UPDATE osm_waterway_linestring
        SET tags = update_tags(tags, geometry);
    END
$$;


-- Handle updates

CREATE SCHEMA IF NOT EXISTS waterway_linestring;
CREATE OR REPLACE FUNCTION waterway_linestring.refresh() RETURNS trigger AS
$$
BEGIN
    --     RAISE NOTICE 'Refresh waterway_linestring %', NEW.osm_id;
    NEW.tags = update_tags(NEW.tags, NEW.geometry);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_refresh
    BEFORE INSERT OR UPDATE
    ON osm_waterway_linestring
    FOR EACH ROW
EXECUTE PROCEDURE waterway_linestring.refresh();

-- Layer waterway - ./update_important_waterway.sql

DROP TRIGGER IF EXISTS trigger_important_waterway_linestring_store ON osm_important_waterway_linestring;
DROP TRIGGER IF EXISTS trigger_store ON osm_waterway_linestring;
DROP TRIGGER IF EXISTS trigger_flag ON osm_waterway_linestring;
DROP TRIGGER IF EXISTS trigger_refresh ON waterway_important.updates;

-- We merge the waterways by name like the highways
-- This helps to drop not important rivers (since they do not have a name)
-- and also makes it possible to filter out too short rivers

-- Index for filling and updating osm_important_waterway_linestring table
CREATE UNIQUE INDEX IF NOT EXISTS osm_waterway_linestring_waterway_partial_idx
    ON osm_waterway_linestring (osm_id)
    WHERE name <> ''
      AND waterway = 'river'
      AND ST_IsValid(geometry);

-- Analyze created index
ANALYZE osm_waterway_linestring;

CREATE TABLE IF NOT EXISTS osm_important_waterway_linestring (
    id SERIAL,
    geometry geometry('LineString'),
    source_ids bigint[],
    new_source_ids bigint[],
    old_source_ids bigint[],
    name varchar,
    name_en varchar,
    name_de varchar,
    tags hstore
);

ALTER TABLE osm_important_waterway_linestring ADD COLUMN IF NOT EXISTS source_ids bigint[];
-- Create temporary Merged-LineString to Source-LineStrings-ID columns to store relations before they have been
-- intersected
ALTER TABLE osm_important_waterway_linestring ADD COLUMN IF NOT EXISTS new_source_ids BIGINT[];
ALTER TABLE osm_important_waterway_linestring ADD COLUMN IF NOT EXISTS old_source_ids BIGINT[];

CREATE INDEX IF NOT EXISTS osm_important_waterway_linestring_n_source_ids_not_null_idx 
    ON osm_important_waterway_linestring ((new_source_ids IS NOT NULL));
CREATE INDEX IF NOT EXISTS osm_important_waterway_linestring_o_source_ids_not_null_idx 
    ON osm_important_waterway_linestring ((old_source_ids IS NOT NULL));

-- Create osm_important_waterway_linestring_gen_z11 as a copy of osm_important_waterway_linestring but drop the
-- "source_ids" column. This can be done because z10 and z9 tables are only simplified and not merged, therefore
-- relations to sources are direct via the id column.
CREATE TABLE IF NOT EXISTS osm_important_waterway_linestring_gen_z11
(LIKE osm_important_waterway_linestring);
ALTER TABLE osm_important_waterway_linestring_gen_z11 DROP COLUMN IF EXISTS source_ids;
ALTER TABLE osm_important_waterway_linestring_gen_z11 DROP COLUMN IF EXISTS new_source_ids;
ALTER TABLE osm_important_waterway_linestring_gen_z11 DROP COLUMN IF EXISTS old_source_ids;

-- Create osm_important_waterway_linestring_gen_z10 as a copy of osm_important_waterway_linestring_gen_z11
CREATE TABLE IF NOT EXISTS osm_important_waterway_linestring_gen_z10
(LIKE osm_important_waterway_linestring_gen_z11);

-- Create osm_important_waterway_linestring_gen_z9 as a copy of osm_important_waterway_linestring_gen_z10
CREATE TABLE IF NOT EXISTS osm_important_waterway_linestring_gen_z9
(LIKE osm_important_waterway_linestring_gen_z10);

-- Create OneToMany-Relation-Table storing relations of a Merged-LineString in table
-- osm_important_waterway_linestring to Source-LineStrings from table osm_waterway_linestring
CREATE TABLE IF NOT EXISTS osm_important_waterway_linestring_source_ids(
    id int,
    source_id bigint,
    PRIMARY KEY (id, source_id)
);

-- Ensure tables are emtpy if they haven't been created
TRUNCATE osm_important_waterway_linestring;
TRUNCATE osm_important_waterway_linestring_source_ids;

-- etldoc: osm_waterway_linestring ->  osm_important_waterway_linestring
-- Merge LineStrings from osm_waterway_linestring by grouping them and creating intersecting
-- clusters of each group via ST_ClusterDBSCAN
INSERT INTO osm_important_waterway_linestring (geometry, source_ids, name, name_en, name_de, tags)
SELECT (ST_Dump(ST_LineMerge(ST_Union(geometry)))).geom AS geometry,
       -- We use St_Union instead of St_Collect to ensure no overlapping points exist within the geometries
       -- to merge. https://postgis.net/docs/ST_Union.html
       -- ST_LineMerge only merges across singular intersections and groups its output into a MultiLineString
       -- if more than two LineStrings form an intersection or no intersection could be found.
       -- https://postgis.net/docs/ST_LineMerge.html
       -- In order to not end up with a mixture of LineStrings and MultiLineStrings we dump eventual
       -- MultiLineStrings via ST_Dump. https://postgis.net/docs/ST_Dump.html
       array_agg(osm_id) as source_ids,
       name,
       name_en,
       name_de,
       slice_language_tags(tags) AS tags
FROM (
    SELECT *,
           -- Get intersecting clusters by setting minimum distance to 0 and minimum intersecting points to 1.
           -- https://postgis.net/docs/ST_ClusterDBSCAN.html
           ST_ClusterDBSCAN(geometry, 0, 1) OVER (
               PARTITION BY name, name_en, name_de, slice_language_tags(tags)
           ) AS cluster,
           -- ST_ClusterDBSCAN returns an increasing integer as the cluster-ids within each partition starting at 0.
           -- This leads to clusters having the same ID across multiple partitions therefore we generate a
           -- Cluster-Group-ID by utilizing the DENSE_RANK function sorted over the partition columns.
           DENSE_RANK() OVER (ORDER BY name, name_en, name_de, slice_language_tags(tags)) as cluster_group
    FROM osm_waterway_linestring
    WHERE name <> '' AND waterway = 'river' AND ST_IsValid(geometry)
) q
GROUP BY cluster_group, cluster, name, name_en, name_de, slice_language_tags(tags);

-- Geometry Index
CREATE INDEX IF NOT EXISTS osm_important_waterway_linestring_geometry_idx
    ON osm_important_waterway_linestring USING gist (geometry);

-- Create Primary-Keys for osm_important_waterway_linestring and osm_important_waterway_linestring_gen_z11/z10/z9 tables
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_important_waterway_linestring' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_important_waterway_linestring ADD PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_important_waterway_linestring_gen_z11' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_important_waterway_linestring_gen_z11 ADD PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_important_waterway_linestring_gen_z10' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_important_waterway_linestring_gen_z10 ADD PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_important_waterway_linestring_gen_z9' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_important_waterway_linestring_gen_z9 ADD PRIMARY KEY (id);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Index for storing OSM-IDs of Source-LineStrings
CREATE UNIQUE INDEX IF NOT EXISTS osm_waterway_linestring_osm_id_idx ON osm_waterway_linestring ("osm_id");

-- Indexes which can be utilized during full-update for queries originating from
-- insert_important_waterway_linestring_gen() function
CREATE UNIQUE INDEX IF NOT EXISTS osm_important_waterway_linestring_update_idx
    ON osm_important_waterway_linestring (id) WHERE ST_Length(geometry) > 1000;

-- Analyze populated table with indexes
ANALYZE osm_important_waterway_linestring;

-- Store OSM-IDs of Source-LineStrings by intersecting Merged-LineStrings with their sources. This required because
-- ST_LineMerge only merges across singular intersections and groups its output into a MultiLineString if
-- more than two LineStrings form an intersection or no intersection could be found.
-- Execute after indexes have been created on osm_highway_linestring_gen_z11 to improve performance
INSERT INTO osm_important_waterway_linestring_source_ids (id, source_id)
SELECT m.id, m.source_id
FROM (
    SELECT id, unnest(source_ids) AS source_id, geometry
    FROM osm_important_waterway_linestring
) m
JOIN osm_waterway_linestring s ON (m.source_id = s.osm_id)
WHERE ST_Intersects(s.geometry, m.geometry)
ON CONFLICT (id, source_id) DO NOTHING;

-- Drop temporary Merged-LineString to Source-LineStrings-ID column
ALTER TABLE osm_important_waterway_linestring DROP COLUMN IF EXISTS source_ids;

CREATE SCHEMA IF NOT EXISTS waterway_important;

CREATE TABLE IF NOT EXISTS waterway_important.changes_z9_z10_z11
(
    is_old boolean,
    id integer,
    PRIMARY KEY (is_old, id)
);

CREATE OR REPLACE FUNCTION insert_important_waterway_linestring_gen(full_update bool) RETURNS void AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh waterway z9 z10 z11';

    -- Analyze tracking and source tables before performing update
    ANALYZE waterway_important.changes_z9_z10_z11;
    ANALYZE osm_important_waterway_linestring;

    -- Remove entries which have been deleted from source table
    DELETE FROM osm_important_waterway_linestring_gen_z11
    USING waterway_important.changes_z9_z10_z11
    WHERE full_update IS TRUE OR (
        waterway_important.changes_z9_z10_z11.is_old IS TRUE AND
        waterway_important.changes_z9_z10_z11.id = osm_important_waterway_linestring_gen_z11.id
    );

    -- etldoc: osm_important_waterway_linestring -> osm_important_waterway_linestring_gen_z11
    INSERT INTO osm_important_waterway_linestring_gen_z11 (geometry, id, name, name_en, name_de, tags)
    SELECT ST_Simplify(geometry, ZRes(12)) AS geometry,
        id,
        name,
        name_en,
        name_de,
        tags
    FROM osm_important_waterway_linestring
    WHERE (
        full_update OR
        EXISTS(
            SELECT NULL
            FROM waterway_important.changes_z9_z10_z11
            WHERE waterway_important.changes_z9_z10_z11.is_old IS FALSE AND
                  waterway_important.changes_z9_z10_z11.id = osm_important_waterway_linestring.id
        )
    ) AND ST_Length(geometry) > 1000
    ON CONFLICT (id) DO UPDATE SET geometry = excluded.geometry, name = excluded.name, name_en = excluded.name_en,
                                   name_de = excluded.name_de, tags = excluded.tags;

    -- Analyze source table
    ANALYZE osm_important_waterway_linestring_gen_z11;

    -- Remove entries which have been deleted from source table
    DELETE FROM osm_important_waterway_linestring_gen_z10
    USING waterway_important.changes_z9_z10_z11
    WHERE full_update IS TRUE OR (
        waterway_important.changes_z9_z10_z11.is_old IS TRUE AND
        waterway_important.changes_z9_z10_z11.id = osm_important_waterway_linestring_gen_z10.id
    );

    -- etldoc: osm_important_waterway_linestring_gen_z11 -> osm_important_waterway_linestring_gen_z10
    INSERT INTO osm_important_waterway_linestring_gen_z10 (geometry, id, name, name_en, name_de, tags)
    SELECT ST_Simplify(geometry, ZRes(11)) AS geometry,
        id,
        name,
        name_en,
        name_de,
        tags
    FROM osm_important_waterway_linestring_gen_z11
    WHERE (
        full_update OR
        EXISTS(
            SELECT NULL
            FROM waterway_important.changes_z9_z10_z11
            WHERE waterway_important.changes_z9_z10_z11.is_old IS FALSE AND
                  waterway_important.changes_z9_z10_z11.id = osm_important_waterway_linestring_gen_z11.id
        )
    ) AND ST_Length(geometry) > 4000
    ON CONFLICT (id) DO UPDATE SET geometry = excluded.geometry, name = excluded.name, name_en = excluded.name_en,
                                   name_de = excluded.name_de, tags = excluded.tags;

    -- Analyze source table
    ANALYZE osm_important_waterway_linestring_gen_z10;

    -- Remove entries which have been deleted from source table
    DELETE FROM osm_important_waterway_linestring_gen_z9
    USING waterway_important.changes_z9_z10_z11
    WHERE full_update IS TRUE OR (
        waterway_important.changes_z9_z10_z11.is_old IS TRUE AND
        waterway_important.changes_z9_z10_z11.id = osm_important_waterway_linestring_gen_z9.id
    );

    -- etldoc: osm_important_waterway_linestring_gen_z10 -> osm_important_waterway_linestring_gen_z9
    INSERT INTO osm_important_waterway_linestring_gen_z9 (geometry, id, name, name_en, name_de, tags)
    SELECT ST_Simplify(geometry, ZRes(10)) AS geometry,
        id,
        name,
        name_en,
        name_de,
        tags
    FROM osm_important_waterway_linestring_gen_z10
    WHERE (
        full_update OR
        EXISTS(
            SELECT NULL
            FROM waterway_important.changes_z9_z10_z11
            WHERE waterway_important.changes_z9_z10_z11.is_old IS FALSE AND
                  waterway_important.changes_z9_z10_z11.id = osm_important_waterway_linestring_gen_z10.id
        )
    ) AND ST_Length(geometry) > 8000
    ON CONFLICT (id) DO UPDATE SET geometry = excluded.geometry, name = excluded.name, name_en = excluded.name_en,
                                   name_de = excluded.name_de, tags = excluded.tags;

    -- noinspection SqlWithoutWhere
    DELETE FROM waterway_important.changes_z9_z10_z11;

    RAISE LOG 'Refresh waterway z9 z10 z11 done in %', age(clock_timestamp(), t);
END;
$$ LANGUAGE plpgsql;

-- Ensure tables are emtpy if they haven't been created
TRUNCATE osm_important_waterway_linestring_gen_z11;
TRUNCATE osm_important_waterway_linestring_gen_z10;
TRUNCATE osm_important_waterway_linestring_gen_z9;

SELECT insert_important_waterway_linestring_gen(TRUE);

-- Indexes for queries originating from insert_important_waterway_linestring_gen() function
CREATE UNIQUE INDEX IF NOT EXISTS osm_important_waterway_linestring_gen_z11_update_idx
    ON osm_important_waterway_linestring_gen_z11 (id) WHERE ST_Length(geometry) > 4000;
CREATE UNIQUE INDEX IF NOT EXISTS osm_important_waterway_linestring_gen_z10_update_idx
    ON osm_important_waterway_linestring_gen_z10 (id) WHERE ST_Length(geometry) > 8000;

-- Geometry Indexes
CREATE INDEX IF NOT EXISTS osm_important_waterway_linestring_gen_z11_geometry_idx
    ON osm_important_waterway_linestring_gen_z11 USING gist (geometry);
CREATE INDEX IF NOT EXISTS osm_important_waterway_linestring_gen_z10_geometry_idx
    ON osm_important_waterway_linestring_gen_z10 USING gist (geometry);
CREATE INDEX IF NOT EXISTS osm_important_waterway_linestring_gen_z9_geometry_idx
    ON osm_important_waterway_linestring_gen_z9 USING gist (geometry);


-- Handle updates on
-- -- osm_waterway_linestring -> osm_important_waterway_linestring
-- -- osm_important_waterway_linestring -> osm_important_waterway_linestring_gen_z11
-- -- osm_important_waterway_linestring -> osm_important_waterway_linestring_gen_z10
-- -- osm_important_waterway_linestring -> osm_important_waterway_linestring_gen_z9

CREATE OR REPLACE AGGREGATE array_cat_agg(anycompatiblearray) (
  SFUNC=array_cat,
  STYPE=anycompatiblearray,
  INITCOND = '{}'
);

CREATE TABLE IF NOT EXISTS waterway_important.changes
(
    osm_id bigint,
    is_old boolean,
    PRIMARY KEY (is_old, osm_id)
);

-- Store IDs of changed elements from osm_waterway_linestring table.
CREATE OR REPLACE FUNCTION waterway_important.store() RETURNS trigger AS
$$
BEGIN
    IF (tg_op IN ('DELETE', 'UPDATE')) AND OLD.name <> '' AND OLD.waterway = 'river' THEN
        INSERT INTO waterway_important.changes(is_old, osm_id)
        VALUES (TRUE, old.osm_id) ON CONFLICT DO NOTHING;
    END IF;
    IF (tg_op IN ('UPDATE', 'INSERT')) AND NEW.name <> '' AND NEW.waterway = 'river' THEN
        INSERT INTO waterway_important.changes(is_old, osm_id)
        VALUES (FALSE, new.osm_id) ON CONFLICT DO NOTHING;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Store IDs of changed elements from osm_important_waterway_linestring table.
CREATE OR REPLACE FUNCTION waterway_important.important_waterway_linestring_store() RETURNS trigger AS
$$
BEGIN
    IF (tg_op = 'UPDATE' OR tg_op = 'DELETE') THEN
        INSERT INTO waterway_important.changes_z9_z10_z11 (is_old, id) VALUES (TRUE, old.id) ON CONFLICT DO NOTHING ;
    END IF;

    IF (tg_op = 'UPDATE' OR tg_op = 'INSERT') THEN
        INSERT INTO waterway_important.changes_z9_z10_z11 (is_old, id) VALUES (FALSE, new.id) ON CONFLICT DO NOTHING;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS waterway_important.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION waterway_important.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO waterway_important.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION waterway_important.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh waterway';

    -- REFRESH osm_important_waterway_linestring

    -- Analyze tracking and source tables before performing update
    ANALYZE waterway_important.changes;
    ANALYZE osm_waterway_linestring;

    -- Fetch updated and deleted Merged-LineString from relation-table filtering for each Merged-LineString which
    -- contains an updated Source-LineString.
    -- Additionally attach a list of Source-LineString-IDs to each Merged-LineString in order to unnest them later.
    CREATE TEMPORARY TABLE affected_merged_linestrings AS
    SELECT m.id, array_agg(source_id) AS source_ids
    FROM osm_important_waterway_linestring_source_ids m
    WHERE EXISTS(
        SELECT NULL
        FROM waterway_important.changes c
        WHERE c.is_old IS TRUE AND c.osm_id = m.source_id
    )
    GROUP BY id;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE affected_merged_linestrings;

    -- Delete all Merged-LineStrings which contained an updated or deleted Source-LineString
    DELETE
    FROM osm_important_waterway_linestring m
    USING affected_merged_linestrings
    WHERE affected_merged_linestrings.id = m.id;
    DELETE
    FROM osm_important_waterway_linestring_source_ids m
    USING affected_merged_linestrings
    WHERE affected_merged_linestrings.id = m.id;

    -- Analyze the tables affected by the delete-query in order to speed up subsequent queries
    ANALYZE osm_important_waterway_linestring;
    ANALYZE osm_important_waterway_linestring_source_ids;

    -- Create a table containing all LineStrings which should be merged
    CREATE TEMPORARY TABLE linestrings_to_merge AS
    -- Add all Source-LineStrings affected by this update
    SELECT osm_id, NULL::INTEGER AS id, NULL::BIGINT[] AS source_ids, geometry, name, name_en, name_de,
           slice_language_tags(tags) as tags
    -- Table containing the IDs of all Source-LineStrings affected by this update
    FROM (
        -- Get Source-LineString-IDs of deleted or updated elements
        SELECT unnest(affected_merged_linestrings.source_ids)::bigint AS source_id FROM affected_merged_linestrings
        UNION
        -- Get Source-LineString-IDs of inserted or updated elements
        SELECT osm_id AS source_id FROM waterway_important.changes WHERE is_old IS FALSE
        ORDER BY source_id
    ) affected_source_linestrings
    JOIN osm_waterway_linestring ON (
        affected_source_linestrings.source_id = osm_waterway_linestring.osm_id
    )
    WHERE name <> '' AND waterway = 'river' AND ST_IsValid(geometry);

    -- Drop temporary tables early to save resources
    DROP TABLE affected_merged_linestrings;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE linestrings_to_merge;

    -- Add all Merged-LineStrings intersecting with Source-LineStrings affected by this update
    INSERT INTO linestrings_to_merge
    SELECT NULL::BIGINT AS osm_id, m.id,
           ARRAY(
               SELECT s.source_id FROM osm_important_waterway_linestring_source_ids s WHERE s.id = m.id
           )::BIGINT[] AS source_ids,
           m.geometry, m.name, m.name_en, m.name_de, m.tags
    FROM linestrings_to_merge
    JOIN osm_important_waterway_linestring m ON (ST_Intersects(linestrings_to_merge.geometry, m.geometry));

    -- Analyze the created table to speed up subsequent queries
    ANALYZE linestrings_to_merge;

    -- Delete all Merged-LineStrings intersecting with Source-LineStrings affected by this update.
    -- We can use the linestrings_to_merge table since Source-LineStrings affected by this update and present in the
    -- table will have their ID-Column set to NULL by the previous query.
    DELETE
    FROM osm_important_waterway_linestring m
    USING linestrings_to_merge
    WHERE m.id = linestrings_to_merge.id;
    DELETE
    FROM osm_important_waterway_linestring_source_ids m
    USING linestrings_to_merge
    WHERE m.id = linestrings_to_merge.id;

    -- Create table containing all LineStrings to and create clusters of intersecting LineStrings partitioned by their
    -- groups
    CREATE TEMPORARY TABLE clustered_linestrings_to_merge AS
    SELECT *,
           -- Get intersecting clusters by setting minimum distance to 0 and minimum intersecting points to 1.
           -- https://postgis.net/docs/ST_ClusterDBSCAN.html
           ST_ClusterDBSCAN(geometry, 0, 1) OVER (PARTITION BY name, name_en, name_de, tags) AS cluster,
           -- ST_ClusterDBSCAN returns an increasing integer as the cluster-ids within each partition starting at 0.
           -- This leads to clusters having the same ID across multiple partitions therefore we generate a
           -- Cluster-Group-ID by utilizing the DENSE_RANK function sorted over the partition columns.
           DENSE_RANK() OVER (ORDER BY name, name_en, name_de, tags) as cluster_group
    FROM linestrings_to_merge;

    -- Drop temporary tables early to save resources
    DROP TABLE linestrings_to_merge;

    -- Create index on cluster columns and analyze the created table to speed up subsequent queries
    CREATE INDEX ON clustered_linestrings_to_merge (cluster_group, cluster);
    ANALYZE clustered_linestrings_to_merge;


    WITH inserted_linestrings AS (
        -- Merge LineStrings of each cluster and insert them
        INSERT INTO osm_important_waterway_linestring (geometry, new_source_ids, old_source_ids, name, name_en, name_de,
                                                       tags)
        SELECT (ST_Dump(ST_LineMerge(ST_Union(geometry)))).geom AS geometry,
               -- We use St_Union instead of St_Collect to ensure no overlapping points exist within the geometries
               -- to merge. https://postgis.net/docs/ST_Union.html
               -- ST_LineMerge only merges across singular intersections and groups its output into a MultiLineString
               -- if more than two LineStrings form an intersection or no intersection could be found.
               -- https://postgis.net/docs/ST_LineMerge.html
               -- In order to not end up with a mixture of LineStrings and MultiLineStrings we dump eventual
               -- MultiLineStrings via ST_Dump. https://postgis.net/docs/ST_Dump.html
               coalesce( array_agg(osm_id) FILTER (WHERE osm_id IS NOT NULL), '{}' )::BIGINT[] AS new_source_ids,
               array_cat_agg(source_ids)::BIGINT[] as old_source_ids,
               name,
               name_en,
               name_de,
               tags
        FROM clustered_linestrings_to_merge
        GROUP BY cluster_group, cluster, name, name_en, name_de, tags
        RETURNING id, new_source_ids, old_source_ids, geometry
    )
    -- Store OSM-IDs of Source-LineStrings by intersecting Merged-LineStrings with their sources.
    -- This is required because ST_LineMerge only merges across singular intersections and groups its output into a
    -- MultiLineString if more than two LineStrings form an intersection or no intersection could be found.
    INSERT INTO osm_important_waterway_linestring_source_ids (id, source_id)
    SELECT m.id, source_id
    FROM (
        SELECT id, source_id, geometry
        FROM inserted_linestrings
        CROSS JOIN LATERAL (
            SELECT DISTINCT all_source_ids.source_id
            FROM unnest(
                array_cat(inserted_linestrings.new_source_ids, inserted_linestrings.old_source_ids)
            ) AS all_source_ids(source_id)
        ) source_ids
    ) m
    JOIN osm_waterway_linestring s ON (m.source_id = s.osm_id)
    WHERE ST_Intersects(s.geometry, m.geometry)
    ON CONFLICT (id, source_id) DO NOTHING;

    -- Cleanup remaining table
    DROP TABLE clustered_linestrings_to_merge;

    -- Restore temporary Merged-LineString to Source-LineStrings-ID columns
    UPDATE osm_important_waterway_linestring SET new_source_ids = NULL WHERE new_source_ids IS NOT NULL;
    UPDATE osm_important_waterway_linestring SET old_source_ids = NULL WHERE old_source_ids IS NOT NULL;

    -- noinspection SqlWithoutWhere
    DELETE FROM waterway_important.changes;
    -- noinspection SqlWithoutWhere
    DELETE FROM waterway_important.updates;

    RAISE LOG 'Refresh waterway done in %', age(clock_timestamp(), t);

    -- Update z11, z10 and z9 tables
    PERFORM insert_important_waterway_linestring_gen(FALSE);

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_important_waterway_linestring_store
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_important_waterway_linestring
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE waterway_important.important_waterway_linestring_store();

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_waterway_linestring
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE waterway_important.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_waterway_linestring
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE waterway_important.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON waterway_important.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE waterway_important.refresh();

-- Layer waterway - ./waterway.sql

CREATE OR REPLACE FUNCTION waterway_brunnel(is_bridge bool, is_tunnel bool) RETURNS text AS
$$
SELECT CASE
           WHEN is_bridge THEN 'bridge'
           WHEN is_tunnel THEN 'tunnel'
           END;
$$ LANGUAGE SQL IMMUTABLE
                STRICT
                PARALLEL SAFE;
-- ne_110m_rivers_lake_centerlines
-- etldoc: ne_110m_rivers_lake_centerlines ->  ne_110m_rivers_lake_centerlines_gen_z3
DROP MATERIALIZED VIEW IF EXISTS ne_110m_rivers_lake_centerlines_gen_z3 CASCADE;
CREATE MATERIALIZED VIEW ne_110m_rivers_lake_centerlines_gen_z3 AS
(
SELECT ST_Simplify(geometry, ZRes(5)) as geometry,
       'river'::text AS class,
       NULL::text AS name,
       NULL::text AS name_en,
       NULL::text AS name_de,
       NULL::hstore AS tags,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel,
       NULL::boolean AS is_intermittent
FROM ne_110m_rivers_lake_centerlines
WHERE featurecla = 'River'
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_110m_rivers_lake_centerlines_gen_z3_idx ON ne_110m_rivers_lake_centerlines_gen_z3 USING gist (geometry);

-- ne_50m_rivers_lake_centerlines
-- etldoc: ne_50m_rivers_lake_centerlines ->  ne_50m_rivers_lake_centerlines_gen_z5
DROP MATERIALIZED VIEW IF EXISTS ne_50m_rivers_lake_centerlines_gen_z5 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_rivers_lake_centerlines_gen_z5 AS
(
SELECT ST_Simplify(geometry, ZRes(7)) as geometry,
       'river'::text AS class,
       NULL::text AS name,
       NULL::text AS name_en,
       NULL::text AS name_de,
       NULL::hstore AS tags,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel,
       NULL::boolean AS is_intermittent
FROM ne_50m_rivers_lake_centerlines
WHERE featurecla = 'River'
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_rivers_lake_centerlines_gen_z5_idx ON ne_50m_rivers_lake_centerlines_gen_z5 USING gist (geometry);

-- etldoc: ne_50m_rivers_lake_centerlines_gen_z5 ->  ne_50m_rivers_lake_centerlines_gen_z4
DROP MATERIALIZED VIEW IF EXISTS ne_50m_rivers_lake_centerlines_gen_z4 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_rivers_lake_centerlines_gen_z4 AS
(
SELECT ST_Simplify(geometry, ZRes(6)) as geometry,
       class,
       name,
       name_en,
       name_de,
       tags,
       is_bridge,
       is_tunnel,
       is_intermittent
FROM ne_50m_rivers_lake_centerlines_gen_z5
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_rivers_lake_centerlines_gen_z4_idx ON ne_50m_rivers_lake_centerlines_gen_z4 USING gist (geometry);

-- osm_waterway_relation
-- etldoc: osm_waterway_relation -> waterway_relation
DROP TABLE IF EXISTS waterway_relation CASCADE;
CREATE TABLE waterway_relation AS (
    SELECT ST_Union(geometry) AS geometry,
           name,
           slice_language_tags(tags) AS tags
    FROM osm_waterway_relation
    WHERE name <> ''
      AND (role = 'main_stream' OR role = '')
      AND ST_GeometryType(geometry) = 'ST_LineString'
      AND ST_IsClosed(geometry) = FALSE
    GROUP BY name, slice_language_tags(tags)
);
CREATE INDEX IF NOT EXISTS waterway_relation_geometry_idx ON waterway_relation USING gist (geometry);

-- etldoc: waterway_relation -> waterway_relation_gen_z8
DROP MATERIALIZED VIEW IF EXISTS waterway_relation_gen_z8 CASCADE;
CREATE MATERIALIZED VIEW waterway_relation_gen_z8 AS (
    SELECT ST_Simplify(geometry, ZRes(10)) AS geometry,
       'river'::text AS class,
       name,
       NULL::text AS name_en,
       NULL::text AS name_de,
       tags,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel,
       NULL::boolean AS is_intermittent
    FROM waterway_relation
    WHERE ST_Length(geometry) > 300000
) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS waterway_relation_gen_z8_geometry_idx ON waterway_relation_gen_z8 USING gist (geometry);

-- etldoc: waterway_relation_gen_z8 -> waterway_relation_gen_z7
DROP MATERIALIZED VIEW IF EXISTS waterway_relation_gen_z7 CASCADE;
CREATE MATERIALIZED VIEW waterway_relation_gen_z7 AS (
    SELECT ST_Simplify(geometry, ZRes(9)) AS geometry,
       class,
       name,
       name_en,
       name_de,
       tags,
       is_bridge,
       is_tunnel,
       is_intermittent
    FROM waterway_relation_gen_z8
    WHERE ST_Length(geometry) > 400000
) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS waterway_relation_gen_z7_geometry_idx ON waterway_relation_gen_z7 USING gist (geometry);

-- etldoc: waterway_relation_gen_z7 -> waterway_relation_gen_z6
DROP MATERIALIZED VIEW IF EXISTS waterway_relation_gen_z6 CASCADE;
CREATE MATERIALIZED VIEW waterway_relation_gen_z6 AS (
    SELECT ST_Simplify(geometry, ZRes(8)) AS geometry,
       class,
       name,
       name_en,
       name_de,
       tags,
       is_bridge,
       is_tunnel,
       is_intermittent
    FROM waterway_relation_gen_z7
    WHERE ST_Length(geometry) > 500000
) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS waterway_relation_gen_z6_geometry_idx ON waterway_relation_gen_z6 USING gist (geometry);


-- etldoc: ne_110m_rivers_lake_centerlines_gen_z3 ->  waterway_z3
CREATE OR REPLACE VIEW waterway_z3 AS
(
SELECT geometry,
       class,
       name,
       name_en,
       name_de,
       tags,
       is_bridge,
       is_tunnel,
       is_intermittent
FROM ne_110m_rivers_lake_centerlines_gen_z3
    );

-- etldoc: ne_50m_rivers_lake_centerlines_gen_z4 ->  waterway_z4
CREATE OR REPLACE VIEW waterway_z4 AS
(
SELECT geometry,
       class,
       name,
       name_en,
       name_de,
       tags,
       is_bridge,
       is_tunnel,
       is_intermittent
FROM ne_50m_rivers_lake_centerlines_gen_z4
    );

-- etldoc: ne_50m_rivers_lake_centerlines_gen_z5 ->  waterway_z5
CREATE OR REPLACE VIEW waterway_z5 AS
(
SELECT geometry,
       class,
       name,
       name_en,
       name_de,
       tags,
       is_bridge,
       is_tunnel,
       is_intermittent
FROM ne_50m_rivers_lake_centerlines_gen_z5
    );

-- etldoc: waterway_relation_gen_z6 ->  waterway_z6
CREATE OR REPLACE VIEW waterway_z6 AS
(
SELECT geometry,
       class,
       name,
       name_en,
       name_de,
       tags,
       is_bridge,
       is_tunnel,
       is_intermittent
FROM waterway_relation_gen_z6
    );

-- etldoc: waterway_relation_gen_z7 ->  waterway_z7
CREATE OR REPLACE VIEW waterway_z7 AS
(
SELECT geometry,
       class,
       name,
       name_en,
       name_de,
       tags,
       is_bridge,
       is_tunnel,
       is_intermittent
FROM waterway_relation_gen_z7
    );

-- etldoc: waterway_relation_gen_z8 ->  waterway_z8
CREATE OR REPLACE VIEW waterway_z8 AS
(
SELECT geometry,
       class,
       name,
       name_en,
       name_de,
       tags,
       is_bridge,
       is_tunnel,
       is_intermittent
FROM waterway_relation_gen_z8
    );

-- etldoc: osm_important_waterway_linestring_gen_z9 ->  waterway_z9
CREATE OR REPLACE VIEW waterway_z9 AS
(
SELECT geometry,
       'river'::text AS class,
       name,
       name_en,
       name_de,
       tags,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel,
       NULL::boolean AS is_intermittent
FROM osm_important_waterway_linestring_gen_z9
    );

-- etldoc: osm_important_waterway_linestring_gen_z10 ->  waterway_z10
CREATE OR REPLACE VIEW waterway_z10 AS
(
SELECT geometry,
       'river'::text AS class,
       name,
       name_en,
       name_de,
       tags,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel,
       NULL::boolean AS is_intermittent
FROM osm_important_waterway_linestring_gen_z10
    );

-- etldoc:osm_important_waterway_linestring_gen_z11 ->  waterway_z11
CREATE OR REPLACE VIEW waterway_z11 AS
(
SELECT geometry,
       'river'::text AS class,
       name,
       name_en,
       name_de,
       tags,
       NULL::boolean AS is_bridge,
       NULL::boolean AS is_tunnel,
       NULL::boolean AS is_intermittent
FROM osm_important_waterway_linestring_gen_z11
    );

-- etldoc: osm_waterway_linestring ->  waterway_z12
CREATE OR REPLACE VIEW waterway_z12 AS
(
SELECT geometry,
       waterway::text AS class,
       name,
       name_en,
       name_de,
       tags,
       is_bridge,
       is_tunnel,
       is_intermittent
FROM osm_waterway_linestring
WHERE waterway IN ('river', 'canal')
    );

-- etldoc: osm_waterway_linestring ->  waterway_z13
CREATE OR REPLACE VIEW waterway_z13 AS
(
SELECT geometry,
       waterway::text AS class,
       name,
       name_en,
       name_de,
       tags,
       is_bridge,
       is_tunnel,
       is_intermittent
FROM osm_waterway_linestring
WHERE waterway IN ('river', 'canal', 'stream', 'drain', 'ditch')
    );

-- etldoc: osm_waterway_linestring ->  waterway_z14
CREATE OR REPLACE VIEW waterway_z14 AS
(
SELECT geometry,
       waterway::text AS class,
       name,
       name_en,
       name_de,
       tags,
       is_bridge,
       is_tunnel,
       is_intermittent
FROM osm_waterway_linestring
    );

-- etldoc: layer_waterway[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc: label="layer_waterway | <z3> z3 |<z4> z4 |<z5> z5 |<z6> z6 |<z7> z7 |<z8> z8 | <z9> z9 |<z10> z10 |<z11> z11 |<z12> z12|<z13> z13|<z14> z14+" ];

CREATE OR REPLACE FUNCTION layer_waterway(bbox geometry, zoom_level int)
    RETURNS TABLE
            (
                geometry     geometry,
                class        text,
                name         text,
                name_en      text,
                name_de      text,
                brunnel      text,
                intermittent int,
                tags         hstore
            )
AS
$$
SELECT geometry,
       class,
       NULLIF(name, '') AS name,
       COALESCE(NULLIF(name_en, ''), NULLIF(name, '')) AS name_en,
       COALESCE(NULLIF(name_de, ''), NULLIF(name, ''), NULLIF(name_en, '')) AS name_de,
       waterway_brunnel(is_bridge, is_tunnel) AS brunnel,
       is_intermittent::int AS intermittent,
       tags
FROM (
         -- etldoc: waterway_z3 ->  layer_waterway:z3
         SELECT *
         FROM waterway_z3
         WHERE zoom_level = 3
         UNION ALL
         -- etldoc: waterway_z4 ->  layer_waterway:z4
         SELECT *
         FROM waterway_z4
         WHERE zoom_level = 4
         UNION ALL
         -- etldoc: waterway_z5 ->  layer_waterway:z5
         SELECT *
         FROM waterway_z5
         WHERE zoom_level = 5
         UNION ALL
         -- etldoc: waterway_z6 ->  layer_waterway:z6
         SELECT *
         FROM waterway_z6
         WHERE zoom_level = 6
         UNION ALL
         -- etldoc: waterway_z7 ->  layer_waterway:z7
         SELECT *
         FROM waterway_z7
         WHERE zoom_level = 7
         UNION ALL
         -- etldoc: waterway_z8 ->  layer_waterway:z8
         SELECT *
         FROM waterway_z8
         WHERE zoom_level = 8
         UNION ALL
         -- etldoc: waterway_z9 ->  layer_waterway:z9
         SELECT *
         FROM waterway_z9
         WHERE zoom_level = 9
         UNION ALL
         -- etldoc: waterway_z10 ->  layer_waterway:z10
         SELECT *
         FROM waterway_z10
         WHERE zoom_level = 10
         UNION ALL
         -- etldoc: waterway_z11 ->  layer_waterway:z11
         SELECT *
         FROM waterway_z11
         WHERE zoom_level = 11
         UNION ALL
         -- etldoc: waterway_z12 ->  layer_waterway:z12
         SELECT *
         FROM waterway_z12
         WHERE zoom_level = 12
         UNION ALL
         -- etldoc: waterway_z13 ->  layer_waterway:z13
         SELECT *
         FROM waterway_z13
         WHERE zoom_level = 13
         UNION ALL
         -- etldoc: waterway_z14 ->  layer_waterway:z14
         SELECT *
         FROM waterway_z14
         WHERE zoom_level >= 14
     ) AS zoom_levels
WHERE geometry && bbox;
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;

DO $$ BEGIN RAISE NOTICE 'Finished layer waterway'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer landcover'; END$$;

DO $$ BEGIN
    PERFORM 'ne_10m_antarctic_ice_shelves_polys'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "landcover"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_10m_glaciated_areas'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "landcover"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_50m_antarctic_ice_shelves_polys'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "landcover"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_50m_glaciated_areas'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "landcover"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_110m_glaciated_areas'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "landcover"';
END;
$$ LANGUAGE 'plpgsql';

-- Layer landcover - ./generalized.sql

DROP TABLE IF EXISTS osm_landcover_gen_z7;
DROP TABLE IF EXISTS osm_landcover_gen_z8;
DROP TABLE IF EXISTS osm_landcover_gen_z9;
DROP TABLE IF EXISTS osm_landcover_gen_z10;
DROP TABLE IF EXISTS osm_landcover_gen_z11;
DROP TABLE IF EXISTS osm_landcover_gen_z12;
DROP TABLE IF EXISTS osm_landcover_gen_z13;
DROP TABLE IF EXISTS simplify_vw_z7 CASCADE;
DROP TABLE IF EXISTS simplify_vw_z8 CASCADE;
DROP TABLE IF EXISTS simplify_vw_z9 CASCADE;
DROP TABLE IF EXISTS simplify_vw_z10 CASCADE;
DROP TABLE IF EXISTS simplify_vw_z11 CASCADE;
DROP TABLE IF EXISTS simplify_vw_z12 CASCADE;
DROP TABLE IF EXISTS simplify_vw_z13 CASCADE;

-- etldoc: osm_landcover_polygon ->  simplify_vw_z13
CREATE TABLE simplify_vw_z13 AS
(
    SELECT subclass,
           ST_MakeValid(
            ST_SnapToGrid(
             ST_SimplifyVW(geometry, power(zres(13),2)),
             0.001)) AS geometry
    FROM osm_landcover_polygon
    WHERE ST_Area(geometry) > power(zres(12),2)
);
CREATE INDEX ON simplify_vw_z13 USING GIST (geometry);

-- etldoc: simplify_vw_z13 ->  osm_landcover_gen_z13
CREATE TABLE osm_landcover_gen_z13 AS
(
    SELECT subclass, ST_MakeValid((ST_dump(ST_Union(geometry))).geom) AS geometry
    FROM (
        SELECT subclass,
               ST_ClusterDBSCAN(geometry, eps := 0, minpoints := 1) over () AS cid, geometry
        FROM simplify_vw_z13
        WHERE ST_NPoints(geometry) < 300
          AND subclass IN ('wood', 'forest')) union_geom300
    GROUP BY subclass,
             cid
    UNION ALL
    SELECT subclass,
           geometry
    FROM simplify_vw_z13
    WHERE (ST_NPoints(geometry) >= 300 AND subclass IN ('wood', 'forest'))
       OR (subclass NOT IN ('wood', 'forest'))
    );

CREATE INDEX ON osm_landcover_gen_z13 USING GIST (geometry);


-- etldoc: simplify_vw_z13 ->  simplify_vw_z12
CREATE TABLE simplify_vw_z12 AS
(
    SELECT subclass,
           ST_MakeValid(
            ST_SnapToGrid(
             ST_SimplifyVW(geometry, power(zres(12),2)),
             0.001)) AS geometry
    FROM simplify_vw_z13
    WHERE ST_Area(geometry) > power(zres(11),2)
);
CREATE INDEX ON simplify_vw_z12 USING GIST (geometry);

-- etldoc: simplify_vw_z12 ->  osm_landcover_gen_z12
CREATE TABLE osm_landcover_gen_z12 AS
(
    SELECT subclass, ST_MakeValid((ST_dump(ST_Union(geometry))).geom) AS geometry
    FROM (
        SELECT subclass,
               ST_ClusterDBSCAN(geometry, eps := 0, minpoints := 1) over () AS cid, geometry
        FROM simplify_vw_z12
        WHERE ST_NPoints(geometry) < 300
          AND subclass IN ('wood', 'forest')) union_geom300
    GROUP BY subclass,
             cid
    UNION ALL
    SELECT subclass,
           geometry
    FROM simplify_vw_z12
    WHERE (ST_NPoints(geometry) >= 300  AND subclass IN ('wood', 'forest'))
       OR (subclass NOT IN ('wood', 'forest'))
    );

CREATE INDEX ON osm_landcover_gen_z12 USING GIST (geometry);


-- etldoc: simplify_vw_z12 ->  simplify_vw_z11
CREATE TABLE simplify_vw_z11 AS
(
    SELECT subclass,
            ST_MakeValid(
            ST_SnapToGrid(
             ST_SimplifyVW(geometry, power(zres(11),2)),
             0.001)) AS geometry
    FROM simplify_vw_z12
    WHERE ST_Area(geometry) > power(zres(10),2)
);
CREATE INDEX ON simplify_vw_z11 USING GIST (geometry);

-- etldoc: simplify_vw_z11 ->  osm_landcover_gen_z11
CREATE TABLE osm_landcover_gen_z11 AS
(
    SELECT subclass, ST_MakeValid((ST_dump(ST_Union(geometry))).geom) AS geometry
    FROM (
        SELECT subclass,
               ST_ClusterDBSCAN(geometry, eps := 0, minpoints := 1) over () AS cid, geometry
        FROM simplify_vw_z11
        WHERE ST_NPoints(geometry) < 300
          AND subclass IN ('wood', 'forest')) union_geom300
    GROUP BY subclass,
             cid
    UNION ALL
    SELECT subclass,
           geometry
    FROM simplify_vw_z11
    WHERE (ST_NPoints(geometry) >= 300 AND subclass IN ('wood', 'forest'))
       OR (subclass NOT IN ('wood', 'forest'))
    );

CREATE INDEX ON osm_landcover_gen_z11 USING GIST (geometry);


-- etldoc: simplify_vw_z11 ->  simplify_vw_z10
CREATE TABLE simplify_vw_z10 AS
(
    SELECT subclass,
           ST_MakeValid(
            ST_SnapToGrid(
             ST_SimplifyVW(geometry, power(zres(10),2)),
             0.001)) AS geometry
    FROM simplify_vw_z11
    WHERE ST_Area(geometry) > power(zres(9),2)
);
CREATE INDEX ON simplify_vw_z10 USING GIST (geometry);

-- etldoc: simplify_vw_z10 ->  osm_landcover_gen_z10
CREATE TABLE osm_landcover_gen_z10 AS
(
    SELECT subclass, ST_MakeValid((ST_dump(ST_Union(geometry))).geom) AS geometry
    FROM (
        SELECT subclass,
               ST_ClusterDBSCAN(geometry, eps := 0, minpoints := 1) over () AS cid, geometry
        FROM simplify_vw_z10
        WHERE ST_NPoints(geometry) < 300
          AND subclass IN ('wood', 'forest')) union_geom300
    GROUP BY subclass,
             cid
    UNION ALL
    SELECT subclass,
           geometry
    FROM simplify_vw_z10
    WHERE (ST_NPoints(geometry) >= 300 AND subclass IN ('wood', 'forest'))
       OR (subclass NOT IN ('wood', 'forest'))
    );

CREATE INDEX ON osm_landcover_gen_z10 USING GIST (geometry);


-- etldoc: simplify_vw_z10 ->  simplify_vw_z9
CREATE TABLE simplify_vw_z9 AS
(
    SELECT subclass,
           ST_MakeValid(
            ST_SnapToGrid(
             ST_SimplifyVW(geometry, power(zres(9),2)),
             0.001)) AS geometry
    FROM simplify_vw_z10
    WHERE ST_Area(geometry) > power(zres(8),2)
);
CREATE INDEX ON simplify_vw_z9 USING GIST (geometry);

-- etldoc: simplify_vw_z9 ->  osm_landcover_gen_z9
CREATE TABLE osm_landcover_gen_z9 AS
(
    SELECT subclass, ST_MakeValid((ST_dump(ST_Union(geometry))).geom) AS geometry
    FROM (
        SELECT subclass,
               ST_ClusterDBSCAN(geometry, eps := 0, minpoints := 1) over () AS cid, geometry
        FROM simplify_vw_z9
        WHERE ST_NPoints(geometry) < 300
          AND subclass IN ('wood', 'forest')) union_geom300
    GROUP BY subclass,
             cid
    UNION ALL
    SELECT subclass,
           ST_MakeValid(
            (ST_Dump(
             ST_Union(geometry))).geom) AS geometry
    FROM (
        SELECT subclass,
               ST_ClusterDBSCAN(geometry, eps := 0, minpoints := 1) over () AS cid, geometry
        FROM simplify_vw_z9
        WHERE ST_NPoints(geometry) >= 300
          AND subclass IN ('wood', 'forest')) union_geom_rest
    GROUP BY subclass,
             cid
    UNION ALL
    SELECT subclass,
           geometry
    FROM simplify_vw_z9
    WHERE subclass NOT IN ('wood', 'forest')
    );

CREATE INDEX ON osm_landcover_gen_z9 USING GIST (geometry);


-- etldoc: simplify_vw_z9 ->  simplify_vw_z8
CREATE TABLE simplify_vw_z8 AS
(
    SELECT subclass,
           ST_MakeValid(
            ST_SnapToGrid(
             ST_SimplifyVW(geometry, power(zres(8),2)),
             0.001)) AS geometry
    FROM simplify_vw_z9
    WHERE ST_Area(geometry) > power(zres(7),2)
    );
CREATE INDEX ON simplify_vw_z8 USING GIST (geometry);

-- etldoc: simplify_vw_z8 ->  osm_landcover_gen_z8
CREATE TABLE osm_landcover_gen_z8 AS
(
SELECT subclass,
       ST_MakeValid(
        (ST_Dump(
         ST_Union(geometry))).geom) AS geometry
    FROM
        (
        SELECT subclass,
               ST_ClusterDBSCAN(geometry, eps := 0, minpoints := 1) OVER () AS cid,
               geometry
        FROM simplify_vw_z8
        WHERE subclass IN ('wood', 'forest')
        ) union_geom
    GROUP BY subclass,
             cid
    UNION ALL
    SELECT subclass,
           geometry
    FROM simplify_vw_z8
    WHERE subclass NOT IN ('wood', 'forest')
    );

CREATE INDEX ON osm_landcover_gen_z8 USING GIST (geometry);


-- etldoc: simplify_vw_z8 ->  simplify_vw_z7
CREATE TABLE simplify_vw_z7 AS
(
    SELECT subclass,
           ST_MakeValid(
            ST_SnapToGrid(
             ST_SimplifyVW(geometry, power(zres(7),2)),
             0.001)) AS geometry
    FROM simplify_vw_z8
    WHERE ST_Area(geometry) > power(zres(6),2)
);
CREATE INDEX ON simplify_vw_z7 USING GIST (geometry);

-- etldoc: simplify_vw_z7 ->  osm_landcover_gen_z7
CREATE TABLE osm_landcover_gen_z7 AS
(
SELECT subclass,
       ST_MakeValid(
        (ST_Dump(
         ST_Union(geometry))).geom) AS geometry
    FROM
        (
        SELECT  subclass,
                ST_ClusterDBSCAN(geometry, eps := 0, minpoints := 1) OVER () AS cid,
                geometry
        FROM simplify_vw_z7
        ) union_geom
GROUP BY subclass,
         cid
    );

CREATE INDEX ON osm_landcover_gen_z7 USING GIST (geometry);

DROP TABLE IF EXISTS simplify_vw_z7 CASCADE;
DROP TABLE IF EXISTS simplify_vw_z8 CASCADE;
DROP TABLE IF EXISTS simplify_vw_z9 CASCADE;
DROP TABLE IF EXISTS simplify_vw_z10 CASCADE;
DROP TABLE IF EXISTS simplify_vw_z11 CASCADE;
DROP TABLE IF EXISTS simplify_vw_z12 CASCADE;
DROP TABLE IF EXISTS simplify_vw_z13 CASCADE;

-- Layer landcover - ./landcover.sql

--TODO: Find a way to nicely generalize landcover
--CREATE TABLE IF NOT EXISTS landcover_grouped_gen2 AS (
--	SELECT osm_id, ST_Simplify((ST_Dump(geometry)).geom, 600) AS geometry, landuse, "natural", wetland
--	FROM (
--	  SELECT max(osm_id) AS osm_id, ST_Union(ST_Buffer(geometry, 600)) AS geometry, landuse, "natural", wetland
--	  FROM osm_landcover_polygon_gen1
--	  GROUP BY LabelGrid(geometry, 15000000), landuse, "natural", wetland
--	) AS grouped_measurements
--);
--CREATE INDEX IF NOT EXISTS landcover_grouped_gen2_geometry_idx ON landcover_grouped_gen2 USING gist(geometry);

CREATE OR REPLACE FUNCTION landcover_class(subclass varchar) RETURNS text AS
$$
SELECT CASE
           WHEN "subclass" IN ('farmland', 'farm', 'orchard', 'vineyard', 'plant_nursery') THEN 'farmland'
           WHEN "subclass" IN ('glacier', 'ice_shelf') THEN 'ice'
           WHEN "subclass" IN ('wood', 'forest') THEN 'wood'
           WHEN "subclass" IN ('bare_rock', 'scree') THEN 'rock'
           WHEN "subclass" IN ('fell', 'flowerbed', 'grassland', 'heath', 'scrub', 'shrubbery', 'tundra', 'grass', 'meadow', 'allotments', 'park', 'village_green', 'recreation_ground', 'garden', 'golf_course') THEN 'grass'
           WHEN "subclass" IN ('wetland', 'bog', 'swamp', 'wet_meadow', 'marsh', 'reedbed', 'saltern', 'tidalflat', 'saltmarsh', 'mangrove') THEN 'wetland'
           WHEN "subclass" IN ('beach', 'sand', 'dune') THEN 'sand'
           END;
$$ LANGUAGE SQL IMMUTABLE
                -- STRICT
                PARALLEL SAFE;

-- ne_50m_antarctic_ice_shelves_polys
-- etldoc: ne_50m_antarctic_ice_shelves_polys ->  ne_50m_antarctic_ice_shelves_polys_gen_z4
DROP MATERIALIZED VIEW IF EXISTS ne_50m_antarctic_ice_shelves_polys_gen_z4 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_antarctic_ice_shelves_polys_gen_z4 AS
(
SELECT
    ST_Simplify(geometry, ZRes(6)) as geometry,
    'ice_shelf'::text AS subclass
FROM ne_50m_antarctic_ice_shelves_polys
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_antarctic_ice_shelves_polys_gen_z4_idx ON ne_50m_antarctic_ice_shelves_polys_gen_z4 USING gist (geometry);

-- ne_110m_glaciated_areas
-- etldoc: ne_110m_glaciated_areas ->  ne_110m_glaciated_areas_gen_z1
DROP MATERIALIZED VIEW IF EXISTS ne_110m_glaciated_areas_gen_z1 CASCADE;
CREATE MATERIALIZED VIEW ne_110m_glaciated_areas_gen_z1 AS
(
SELECT
    ST_Simplify(geometry, ZRes(3)) as geometry,
    'glacier'::text AS subclass
FROM ne_110m_glaciated_areas
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_110m_glaciated_areas_gen_z1_idx ON ne_110m_glaciated_areas_gen_z1 USING gist (geometry);

-- etldoc: ne_110m_glaciated_areas_gen_z1 ->  ne_110m_glaciated_areas_gen_z0
DROP MATERIALIZED VIEW IF EXISTS ne_110m_glaciated_areas_gen_z0 CASCADE;
CREATE MATERIALIZED VIEW ne_110m_glaciated_areas_gen_z0 AS
(
SELECT
    ST_Simplify(geometry, ZRes(2)) as geometry,
    subclass
FROM ne_110m_glaciated_areas_gen_z1
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_110m_glaciated_areas_gen_z0_idx ON ne_110m_glaciated_areas_gen_z0 USING gist (geometry);

-- etldoc: ne_50m_antarctic_ice_shelves_polys_gen_z4 ->  ne_50m_antarctic_ice_shelves_polys_gen_z3
DROP MATERIALIZED VIEW IF EXISTS ne_50m_antarctic_ice_shelves_polys_gen_z3 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_antarctic_ice_shelves_polys_gen_z3 AS
(
SELECT
    ST_Simplify(geometry, ZRes(5)) as geometry,
    subclass
FROM ne_50m_antarctic_ice_shelves_polys_gen_z4
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_antarctic_ice_shelves_polys_gen_z3_idx ON ne_50m_antarctic_ice_shelves_polys_gen_z3 USING gist (geometry);

-- etldoc: ne_50m_antarctic_ice_shelves_polys_gen_z3 ->  ne_50m_antarctic_ice_shelves_polys_gen_z2
DROP MATERIALIZED VIEW IF EXISTS ne_50m_antarctic_ice_shelves_polys_gen_z2 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_antarctic_ice_shelves_polys_gen_z2 AS
(
SELECT
    ST_Simplify(geometry, ZRes(4)) as geometry,
    subclass
FROM ne_50m_antarctic_ice_shelves_polys_gen_z3
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_antarctic_ice_shelves_polys_gen_z2_idx ON ne_50m_antarctic_ice_shelves_polys_gen_z2 USING gist (geometry);

-- ne_50m_glaciated_areas
-- etldoc: ne_50m_glaciated_areas ->  ne_50m_glaciated_areas_gen_z4
DROP MATERIALIZED VIEW IF EXISTS ne_50m_glaciated_areas_gen_z4 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_glaciated_areas_gen_z4 AS
(
SELECT
    ST_Simplify(geometry, ZRes(6)) as geometry,
    'glacier'::text AS subclass
FROM ne_50m_glaciated_areas
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_glaciated_areas_gen_z4_idx ON ne_50m_glaciated_areas_gen_z4 USING gist (geometry);

-- etldoc: ne_50m_glaciated_areas_gen_z4 ->  ne_50m_glaciated_areas_gen_z3
DROP MATERIALIZED VIEW IF EXISTS ne_50m_glaciated_areas_gen_z3 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_glaciated_areas_gen_z3 AS
(
SELECT
    ST_Simplify(geometry, ZRes(5)) as geometry,
    subclass
FROM ne_50m_glaciated_areas_gen_z4
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_glaciated_areas_gen_z3_idx ON ne_50m_glaciated_areas_gen_z3 USING gist (geometry);

-- etldoc: ne_50m_glaciated_areas_gen_z3 ->  ne_50m_glaciated_areas_gen_z2
DROP MATERIALIZED VIEW IF EXISTS ne_50m_glaciated_areas_gen_z2 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_glaciated_areas_gen_z2 AS
(
SELECT
    ST_Simplify(geometry, ZRes(4)) as geometry,
    subclass
FROM ne_50m_glaciated_areas_gen_z3
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_glaciated_areas_gen_z2_idx ON ne_50m_glaciated_areas_gen_z2 USING gist (geometry);

-- ne_10m_glaciated_areas
-- etldoc: ne_10m_glaciated_areas ->  ne_10m_glaciated_areas_gen_z6
DROP MATERIALIZED VIEW IF EXISTS ne_10m_glaciated_areas_gen_z6 CASCADE;
CREATE MATERIALIZED VIEW ne_10m_glaciated_areas_gen_z6 AS
(
SELECT
    ST_Simplify(geometry, ZRes(8)) as geometry,
    'glacier'::text AS subclass
FROM ne_10m_glaciated_areas
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_10m_glaciated_areas_gen_z6_idx ON ne_10m_glaciated_areas_gen_z6 USING gist (geometry);

-- etldoc: ne_10m_glaciated_areas_gen_z6 ->  ne_10m_glaciated_areas_gen_z5
DROP MATERIALIZED VIEW IF EXISTS ne_10m_glaciated_areas_gen_z5 CASCADE;
CREATE MATERIALIZED VIEW ne_10m_glaciated_areas_gen_z5 AS
(
SELECT
    ST_Simplify(geometry, ZRes(7)) as geometry,
    subclass
FROM ne_10m_glaciated_areas_gen_z6
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_10m_glaciated_areas_gen_z5_idx ON ne_10m_glaciated_areas_gen_z5 USING gist (geometry);

-- ne_10m_antarctic_ice_shelves_polys
-- etldoc: ne_10m_antarctic_ice_shelves_polys ->  ne_10m_antarctic_ice_shelves_polys_gen_z6
DROP MATERIALIZED VIEW IF EXISTS ne_10m_antarctic_ice_shelves_polys_gen_z6 CASCADE;
CREATE MATERIALIZED VIEW ne_10m_antarctic_ice_shelves_polys_gen_z6 AS
(
SELECT
    ST_Simplify(geometry, ZRes(8)) as geometry,
    'ice_shelf'::text AS subclass
FROM ne_10m_antarctic_ice_shelves_polys
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_10m_antarctic_ice_shelves_polys_gen_z6_idx ON ne_10m_antarctic_ice_shelves_polys_gen_z6 USING gist (geometry);

-- etldoc: ne_10m_antarctic_ice_shelves_polys_gen_z6 ->  ne_10m_antarctic_ice_shelves_polys_gen_z5
DROP MATERIALIZED VIEW IF EXISTS ne_10m_antarctic_ice_shelves_polys_gen_z5 CASCADE;
CREATE MATERIALIZED VIEW ne_10m_antarctic_ice_shelves_polys_gen_z5 AS
(
SELECT
    ST_Simplify(geometry, ZRes(7)) as geometry,
    subclass
FROM ne_10m_antarctic_ice_shelves_polys_gen_z6
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_10m_antarctic_ice_shelves_polys_gen_z5_idx ON ne_10m_antarctic_ice_shelves_polys_gen_z5 USING gist (geometry);

-- etldoc: ne_110m_glaciated_areas_gen_z0 ->  landcover_z0
CREATE OR REPLACE VIEW landcover_z0 AS
(
SELECT
    geometry,
    subclass
FROM ne_110m_glaciated_areas_gen_z0
    );

-- etldoc: ne_110m_glaciated_areas_gen_z1 ->  landcover_z1
CREATE OR REPLACE VIEW landcover_z1 AS
(
SELECT
    geometry,
    subclass
FROM ne_110m_glaciated_areas_gen_z1
    );

CREATE OR REPLACE VIEW landcover_z2 AS
(
-- etldoc: ne_50m_glaciated_areas_gen_z2 ->  landcover_z2
SELECT
    geometry,
    subclass
FROM ne_50m_glaciated_areas_gen_z2
UNION ALL
-- etldoc: ne_50m_antarctic_ice_shelves_polys_gen_z2 ->  landcover_z2
SELECT
    geometry,
    subclass
FROM ne_50m_antarctic_ice_shelves_polys_gen_z2
    );

CREATE OR REPLACE VIEW landcover_z3 AS
(
-- etldoc: ne_50m_glaciated_areas_gen_z3 ->  landcover_z3
SELECT
    geometry,
    subclass
FROM ne_50m_glaciated_areas_gen_z3
UNION ALL
-- etldoc: ne_50m_antarctic_ice_shelves_polys_gen_z3 ->  landcover_z3
SELECT
    geometry,
    subclass
FROM ne_50m_antarctic_ice_shelves_polys_gen_z3
    );

CREATE OR REPLACE VIEW landcover_z4 AS
(
-- etldoc: ne_50m_glaciated_areas_gen_z4 ->  landcover_z4
SELECT
    geometry,
    subclass
FROM ne_50m_glaciated_areas_gen_z4
UNION ALL
-- etldoc: ne_50m_antarctic_ice_shelves_polys_gen_z4 ->  landcover_z4
SELECT
    geometry,
    subclass
FROM ne_50m_antarctic_ice_shelves_polys_gen_z4
    );

CREATE OR REPLACE VIEW landcover_z5 AS
(
-- etldoc: ne_10m_glaciated_areas_gen_z5 ->  landcover_z5
SELECT
    geometry,
    subclass
FROM ne_10m_glaciated_areas_gen_z5
UNION ALL
-- etldoc: ne_10m_antarctic_ice_shelves_polys_gen_z5 ->  landcover_z5
SELECT
    geometry,
    subclass
FROM ne_10m_antarctic_ice_shelves_polys_gen_z5
    );

CREATE OR REPLACE VIEW landcover_z6 AS
(
-- etldoc: ne_10m_glaciated_areas_gen_z6 ->  landcover_z6
SELECT
    geometry,
    subclass
FROM ne_10m_glaciated_areas_gen_z6
UNION ALL
-- etldoc: ne_10m_antarctic_ice_shelves_polys_gen_z6 ->  landcover_z6
SELECT
    geometry,
    subclass
FROM ne_10m_antarctic_ice_shelves_polys_gen_z6
    );

-- etldoc: layer_landcover[shape=record fillcolor=lightpink, style="rounded, filled", label="layer_landcover | <z0> z0 | <z1> z1 | <z2> z2 | <z3> z3 | <z4> z4 | <z5> z5 | <z6> z6 |<z7> z7 |<z8> z8 |<z9> z9 |<z10> z10 |<z11> z11 |<z12> z12|<z13> z13|<z14_> z14+" ] ;

CREATE OR REPLACE FUNCTION layer_landcover(bbox geometry, zoom_level int)
    RETURNS TABLE
            (
                geometry geometry,
                class    text,
                subclass text
            )
AS
$$
SELECT geometry,
       landcover_class(subclass) AS class,
       subclass
FROM (
         -- etldoc:  landcover_z0 -> layer_landcover:z0
         SELECT geometry, 
                subclass
         FROM landcover_z0
         WHERE zoom_level = 0
           AND geometry && bbox
         UNION ALL
         -- etldoc:  landcover_z1 -> layer_landcover:z1
         SELECT geometry,
                subclass
         FROM landcover_z1
         WHERE zoom_level = 1
           AND geometry && bbox
         UNION ALL
         -- etldoc:  landcover_z2 -> layer_landcover:z2
         SELECT geometry, 
                subclass
         FROM landcover_z2
         WHERE zoom_level = 2
           AND geometry && bbox
         UNION ALL
         -- etldoc:  landcover_z3 -> layer_landcover:z3
         SELECT geometry,
                subclass
         FROM landcover_z3
         WHERE zoom_level = 3
           AND geometry && bbox
         UNION ALL
         -- etldoc:  landcover_z4 -> layer_landcover:z4
         SELECT geometry,
                subclass
         FROM landcover_z4
         WHERE zoom_level = 4
           AND geometry && bbox
         UNION ALL
         -- etldoc:  landcover_z5 -> layer_landcover:z5
         SELECT geometry, 
                subclass
         FROM landcover_z5
         WHERE zoom_level = 5
           AND geometry && bbox
         UNION ALL
         -- etldoc:  landcover_z6 -> layer_landcover:z6
         SELECT geometry,
                subclass
         FROM landcover_z6
         WHERE zoom_level = 6
           AND geometry && bbox
         UNION ALL
         -- etldoc:  osm_landcover_gen_z7 -> layer_landcover:z7
         SELECT geometry, 
                subclass
         FROM osm_landcover_gen_z7
         WHERE zoom_level = 7
           AND geometry && bbox
         UNION ALL
         -- etldoc:  osm_landcover_gen_z8 -> layer_landcover:z8
         SELECT geometry, 
                subclass
         FROM osm_landcover_gen_z8
         WHERE zoom_level = 8
           AND geometry && bbox
         UNION ALL
         -- etldoc:  osm_landcover_gen_z9 -> layer_landcover:z9
         SELECT geometry, 
                subclass
         FROM osm_landcover_gen_z9
         WHERE zoom_level = 9
           AND geometry && bbox
         UNION ALL
         -- etldoc:  osm_landcover_gen_z10 -> layer_landcover:z10
         SELECT geometry, 
                subclass
         FROM osm_landcover_gen_z10
         WHERE zoom_level = 10
           AND geometry && bbox
         UNION ALL
         -- etldoc:  osm_landcover_gen_z11 -> layer_landcover:z11
         SELECT geometry, 
                subclass
         FROM osm_landcover_gen_z11
         WHERE zoom_level = 11
           AND geometry && bbox
         UNION ALL
         -- etldoc:  osm_landcover_gen_z12 -> layer_landcover:z12
         SELECT geometry, 
                subclass
         FROM osm_landcover_gen_z12
         WHERE zoom_level = 12
           AND geometry && bbox
         UNION ALL
         -- etldoc:  osm_landcover_gen_z13 -> layer_landcover:z13
         SELECT geometry, 
                subclass
         FROM osm_landcover_gen_z13
         WHERE zoom_level = 13
           AND geometry && bbox
         UNION ALL
         -- etldoc:  osm_landcover_polygon -> layer_landcover:z14_
         SELECT geometry, 
                subclass
         FROM osm_landcover_polygon
         WHERE zoom_level >= 14
           AND geometry && bbox
     ) AS zoom_levels;
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;

DO $$ BEGIN RAISE NOTICE 'Finished layer landcover'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer landuse'; END$$;

DO $$ BEGIN
    PERFORM 'ne_50m_urban_areas'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "landuse"';
END;
$$ LANGUAGE 'plpgsql';

-- Layer landuse - ./class.sql

-- Unify class names that represent the same type of feature
CREATE OR REPLACE FUNCTION landuse_unify(class text) RETURNS text LANGUAGE plpgsql
AS
$$
BEGIN
  RETURN CASE
    WHEN class='grave_yard' THEN 'cemetery'
    ELSE class END;
END;
$$;

-- Layer landuse - ./prep_landuse.sql

DROP TABLE IF EXISTS cluster_zres14;
CREATE TABLE cluster_zres14 AS 
(
WITH single_geom AS (
        SELECT (ST_Dump(geometry)).geom AS geometry
        FROM osm_landuse_polygon 
        WHERE landuse='residential'
    )
    SELECT ST_ClusterDBSCAN(geometry, eps := zres(14), minpoints := 1) over () AS cid,
           geometry
    FROM single_geom
);
CREATE INDEX ON cluster_zres14 USING gist(geometry);


DROP TABLE IF EXISTS cluster_zres14_union;
CREATE TABLE cluster_zres14_union AS (
SELECT ST_Buffer(
            ST_Union(
                ST_Buffer(
                    ST_SnapToGrid(geometry, 0.01)
                    , zres(14), 'join=mitre'
                )
            ),-zres(14), 'join=mitre'
        ) AS geometry
FROM cluster_zres14
GROUP BY cid
);
CREATE INDEX ON cluster_zres14_union USING gist(geometry);


DROP TABLE IF EXISTS cluster_zres12;
CREATE TABLE cluster_zres12 AS 
(
WITH single_geom AS (
    SELECT (ST_Dump(geometry)).geom AS geometry
    FROM osm_landuse_polygon 
    WHERE landuse='residential'
    )
    SELECT ST_ClusterDBSCAN(geometry, eps := zres(12), minpoints := 1) over () AS cid,
           geometry
    FROM single_geom
);
CREATE INDEX ON cluster_zres12 USING gist(geometry);


DROP TABLE IF EXISTS cluster_zres12_union;
CREATE TABLE cluster_zres12_union AS 
(
SELECT ST_Buffer(
            ST_Union(
                ST_Buffer(
                    ST_SnapToGrid(geometry, 1)
                        , zres(12), 'join=mitre'
                    )
                ), -zres(12), 'join=mitre'
            ) AS geometry
FROM cluster_zres12
GROUP BY cid
);
CREATE INDEX ON cluster_zres12_union USING gist(geometry);


DROP TABLE IF EXISTS cluster_zres9;
CREATE TABLE cluster_zres9 AS 
(
WITH single_geom AS (
        SELECT (ST_Dump(geometry)).geom AS geometry
        FROM osm_landuse_polygon 
        WHERE landuse='residential'
    )
    SELECT ST_ClusterDBSCAN(geometry, eps := zres(9), minpoints := 1) over () AS cid,
           geometry
    FROM single_geom
);
CREATE INDEX ON cluster_zres9 USING gist(geometry);


DROP TABLE IF EXISTS cluster_zres9_union;
CREATE TABLE cluster_zres9_union AS 
(
SELECT ST_Buffer(
            ST_Union(
                ST_Buffer(
                    ST_SnapToGrid(geometry, 1)
                        , zres(9), 'join=mitre'
                    )
                ), -zres(9), 'join=mitre'
            ) AS geometry
FROM cluster_zres9
GROUP BY cid
);
CREATE INDEX ON cluster_zres9_union USING gist(geometry);

-- For z6
-- etldoc: osm_landuse_polygon ->  osm_residential_gen_z6
DROP TABLE IF EXISTS osm_residential_gen_z6 CASCADE;
CREATE TABLE osm_residential_gen_z6 AS
(
SELECT ST_SimplifyVW(geometry, power(zres(6), 2)) AS geometry
FROM cluster_zres9_union
WHERE ST_Area(geometry) > power(zres(6), 2)
);
CREATE INDEX ON osm_residential_gen_z6 USING gist(geometry);


-- For z7
-- etldoc: osm_landuse_polygon ->  osm_residential_gen_z7
DROP TABLE IF EXISTS osm_residential_gen_z7 CASCADE;
CREATE TABLE osm_residential_gen_z7 AS
(
SELECT ST_SimplifyVW(geometry, power(zres(7), 2)) AS geometry
FROM cluster_zres12_union
WHERE ST_Area(geometry) > power(zres(6), 2)
);
CREATE INDEX ON osm_residential_gen_z7 USING gist(geometry);


-- For z8
-- etldoc: osm_landuse_polygon ->  osm_residential_gen_z8
DROP TABLE IF EXISTS osm_residential_gen_z8 CASCADE;
CREATE TABLE osm_residential_gen_z8 AS
(
SELECT ST_SimplifyVW(geometry, power(zres(8), 2)) AS geometry
FROM cluster_zres12_union
WHERE ST_Area(geometry) > power(zres(7), 2)
);
CREATE INDEX ON osm_residential_gen_z8 USING gist(geometry);


-- For z9
-- etldoc: osm_landuse_polygon ->  osm_residential_gen_z9
DROP TABLE IF EXISTS osm_residential_gen_z9 CASCADE;
CREATE TABLE osm_residential_gen_z9 AS
(
SELECT ST_SimplifyVW(geometry, power(zres(9), 2)) AS geometry
FROM cluster_zres12_union
WHERE ST_Area(geometry) > power(zres(9), 2)
);
CREATE INDEX ON osm_residential_gen_z9 USING gist(geometry);


-- For z10
-- etldoc: osm_landuse_polygon ->  osm_residential_gen_z10
DROP TABLE IF EXISTS osm_residential_gen_z10 CASCADE;
CREATE TABLE osm_residential_gen_z10 AS
(
SELECT ST_SimplifyVW(geometry, power(zres(10), 2)) AS geometry
FROM cluster_zres14_union
WHERE ST_Area(geometry) > power(zres(10), 2)
);
CREATE INDEX ON osm_residential_gen_z10 USING gist(geometry);


-- For z11
-- etldoc: osm_landuse_polygon ->  osm_residential_gen_z11
DROP TABLE IF EXISTS osm_residential_gen_z11 CASCADE;
CREATE TABLE osm_residential_gen_z11 AS
(
SELECT ST_SimplifyVW(geometry, power(zres(11), 2)) AS geometry
FROM cluster_zres14_union
WHERE ST_Area(geometry) > power(zres(11), 2)
);
CREATE INDEX ON osm_residential_gen_z11 USING gist(geometry);


-- For z12
-- etldoc: osm_landuse_polygon ->  osm_residential_gen_z12
DROP TABLE IF EXISTS osm_residential_gen_z12 CASCADE;
CREATE TABLE osm_residential_gen_z12 AS
(
SELECT ST_SimplifyVW(geometry, power(zres(12), 2)) AS geometry
FROM cluster_zres14_union
WHERE ST_Area(geometry) > power(zres(12), 2)
);
CREATE INDEX ON osm_residential_gen_z12 USING gist(geometry);

-- Layer landuse - ./landuse.sql

-- ne_50m_urban_areas
-- etldoc: ne_50m_urban_areas ->  ne_50m_urban_areas_gen_z5
DROP MATERIALIZED VIEW IF EXISTS ne_50m_urban_areas_gen_z5 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_urban_areas_gen_z5 AS
(
SELECT
       NULL::bigint AS osm_id,
       ST_Simplify(geometry, ZRes(7)) as geometry,
       'residential'::text AS landuse,
       NULL::text AS amenity,
       NULL::text AS leisure,
       NULL::text AS tourism,
       NULL::text AS place,
       NULL::text AS waterway,
       NULL::text AS parking,
       NULL::text AS access,
       scalerank
FROM ne_50m_urban_areas
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_urban_areas_gen_z5_idx ON ne_50m_urban_areas_gen_z5 USING gist (geometry);

-- etldoc: ne_50m_urban_areas_gen_z5 ->  ne_50m_urban_areas_gen_z4
DROP MATERIALIZED VIEW IF EXISTS ne_50m_urban_areas_gen_z4 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_urban_areas_gen_z4 AS
(
SELECT
       osm_id,
       ST_Simplify(geometry, ZRes(6)) as geometry,
       landuse,
       amenity,
       leisure,
       tourism,
       place,
       waterway,
       parking,
       access
FROM ne_50m_urban_areas_gen_z5
WHERE scalerank <= 2
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_urban_areas_gen_z4_idx ON ne_50m_urban_areas_gen_z4 USING gist (geometry);

-- etldoc: osm_landuse_polygon_gen_z6 ->  osm_landuse_polygon_gen_z6_union
-- etldoc: osm_residential_gen_z6 ->  osm_landuse_polygon_gen_z6_union
CREATE OR REPLACE VIEW osm_landuse_polygon_gen_z6_union AS
(
       SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z6
		 WHERE landuse <> 'residential'
       UNION ALL
       SELECT NULL::bigint AS osm_id,
              geometry,
              'residential' AS landuse,
              '' AS amenity,
              '' AS leisure,
              '' AS tourism,
              '' AS place,
              '' AS waterway,
              '' AS parking,
              '' AS access
         FROM osm_residential_gen_z6
);

-- etldoc: osm_landuse_polygon_gen_z7 ->  osm_landuse_polygon_gen_z7_union
-- etldoc: osm_residential_gen_z7 ->  osm_landuse_polygon_gen_z7_union
CREATE OR REPLACE VIEW osm_landuse_polygon_gen_z7_union AS
(
       SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z7
		 WHERE landuse <> 'residential'
       UNION ALL
       SELECT NULL::bigint AS osm_id,
              geometry,
              'residential' AS landuse,
              '' AS amenity,
              '' AS leisure,
              '' AS tourism,
              '' AS place,
              '' AS waterway,
              '' AS parking,
              '' AS access
         FROM osm_residential_gen_z7
);

-- etldoc: osm_landuse_polygon_gen_z8 ->  osm_landuse_polygon_gen_z8_union
-- etldoc: osm_residential_gen_z8 ->  osm_landuse_polygon_gen_z8_union
CREATE OR REPLACE VIEW osm_landuse_polygon_gen_z8_union AS
(
       SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z8
		 WHERE landuse <> 'residential'
       UNION ALL
       SELECT NULL::bigint AS osm_id,
              geometry,
              'residential' AS landuse,
              '' AS amenity,
              '' AS leisure,
              '' AS tourism,
              '' AS place,
              '' AS waterway,
              '' AS parking,
              '' AS access
         FROM osm_residential_gen_z8
);

-- etldoc: osm_landuse_polygon_gen_z9 ->  osm_landuse_polygon_gen_z9_union
-- etldoc: osm_residential_gen_z9 ->  osm_landuse_polygon_gen_z9_union
CREATE OR REPLACE VIEW osm_landuse_polygon_gen_z9_union AS
(
       SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z9
		 WHERE landuse <> 'residential'
       UNION ALL
       SELECT NULL::bigint AS osm_id,
              geometry,
              'residential' AS landuse,
              '' AS amenity,
              '' AS leisure,
              '' AS tourism,
              '' AS place,
              '' AS waterway,
              '' AS parking,
              '' AS access
         FROM osm_residential_gen_z9
);

-- etldoc: osm_landuse_polygon_gen_z10 ->  osm_landuse_polygon_gen_z10_union
-- etldoc: osm_residential_gen_z10 ->  osm_landuse_polygon_gen_z10_union
CREATE OR REPLACE VIEW osm_landuse_polygon_gen_z10_union AS
(
       SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z10
		 WHERE landuse <> 'residential'
       UNION ALL
       SELECT NULL::bigint AS osm_id,
              geometry,
              'residential' AS landuse,
              '' AS amenity,
              '' AS leisure,
              '' AS tourism,
              '' AS place,
              '' AS waterway,
              '' AS parking,
              '' AS access
         FROM osm_residential_gen_z10
);

-- etldoc: osm_landuse_polygon_gen_z11 ->  osm_landuse_polygon_gen_z11_union
-- etldoc: osm_residential_gen_z11 ->  osm_landuse_polygon_gen_z11_union
CREATE OR REPLACE VIEW osm_landuse_polygon_gen_z11_union AS
(
       SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z11
		 WHERE landuse <> 'residential'
       UNION ALL
       SELECT NULL::bigint AS osm_id,
              geometry,
              'residential' AS landuse,
              '' AS amenity,
              '' AS leisure,
              '' AS tourism,
              '' AS place,
              '' AS waterway,
              '' AS parking,
              '' AS access
         FROM osm_residential_gen_z11
);

-- etldoc: osm_landuse_polygon_gen_z12 ->  osm_landuse_polygon_gen_z12_union
-- etldoc: osm_residential_gen_z12 ->  osm_landuse_polygon_gen_z12_union
CREATE OR REPLACE VIEW osm_landuse_polygon_gen_z12_union AS
(
       SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z12
		 WHERE landuse <> 'residential'
       UNION ALL
       SELECT NULL::bigint AS osm_id,
              geometry,
              'residential' AS landuse,
              '' AS amenity,
              '' AS leisure,
              '' AS tourism,
              '' AS place,
              '' AS waterway,
              '' AS parking,
              '' AS access
         FROM osm_residential_gen_z12
);

-- etldoc: layer_landuse[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="layer_landuse |<z4> z4|<z5> z5|<z6> z6|<z7> z7|<z8> z8|<z9> z9|<z10> z10|<z11> z11|<z12> z12|<z13> z13|<z14> z14+" ] ;

CREATE OR REPLACE FUNCTION layer_landuse(bbox geometry, zoom_level int)
    RETURNS TABLE
            (
                osm_id   bigint,
                geometry geometry,
                class    text,
                subclass    text,
                access    text
            )
AS
$$
SELECT osm_id,
       geometry,
       landuse_unify(
         COALESCE(
               NULLIF(landuse, ''),
               NULLIF(amenity, ''),
               NULLIF(leisure, ''),
               NULLIF(tourism, ''),
               NULLIF(place, ''),
               NULLIF(waterway, '')
           )) AS class,
       NULLIF(parking, '') as subclass,
       CASE WHEN access IN ('private', 'no') THEN 'no' END AS access
FROM (
         -- etldoc: ne_50m_urban_areas_gen_z4 -> layer_landuse:z4
         SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM ne_50m_urban_areas_gen_z4
         WHERE zoom_level = 4
         UNION ALL
         -- etldoc: ne_50m_urban_areas_gen_z5 -> layer_landuse:z5
         SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM ne_50m_urban_areas_gen_z5
         WHERE zoom_level = 5
         UNION ALL
         -- etldoc: osm_landuse_polygon_gen_z6_union -> layer_landuse:z6
         SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z6_union
         WHERE zoom_level = 6
         UNION ALL
         -- etldoc: osm_landuse_polygon_gen_z7_union -> layer_landuse:z7
         SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z7_union
         WHERE zoom_level = 7
         UNION ALL
         -- etldoc: osm_landuse_polygon_gen_z8_union -> layer_landuse:z8
         SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z8_union
         WHERE zoom_level = 8
         UNION ALL
         -- etldoc: osm_landuse_polygon_gen_z9_union -> layer_landuse:z9
         SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z9_union
         WHERE zoom_level = 9
         UNION ALL
         -- etldoc: osm_landuse_polygon_gen_z10_union -> layer_landuse:z10
         SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z10_union
         WHERE zoom_level = 10
         UNION ALL
         -- etldoc: osm_landuse_polygon_gen_z11_union -> layer_landuse:z11
         SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z11_union
         WHERE zoom_level = 11
         UNION ALL
         -- etldoc: osm_landuse_polygon_gen_z12_union -> layer_landuse:z12
         SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z12_union
         WHERE zoom_level = 12
         UNION ALL
         -- etldoc: osm_landuse_polygon_gen_z13 -> layer_landuse:z13
         SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon_gen_z13
         WHERE zoom_level = 13
         UNION ALL
         -- etldoc: osm_landuse_polygon -> layer_landuse:z14
         SELECT osm_id,
                geometry,
                landuse,
                amenity,
                leisure,
                tourism,
                place,
                waterway,
                parking,
                access
         FROM osm_landuse_polygon
         WHERE zoom_level >= 14
     ) AS zoom_levels
WHERE geometry && bbox;
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;

DO $$ BEGIN RAISE NOTICE 'Finished layer landuse'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer mountain_peak'; END$$;

DO $$ BEGIN
    PERFORM 'ne_10m_admin_0_countries'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "mountain_peak"';
END;
$$ LANGUAGE 'plpgsql';

-- Layer mountain_peak - ./update_peak_point.sql

DROP TRIGGER IF EXISTS trigger_flag ON osm_peak_point;
DROP TRIGGER IF EXISTS trigger_store ON osm_peak_point;
DROP TRIGGER IF EXISTS trigger_refresh ON mountain_peak_point.updates;

CREATE SCHEMA IF NOT EXISTS mountain_peak_point;

CREATE TABLE IF NOT EXISTS mountain_peak_point.osm_ids
(
    osm_id bigint PRIMARY KEY
);

-- etldoc:  osm_peak_point ->  osm_peak_point
CREATE OR REPLACE FUNCTION update_osm_peak_point(full_update boolean) RETURNS void AS
$$
    UPDATE osm_peak_point
    SET tags = update_tags(tags, geometry)
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM mountain_peak_point.osm_ids))
      AND COALESCE(tags -> 'name:latin', tags -> 'name:nonlatin', tags -> 'name_int') IS NULL
      AND tags != update_tags(tags, geometry)
$$ LANGUAGE SQL;

SELECT update_osm_peak_point(true);

-- Handle updates

CREATE OR REPLACE FUNCTION mountain_peak_point.store() RETURNS trigger AS
$$
BEGIN
    INSERT INTO mountain_peak_point.osm_ids VALUES (NEW.osm_id) ON CONFLICT (osm_id) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS mountain_peak_point.updates
(
    id serial PRIMARY KEY,
    t  text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION mountain_peak_point.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO mountain_peak_point.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mountain_peak_point.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh mountain_peak_point';

    -- Analyze tracking and source tables before performing update
    ANALYZE mountain_peak_point.osm_ids;
    ANALYZE osm_peak_point;

    PERFORM update_osm_peak_point(false);
    -- noinspection SqlWithoutWhere
    DELETE FROM mountain_peak_point.osm_ids;
    -- noinspection SqlWithoutWhere
    DELETE FROM mountain_peak_point.updates;

    RAISE LOG 'Refresh mountain_peak_point done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE
    ON osm_peak_point
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE mountain_peak_point.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE
    ON osm_peak_point
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE mountain_peak_point.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON mountain_peak_point.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE mountain_peak_point.refresh();

-- Layer mountain_peak - ./update_mountain_linestring.sql

DROP TRIGGER IF EXISTS trigger_flag ON osm_mountain_linestring;
DROP TRIGGER IF EXISTS trigger_store ON osm_mountain_linestring;
DROP TRIGGER IF EXISTS trigger_refresh ON mountain_linestring.updates;

CREATE SCHEMA IF NOT EXISTS mountain_linestring;

CREATE TABLE IF NOT EXISTS mountain_linestring.osm_ids
(
    osm_id bigint PRIMARY KEY
);

-- etldoc:  osm_mountain_linestring ->  osm_mountain_linestring
CREATE OR REPLACE FUNCTION update_osm_mountain_linestring(full_update boolean) RETURNS void AS
$$
    UPDATE osm_mountain_linestring
    SET tags = update_tags(tags, geometry)
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM mountain_linestring.osm_ids))
      AND COALESCE(tags -> 'name:latin', tags -> 'name:nonlatin', tags -> 'name_int') IS NULL
      AND tags != update_tags(tags, geometry)
$$ LANGUAGE SQL;

SELECT update_osm_mountain_linestring(true);

-- Handle updates

CREATE OR REPLACE FUNCTION mountain_linestring.store() RETURNS trigger AS
$$
BEGIN
    INSERT INTO mountain_linestring.osm_ids VALUES (NEW.osm_id) ON CONFLICT (osm_id) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS mountain_linestring.updates
(
    id serial PRIMARY KEY,
    t  text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION mountain_linestring.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO mountain_linestring.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mountain_linestring.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh mountain_linestring';

    -- Analyze tracking and source tables before performing update
    ANALYZE mountain_linestring.osm_ids;
    ANALYZE osm_mountain_linestring;

    PERFORM update_osm_mountain_linestring(false);
    -- noinspection SqlWithoutWhere
    DELETE FROM mountain_linestring.osm_ids;
    -- noinspection SqlWithoutWhere
    DELETE FROM mountain_linestring.updates;

    RAISE LOG 'Refresh mountain_linestring done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE
    ON osm_mountain_linestring
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE mountain_linestring.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE
    ON osm_mountain_linestring
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE mountain_linestring.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON mountain_linestring.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE mountain_linestring.refresh();

-- Layer mountain_peak - ./mountain_peak.sql

-- etldoc: osm_peak_point -> peak_point
-- etldoc: ne_10m_admin_0_countries -> peak_point
CREATE OR REPLACE VIEW peak_point AS
(
SELECT pp.osm_id,
       pp.geometry,
       pp.name,
       pp.name_en,
       pp.name_de,
       pp.tags,
       pp.ele,
       ne.iso_a2,
       pp.wikipedia
FROM osm_peak_point pp, ne_10m_admin_0_countries ne
WHERE ST_Intersects(pp.geometry, ne.geometry)
    );



-- etldoc: layer_mountain_peak[shape=record fillcolor=lightpink,
-- etldoc:     style="rounded,filled", label="layer_mountain_peak | <z7_> z7+ | <z13_> z13+" ] ;

CREATE OR REPLACE FUNCTION layer_mountain_peak(bbox geometry,
                                               zoom_level integer,
                                               pixel_width numeric)
    RETURNS TABLE
            (
                osm_id          bigint,
                geometry        geometry,
                name            text,
                name_en         text,
                name_de         text,
                class           text,
                tags            hstore,
                ele             int,
                ele_ft          int,
                customary_ft    int,
                "rank"          int
            )
AS
$$
SELECT
    -- etldoc: peak_point -> layer_mountain_peak:z7_
    osm_id,
    geometry,
    name,
    name_en,
    name_de,
    tags->'natural' AS class,
    tags,
    ele::int,
    ele_ft::int,
    customary_ft,
    rank::int
FROM (
         SELECT osm_id,
                geometry,
                NULLIF(name, '') as name,
                COALESCE(NULLIF(name_en, ''), NULLIF(name, '')) AS name_en,
                COALESCE(NULLIF(name_de, ''), NULLIF(name, ''), NULLIF(name_en, '')) AS name_de,
                tags,
                substring(ele FROM E'^(-?\\d+)(\\D|$)')::int AS ele,
                round(substring(ele FROM E'^(-?\\d+)(\\D|$)')::int * 3.2808399)::int AS ele_ft,
                CASE WHEN iso_a2 = 'US' THEN 1 END AS customary_ft,
                row_number() OVER (
                    PARTITION BY LabelGrid(geometry, 100 * pixel_width)
                    ORDER BY (
                            (CASE WHEN ele <> '' THEN substring(ele FROM E'^(-?\\d+)(\\D|$)')::int ELSE 0 END) +
                            (CASE WHEN wikipedia <> '' THEN 10000 ELSE 0 END) +
                            (CASE WHEN name <> '' THEN 10000 ELSE 0 END)
                        ) DESC
                    )::int AS "rank"
         FROM peak_point
         WHERE geometry && bbox
           AND (
            (ele <> '' AND ele ~ E'^-?\\d{1,4}(\\D|$)')
            OR name <> ''
           )
     ) AS ranked_peaks
WHERE zoom_level >= 7
  AND (rank <= 5 OR zoom_level >= 14)

UNION ALL

SELECT
    -- etldoc: osm_mountain_linestring -> layer_mountain_peak:z13_
    osm_id,
    geometry,
    name,
    name_en,
    name_de,
    tags->'natural' AS class,
    tags,
    NULL AS ele,
    NULL AS ele_ft,
    NULL AS customary_ft,
    rank::int
FROM (
         SELECT osm_id,
                geometry,
                name,
                COALESCE(NULLIF(name_en, ''), name) AS name_en,
                COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
                tags,
                row_number() OVER (
                    PARTITION BY LabelGrid(geometry, 100 * pixel_width)
                    ORDER BY (
                            (CASE WHEN wikipedia <> '' THEN 10000 ELSE 0 END) +
                            (CASE WHEN name <> '' THEN 10000 ELSE 0 END)
                        ) DESC
                    )::int AS "rank"
         FROM osm_mountain_linestring
         WHERE geometry && bbox
     ) AS ranked_mountain_linestring
WHERE zoom_level >= 13
ORDER BY "rank" ASC;

$$ LANGUAGE SQL STABLE
                PARALLEL SAFE;
-- TODO: Check if the above can be made STRICT -- i.e. if pixel_width could be NULL

DO $$ BEGIN RAISE NOTICE 'Finished layer mountain_peak'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer park'; END$$;

-- Layer park - ./class.sql



CREATE OR REPLACE FUNCTION protect_class_map(protect_class text)
    RETURNS text AS
$$
SELECT CASE 
    WHEN protect_class = '1a' THEN 'conservation'
    WHEN protect_class = '1b' THEN 'wilderness_preserve'
    WHEN protect_class = '2' THEN 'national_park'
    WHEN protect_class = '3' THEN 'conservation'
    WHEN protect_class = '4' THEN 'wildlife_refuge'
    WHEN protect_class = '5' THEN 'conservation'
    WHEN protect_class = '6' THEN 'sustainable'
    ELSE NULL
END;
$$ LANGUAGE SQL IMMUTABLE
                PARALLEL SAFE;

CREATE OR REPLACE FUNCTION park_class(boundary text, leisure text, landuse text, historic text, maritime boolean, tags hstore)
    RETURNS text AS
$$
SELECT CASE 
    WHEN maritime = TRUE THEN 'marine'
    WHEN boundary = 'national_park' THEN 'national_park'
    WHEN boundary = 'protected_area' THEN 
        COALESCE(
            NULLIF(tags->'protected_area', ''),
            protect_class_map(tags->'protect_class'),
            NULLIF(tags->'protection_title', ''),
            'protected_area'
        )
    WHEN leisure = 'nature_reserve' THEN 'nature_reserve'
    WHEN landuse = 'recreation_ground' THEN 'recreation_ground'
    WHEN historic <> '' THEN 'historic'
    ELSE 'nature_reserve' END;
$$ LANGUAGE SQL IMMUTABLE
                PARALLEL SAFE;

-- Layer park - ./update_park_polygon.sql

ALTER TABLE osm_park_polygon
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_park_polygon_gen_z13
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_park_polygon_gen_z12
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_park_polygon_gen_z11
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_park_polygon_gen_z10
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_park_polygon_gen_z9
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_park_polygon_gen_z8
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_park_polygon_gen_z7
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_park_polygon_gen_z6
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_park_polygon_gen_z5
    ADD COLUMN IF NOT EXISTS geometry_point geometry;

-- etldoc:  osm_park_polygon_gen_z4 -> osm_park_polygon_dissolve_z4
DROP MATERIALIZED VIEW IF EXISTS osm_park_polygon_dissolve_z4 CASCADE;
CREATE MATERIALIZED VIEW osm_park_polygon_dissolve_z4 AS
(
  SELECT min(osm_id) AS osm_id,
         ST_Union(geometry) AS geometry,
         boundary
  FROM (
        SELECT ST_ClusterDBSCAN(geometry, 0, 1) OVER() AS cluster,
               osm_id,
               geometry,
               boundary
        FROM osm_park_polygon_gen_z4
  ) park_cluster
  GROUP BY boundary, cluster
);
CREATE UNIQUE INDEX IF NOT EXISTS osm_park_polygon_dissolve_idx ON osm_park_polygon_dissolve_z4 (osm_id);

DROP TRIGGER IF EXISTS update_row ON osm_park_polygon;
DROP TRIGGER IF EXISTS update_row ON osm_park_polygon_gen_z13;
DROP TRIGGER IF EXISTS update_row ON osm_park_polygon_gen_z12;
DROP TRIGGER IF EXISTS update_row ON osm_park_polygon_gen_z11;
DROP TRIGGER IF EXISTS update_row ON osm_park_polygon_gen_z10;
DROP TRIGGER IF EXISTS update_row ON osm_park_polygon_gen_z9;
DROP TRIGGER IF EXISTS update_row ON osm_park_polygon_gen_z8;
DROP TRIGGER IF EXISTS update_row ON osm_park_polygon_gen_z7;
DROP TRIGGER IF EXISTS update_row ON osm_park_polygon_gen_z6;
DROP TRIGGER IF EXISTS update_row ON osm_park_polygon_gen_z5;
DROP TRIGGER IF EXISTS update_row ON osm_park_polygon_gen_z4;
DROP TRIGGER IF EXISTS trigger_flag ON osm_park_polygon;
DROP TRIGGER IF EXISTS trigger_refresh ON park_polygon.updates;

-- etldoc:  osm_park_polygon ->  osm_park_polygon
-- etldoc:  osm_park_polygon_gen_z13 ->  osm_park_polygon_gen_z13
-- etldoc:  osm_park_polygon_gen_z12 ->  osm_park_polygon_gen_z12
-- etldoc:  osm_park_polygon_gen_z11 ->  osm_park_polygon_gen_z11
-- etldoc:  osm_park_polygon_gen_z10 ->  osm_park_polygon_gen_z10
-- etldoc:  osm_park_polygon_gen_z9 ->  osm_park_polygon_gen_z9
-- etldoc:  osm_park_polygon_gen_z8 ->  osm_park_polygon_gen_z8
-- etldoc:  osm_park_polygon_gen_z7 ->  osm_park_polygon_gen_z7
-- etldoc:  osm_park_polygon_gen_z6 ->  osm_park_polygon_gen_z6
-- etldoc:  osm_park_polygon_gen_z5 ->  osm_park_polygon_gen_z5
-- etldoc:  osm_park_polygon_gen_z4 ->  osm_park_polygon_gen_z4
CREATE OR REPLACE FUNCTION update_osm_park_polygon() RETURNS void AS
$$
BEGIN
    UPDATE osm_park_polygon
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_park_polygon_gen_z13
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_park_polygon_gen_z12
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_park_polygon_gen_z11
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_park_polygon_gen_z10
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_park_polygon_gen_z9
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_park_polygon_gen_z8
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_park_polygon_gen_z7
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_park_polygon_gen_z6
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_park_polygon_gen_z5
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    REFRESH MATERIALIZED VIEW CONCURRENTLY osm_park_polygon_dissolve_z4;
END;
$$ LANGUAGE plpgsql;

SELECT update_osm_park_polygon();
CREATE INDEX IF NOT EXISTS osm_park_polygon_point_geom_idx ON osm_park_polygon USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_park_polygon_gen_z13_point_geom_idx ON osm_park_polygon_gen_z13 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_park_polygon_gen_z12_point_geom_idx ON osm_park_polygon_gen_z12 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_park_polygon_gen_z11_point_geom_idx ON osm_park_polygon_gen_z11 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_park_polygon_gen_z10_point_geom_idx ON osm_park_polygon_gen_z10 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_park_polygon_gen_z9_point_geom_idx ON osm_park_polygon_gen_z9 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_park_polygon_gen_z8_point_geom_idx ON osm_park_polygon_gen_z8 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_park_polygon_gen_z7_point_geom_idx ON osm_park_polygon_gen_z7 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_park_polygon_gen_z6_point_geom_idx ON osm_park_polygon_gen_z6 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_park_polygon_gen_z5_point_geom_idx ON osm_park_polygon_gen_z5 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_park_polygon_gen_z4_polygon_geom_idx ON osm_park_polygon_gen_z4 USING gist (geometry);
CREATE INDEX IF NOT EXISTS osm_park_polygon_dissolve_z4_polygon_geom_idx ON osm_park_polygon_dissolve_z4 USING gist (geometry);

CREATE SCHEMA IF NOT EXISTS park_polygon;

CREATE TABLE IF NOT EXISTS park_polygon.updates
(
    id serial PRIMARY KEY,
    t  text,
    UNIQUE (t)
);

CREATE OR REPLACE FUNCTION park_polygon.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO park_polygon.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION park_polygon.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh park_polygon';

    -- Analyze tracking and source tables before performing update
    ANALYZE osm_park_polygon_gen_z4;
    REFRESH MATERIALIZED VIEW CONCURRENTLY osm_park_polygon_dissolve_z4;

    -- noinspection SqlWithoutWhere
    DELETE FROM park_polygon.updates;

    RAISE LOG 'Refresh park_polygon done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_osm_park_polygon_row()
    RETURNS trigger
AS
$$
BEGIN
    NEW.tags = update_tags(NEW.tags, NEW.geometry);
    NEW.geometry_point = ST_PointOnSurface(NEW.geometry);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_osm_park_dissolved_polygon_row()
    RETURNS trigger
AS
$$
BEGIN
    NEW.tags = update_tags(NEW.tags, NEW.geometry);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_park_polygon
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_park_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_park_polygon_gen_z13
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_park_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_park_polygon_gen_z12
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_park_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_park_polygon_gen_z11
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_park_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_park_polygon_gen_z10
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_park_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_park_polygon_gen_z9
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_park_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_park_polygon_gen_z8
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_park_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_park_polygon_gen_z7
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_park_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_park_polygon_gen_z6
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_park_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_park_polygon_gen_z5
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_park_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_park_polygon_gen_z4
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_park_dissolved_polygon_row();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_park_polygon
    FOR EACH STATEMENT
EXECUTE PROCEDURE park_polygon.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON park_polygon.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE park_polygon.refresh();

-- Layer park - ./park.sql

-- etldoc: layer_park[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="layer_park |<z4> z4 |<z5> z5 |<z6> z6 |<z7> z7 |<z8> z8 |<z9> z9 |<z10> z10 |<z11> z11 |<z12> z12|<z13> z13|<z14> z14+" ] ;

CREATE OR REPLACE FUNCTION layer_park(bbox geometry, zoom_level int, pixel_width numeric)
    RETURNS TABLE
            (
                osm_id   bigint,
                geometry geometry,
                class    text,
                name     text,
                name_en  text,
                name_de  text,
                tags     hstore,
                rank     int
            )
AS
$$
SELECT osm_id,
       geometry,
       class,
       NULLIF(name, '') AS name,
       NULLIF(name_en, '') AS name_en,
       NULLIF(name_de, '') AS name_de,
       tags,
       rank
FROM (
         SELECT osm_id,
                geometry,
                park_class(boundary, leisure, landuse, historic, maritime, tags) AS class,
                name,
                name_en,
                name_de,
                tags,
                NULL::int AS rank
         FROM (
                  -- etldoc: osm_park_polygon_dissolve_z4 -> layer_park:z4
                  SELECT NULL::int AS osm_id,
                         geometry,
                         NULL AS name,
                         NULL AS name_en,
                         NULL AS name_de,
                         NULL AS tags,
                         NULL AS leisure,
                         NULL AS landuse,
                         NULL AS boundary,
                         NULL AS historic,
                         NULL AS maritime
                  FROM osm_park_polygon_dissolve_z4
                  WHERE zoom_level = 4
                    AND geometry && bbox
                  UNION ALL
                  -- etldoc: osm_park_polygon_gen_z5 -> layer_park:z5
                  SELECT osm_id,
                         geometry,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime
                  FROM osm_park_polygon_gen_z5
                  WHERE zoom_level = 5
                    AND geometry && bbox
                  UNION ALL
                  -- etldoc: osm_park_polygon_gen_z6 -> layer_park:z6
                  SELECT osm_id,
                         geometry,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime
                  FROM osm_park_polygon_gen_z6
                  WHERE zoom_level = 6
                    AND geometry && bbox
                  UNION ALL
                  -- etldoc: osm_park_polygon_gen_z7 -> layer_park:z7
                  SELECT osm_id,
                         geometry,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime
                  FROM osm_park_polygon_gen_z7
                  WHERE zoom_level = 7
                    AND geometry && bbox
                  UNION ALL
                  -- etldoc: osm_park_polygon_gen_z8 -> layer_park:z8
                  SELECT osm_id,
                         geometry,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime
                  FROM osm_park_polygon_gen_z8
                  WHERE zoom_level = 8
                    AND geometry && bbox
                  UNION ALL
                  -- etldoc: osm_park_polygon_gen_z9 -> layer_park:z9
                  SELECT osm_id,
                         geometry,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime
                  FROM osm_park_polygon_gen_z9
                  WHERE zoom_level = 9
                    AND geometry && bbox
                  UNION ALL
                  -- etldoc: osm_park_polygon_gen_z10 -> layer_park:z10
                  SELECT osm_id,
                         geometry,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime
                  FROM osm_park_polygon_gen_z10
                  WHERE zoom_level = 10
                    AND geometry && bbox
                  UNION ALL
                  -- etldoc: osm_park_polygon_gen_z11 -> layer_park:z11
                  SELECT osm_id,
                         geometry,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime
                  FROM osm_park_polygon_gen_z11
                  WHERE zoom_level = 11
                    AND geometry && bbox
                  UNION ALL
                  -- etldoc: osm_park_polygon_gen_z12 -> layer_park:z12
                  SELECT osm_id,
                         geometry,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime
                  FROM osm_park_polygon_gen_z12
                  WHERE zoom_level = 12
                    AND geometry && bbox
                  UNION ALL
                  -- etldoc: osm_park_polygon_gen_z13 -> layer_park:z13
                  SELECT osm_id,
                         geometry,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime
                  FROM osm_park_polygon_gen_z13
                  WHERE zoom_level = 13
                    AND geometry && bbox
                  UNION ALL
                  -- etldoc: osm_park_polygon -> layer_park:z14
                  SELECT osm_id,
                         geometry,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime
                  FROM osm_park_polygon
                  WHERE zoom_level >= 14
                    AND geometry && bbox
              ) AS park_polygon

         UNION ALL
         SELECT osm_id,
                geometry_point AS geometry,
                park_class(boundary, leisure, landuse, historic, maritime, tags) AS class,
                name,
                name_en,
                name_de,
                tags,
                row_number() OVER (
                    PARTITION BY LabelGrid(geometry_point, 100 * pixel_width), boundary
                    ORDER BY
                        (CASE WHEN boundary = 'national_park' THEN TRUE ELSE FALSE END) DESC,
                        (COALESCE(NULLIF(tags->'wikipedia', ''), NULLIF(tags->'wikidata', '')) IS NOT NULL) DESC,
                        area DESC
                    )::int AS "rank"
         FROM (
                  -- etldoc: osm_park_polygon_gen_z5 -> layer_park:z5
                  SELECT osm_id,
                         geometry_point,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime,
                         area
                  FROM osm_park_polygon_gen_z5
                  WHERE zoom_level = 5
                    AND geometry_point && bbox
                    AND area > 70000*2^(20-zoom_level)
                  UNION ALL

                  -- etldoc: osm_park_polygon_gen_z6 -> layer_park:z6
                  SELECT osm_id,
                         geometry_point,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime,
                         area
                  FROM osm_park_polygon_gen_z6
                  WHERE zoom_level = 6
                    AND geometry_point && bbox
                    AND area > 70000*2^(20-zoom_level)
                  UNION ALL

                  -- etldoc: osm_park_polygon_gen_z7 -> layer_park:z7
                  SELECT osm_id,
                         geometry_point,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime,
                         area
                  FROM osm_park_polygon_gen_z7
                  WHERE zoom_level = 7
                    AND geometry_point && bbox
                    AND area > 70000*2^(20-zoom_level)
                  UNION ALL

                  -- etldoc: osm_park_polygon_gen_z8 -> layer_park:z8
                  SELECT osm_id,
                         geometry_point,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime,
                         area
                  FROM osm_park_polygon_gen_z8
                  WHERE zoom_level = 8
                    AND geometry_point && bbox
                    AND area > 70000*2^(20-zoom_level)
                  UNION ALL

                  -- etldoc: osm_park_polygon_gen_z9 -> layer_park:z9
                  SELECT osm_id,
                         geometry_point,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime,
                         area
                  FROM osm_park_polygon_gen_z9
                  WHERE zoom_level = 9
                    AND geometry_point && bbox
                    AND area > 70000*2^(20-zoom_level)
                  UNION ALL

                  -- etldoc: osm_park_polygon_gen_z10 -> layer_park:z10
                  SELECT osm_id,
                         geometry_point,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime,
                         area
                  FROM osm_park_polygon_gen_z10
                  WHERE zoom_level = 10
                    AND geometry_point && bbox
                    AND area > 70000*2^(20-zoom_level)
                  UNION ALL

                  -- etldoc: osm_park_polygon_gen_z11 -> layer_park:z11
                  SELECT osm_id,
                         geometry_point,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime,
                         area
                  FROM osm_park_polygon_gen_z11
                  WHERE zoom_level = 11
                    AND geometry_point && bbox
                    AND area > 70000*2^(20-zoom_level)
                  UNION ALL

                  -- etldoc: osm_park_polygon_gen_z12 -> layer_park:z12
                  SELECT osm_id,
                         geometry_point,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime,
                         area
                  FROM osm_park_polygon_gen_z12
                  WHERE zoom_level = 12
                    AND geometry_point && bbox
                    AND area > 70000*2^(20-zoom_level)
                  UNION ALL

                  -- etldoc: osm_park_polygon_gen_z13 -> layer_park:z13
                  SELECT osm_id,
                         geometry_point,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime,
                         area
                  FROM osm_park_polygon_gen_z13
                  WHERE zoom_level = 13
                    AND geometry_point && bbox
                    AND area > 70000*2^(20-zoom_level)
                  UNION ALL

                  -- etldoc: osm_park_polygon -> layer_park:z14
                  SELECT osm_id,
                         geometry_point,
                         name,
                         name_en,
                         name_de,
                         tags,
                         leisure,
                         landuse,
                         boundary,
                         historic,
                         maritime,
                         area
                  FROM osm_park_polygon
                  WHERE zoom_level >= 14
                    AND geometry_point && bbox
              ) AS park_point
     ) AS park_all;
$$ LANGUAGE SQL STABLE
                PARALLEL SAFE;
-- TODO: Check if the above can be made STRICT -- i.e. if pixel_width could be NULL

DO $$ BEGIN RAISE NOTICE 'Finished layer park'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer aeroway'; END$$;

-- Layer aeroway - ./aeroway.sql

-- etldoc: layer_aeroway[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="layer_aeroway |<z10> z10|<z11> z11|<z12> z12|<z13> z13|<z14_> z14+" ];

CREATE OR REPLACE FUNCTION layer_aeroway(bbox geometry, zoom_level int)
    RETURNS TABLE
            (
                geometry geometry,
                class    text,
                ref      text
            )
AS
$$
SELECT geometry, aeroway AS class, ref
FROM (
         -- etldoc:  osm_aeroway_linestring_gen_z10 -> layer_aeroway:z10
         SELECT geometry, aeroway, ref
         FROM osm_aeroway_linestring_gen_z10
         WHERE zoom_level = 10
         UNION ALL
         -- etldoc:  osm_aeroway_linestring_gen_z11 -> layer_aeroway:z11
         SELECT geometry, aeroway, ref
         FROM osm_aeroway_linestring_gen_z11
         WHERE zoom_level = 11
         UNION ALL
         -- etldoc:  osm_aeroway_linestring_gen_z12 -> layer_aeroway:z12
         SELECT geometry, aeroway, ref
         FROM osm_aeroway_linestring_gen_z12
         WHERE zoom_level = 12
         UNION ALL
         -- etldoc:  osm_aeroway_linestring -> layer_aeroway:z13
         -- etldoc:  osm_aeroway_linestring -> layer_aeroway:z14_
         SELECT geometry, aeroway, ref
         FROM osm_aeroway_linestring
         WHERE zoom_level >= 13
         UNION ALL
         -- etldoc:  osm_aeroway_polygon_gen_z10 -> layer_aeroway:z10
         SELECT geometry, aeroway, ref
         FROM osm_aeroway_polygon_gen_z10
         WHERE zoom_level = 10
         UNION ALL
         -- etldoc:  osm_aeroway_polygon_gen_z11 -> layer_aeroway:z11
         SELECT geometry, aeroway, ref
         FROM osm_aeroway_polygon_gen_z11
         WHERE zoom_level = 11
         UNION ALL
         -- etldoc:  osm_aeroway_polygon_gen_z12 -> layer_aeroway:z12
         SELECT geometry, aeroway, ref
         FROM osm_aeroway_polygon_gen_z12
         WHERE zoom_level = 12
         UNION ALL
         -- etldoc:  osm_aeroway_polygon_gen_z13 -> layer_aeroway:z13
         SELECT geometry, aeroway, ref
         FROM osm_aeroway_polygon_gen_z13
         WHERE zoom_level = 13
         UNION ALL
         -- etldoc:  osm_aeroway_polygon -> layer_aeroway:z14_
         SELECT geometry, aeroway, ref
         FROM osm_aeroway_polygon
         WHERE zoom_level >= 14
         UNION ALL
         
         -- etldoc:  osm_aeroway_point -> layer_aeroway:z14_
         SELECT geometry, aeroway, ref
         FROM osm_aeroway_point
         WHERE zoom_level >= 14
     ) AS zoom_levels
WHERE geometry && bbox;
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;

DO $$ BEGIN RAISE NOTICE 'Finished layer aeroway'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer building'; END$$;

-- Layer building - ./update_building.sql

DROP TRIGGER IF EXISTS trigger_refresh ON buildings.updates;
DROP TRIGGER IF EXISTS trigger_flag ON osm_building_polygon;

-- Creating aggregated building blocks with removed small polygons and small
-- holes. Aggregated polygons are simplified by Visvalingam-Whyatt algorithm.
-- Aggregating is made block by block using country_osm_grid polygon table.

-- Function returning recordset for matview.
-- Returning recordset of buildings aggregates by zres 14, with removed small
-- holes and with removed small buildings/blocks.

CREATE OR REPLACE FUNCTION osm_building_block_gen1()
    RETURNS table
            (
                osm_id   bigint,
                geometry geometry
            )
AS
$$
DECLARE
    zres14 float := Zres(14);
    zres12 float := Zres(12);
    zres14vw float := Zres(14) * Zres(14);
    polyg_world record;

BEGIN
    FOR polyg_world IN 
        SELECT ST_Transform(country.geometry, 3857) AS geometry 
        FROM country_osm_grid country
        
        LOOP
            FOR osm_id, geometry IN
                WITH dta AS ( -- CTE is used because of optimization
                    SELECT o.osm_id,
                            o.geometry,
                            ST_ClusterDBSCAN(o.geometry, eps := zres14, minpoints := 1) OVER () cid
                    FROM osm_building_polygon o
                    WHERE ST_Intersects(o.geometry, polyg_world.geometry)
                )
                SELECT (array_agg(dta.osm_id))[1] AS osm_id,
                    ST_Buffer(
                        ST_Union(
                            ST_Buffer(
                                ST_SnapToGrid(dta.geometry, 0.000001)
                                , zres14, 'join=mitre')
                            )
                        , -zres14, 'join=mitre') AS geometry
                FROM dta
                GROUP BY cid

                LOOP
                    -- removing holes smaller than
                    IF ST_NumInteriorRings(geometry) > 0 THEN -- only from geometries wih holes
                        geometry := (
                            -- there are some multi-geometries in this layer
                            SELECT ST_Collect(gn)
                            FROM (
                                    -- in some cases are "holes" NULL, because all holes are smaller than
                                    SELECT COALESCE(
                                                -- exterior ring
                                                    ST_MakePolygon(ST_ExteriorRing(dmp.geom), holes),
                                                    ST_MakePolygon(ST_ExteriorRing(dmp.geom))
                                                ) gn

                                    FROM ST_Dump(geometry) dmp, -- 1 dump polygons
                                        LATERAL (
                                            SELECT array_agg(ST_Boundary(rg.geom)) holes -- 2 create array
                                            FROM ST_DumpRings(dmp.geom) rg -- 3 from rings
                                            WHERE rg.path[1] > 0 -- 5 except inner ring
                                                AND ST_Area(rg.geom) >= power(zres12, 2) -- 4 bigger than
                                            ) holes
                                ) new_geom
                        );
                    END IF;

                    IF ST_Area(geometry) < power(zres12, 2) THEN
                        CONTINUE;
                    END IF;

                    -- simplify
                    geometry := ST_SimplifyVW(geometry, zres14vw);

                    RETURN NEXT;
                END LOOP;
        END LOOP;
END;
$$ LANGUAGE plpgsql STABLE
                    STRICT
                    PARALLEL SAFE;


DROP MATERIALIZED VIEW IF EXISTS osm_building_block_gen1_dup CASCADE;

CREATE MATERIALIZED VIEW osm_building_block_gen1_dup AS
SELECT *
FROM osm_building_block_gen1();

CREATE INDEX ON osm_building_block_gen1_dup USING gist (geometry);

-- etldoc: osm_building_polygon -> osm_building_block_gen_z13
DROP MATERIALIZED VIEW IF EXISTS osm_building_block_gen_z13;
CREATE MATERIALIZED VIEW osm_building_block_gen_z13 AS
(
WITH 
    counts AS (
        SELECT count(osm_id) AS counts,
		        osm_id
	    FROM osm_building_block_gen1_dup
	GROUP BY osm_id
    ),

    duplicates AS (
        SELECT counts.osm_id
	    FROM counts
	    WHERE counts.counts > 1
    )

SELECT osm.osm_id,
		ST_Union(
            ST_MakeValid(osm.geometry)) AS geometry
	FROM osm_building_block_gen1_dup osm,
			duplicates
	WHERE osm.osm_id = duplicates.osm_id
	GROUP BY osm.osm_id
	
	UNION ALL

	SELECT osm.osm_id, 
			osm.geometry 
	FROM osm_building_block_gen1_dup osm, 
            counts 
	WHERE counts.counts = 1 
		AND osm.osm_id = counts.osm_id
);

CREATE INDEX ON osm_building_block_gen_z13 USING gist (geometry);
CREATE UNIQUE INDEX ON osm_building_block_gen_z13 USING btree (osm_id);

-- Handle updates

CREATE SCHEMA IF NOT EXISTS buildings;

CREATE TABLE IF NOT EXISTS buildings.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);

CREATE OR REPLACE FUNCTION buildings.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO buildings.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION buildings.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh buildings block';
    REFRESH MATERIALIZED VIEW osm_building_block_gen1_dup;
    REFRESH MATERIALIZED VIEW osm_building_block_gen_z13;
    -- noinspection SqlWithoutWhere
    DELETE FROM buildings.updates;

    RAISE LOG 'Update buildings block done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_building_polygon
    FOR EACH STATEMENT
EXECUTE PROCEDURE buildings.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON buildings.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE buildings.refresh();

-- Layer building - ./building.sql

-- etldoc: layer_building[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="layer_building | <z13> z13 | <z14_> z14+ " ] ;

CREATE INDEX IF NOT EXISTS osm_building_relation_building_idx ON osm_building_relation (building) WHERE building = '' AND ST_GeometryType(geometry) = 'ST_Polygon';
CREATE INDEX IF NOT EXISTS osm_building_relation_member_idx ON osm_building_relation (member) WHERE role = 'outline';

CREATE OR REPLACE VIEW osm_all_buildings AS
(
SELECT
    -- etldoc: osm_building_relation -> layer_building:z14_
    -- Buildings built from relations
    member AS osm_id,
    geometry,
    COALESCE(CleanNumeric(height), CleanNumeric(buildingheight)) AS height,
    COALESCE(CleanNumeric(min_height), CleanNumeric(buildingmin_height)) AS min_height,
    COALESCE(CleanNumeric(levels), CleanNumeric(buildinglevels)) AS levels,
    COALESCE(CleanNumeric(min_level), CleanNumeric(buildingmin_level)) AS min_level,
    nullif(material, '') AS material,
    nullif(colour, '') AS colour,
    FALSE AS hide_3d
FROM osm_building_relation
WHERE building = ''
  AND ST_GeometryType(geometry) = 'ST_Polygon'
UNION ALL

SELECT
    -- etldoc: osm_building_polygon -> layer_building:z14_
    -- Standalone buildings
    obp.osm_id,
    obp.geometry,
    COALESCE(CleanNumeric(obp.height), CleanNumeric(obp.buildingheight)) AS height,
    COALESCE(CleanNumeric(obp.min_height), CleanNumeric(obp.buildingmin_height)) AS min_height,
    COALESCE(CleanNumeric(obp.levels), CleanNumeric(obp.buildinglevels)) AS levels,
    COALESCE(CleanNumeric(obp.min_level), CleanNumeric(obp.buildingmin_level)) AS min_level,
    nullif(obp.material, '') AS material,
    nullif(obp.colour, '') AS colour,
    obr.role IS NOT NULL AS hide_3d
FROM osm_building_polygon obp
         LEFT JOIN osm_building_relation obr ON
        obp.osm_id >= 0 AND
        obr.member = obp.osm_id AND
        obr.role = 'outline'
WHERE ST_GeometryType(obp.geometry) IN ('ST_Polygon', 'ST_MultiPolygon')
    );

CREATE OR REPLACE FUNCTION layer_building(bbox geometry, zoom_level int)
    RETURNS TABLE
            (
                geometry          geometry,
                osm_id            bigint,
                render_height     int,
                render_min_height int,
                colour            text,
                hide_3d           boolean
            )
AS
$$
SELECT geometry,
       osm_id,
       render_height,
       render_min_height,
       COALESCE(colour, CASE material
           -- Ordered by count from taginfo
                            WHEN 'cement_block' THEN '#6a7880'
                            WHEN 'brick' THEN '#bd8161'
                            WHEN 'plaster' THEN '#dadbdb'
                            WHEN 'wood' THEN '#d48741'
                            WHEN 'concrete' THEN '#d3c2b0'
                            WHEN 'metal' THEN '#b7b1a6'
                            WHEN 'stone' THEN '#b4a995'
                            WHEN 'mud' THEN '#9d8b75'
                            WHEN 'steel' THEN '#b7b1a6' -- same as metal
                            WHEN 'glass' THEN '#5a81a0'
                            WHEN 'traditional' THEN '#bd8161' -- same as brick
                            WHEN 'masonry' THEN '#bd8161' -- same as brick
                            WHEN 'Brick' THEN '#bd8161' -- same as brick
                            WHEN 'tin' THEN '#b7b1a6' -- same as metal
                            WHEN 'timber_framing' THEN '#b3b0a9'
                            WHEN 'sandstone' THEN '#b4a995' -- same as stone
                            WHEN 'clay' THEN '#9d8b75' -- same as mud
           END) AS colour,
       CASE WHEN hide_3d THEN TRUE END AS hide_3d
FROM (
         SELECT
             -- etldoc: osm_building_block_gen_z13 -> layer_building:z13
             osm_id,
             geometry,
             NULL::int AS render_height,
             NULL::int AS render_min_height,
             NULL::text AS material,
             NULL::text AS colour,
             FALSE AS hide_3d
         FROM osm_building_block_gen_z13
         WHERE zoom_level = 13
           AND geometry && bbox
         UNION ALL
         SELECT
                                  -- etldoc: osm_building_polygon -> layer_building:z14_
             DISTINCT ON (osm_id) osm_id,
                                  geometry,
                                  ceil(COALESCE(height, levels * 3.66, 5))::int AS render_height,
                                  floor(COALESCE(min_height, min_level * 3.66, 0))::int AS render_min_height,
                                  material,
                                  colour,
                                  hide_3d
         FROM osm_all_buildings
         WHERE (levels IS NULL OR levels < 1000)
           AND (min_level IS NULL OR min_level < 1000)
           AND (height IS NULL OR height < 3000)
           AND (min_height IS NULL OR min_height < 3000)
           AND zoom_level >= 14
           AND geometry && bbox
     ) AS zoom_levels
ORDER BY render_height ASC, ST_YMin(geometry) DESC;
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE
                ;

-- not handled: where a building outline covers building parts

DO $$ BEGIN RAISE NOTICE 'Finished layer building'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer water_name'; END$$;

DO $$ BEGIN
    PERFORM 'ne_10m_geography_marine_polys'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "water_name"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'lake_centerline'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "water_name"';
END;
$$ LANGUAGE 'plpgsql';

-- Layer water_name - ./update_marine_point.sql

DROP TRIGGER IF EXISTS trigger_flag ON osm_marine_point;
DROP TRIGGER IF EXISTS trigger_store ON osm_marine_point;
DROP TRIGGER IF EXISTS trigger_refresh ON water_name_marine.updates;

CREATE SCHEMA IF NOT EXISTS water_name_marine;

CREATE TABLE IF NOT EXISTS water_name_marine.osm_ids
(
    osm_id bigint PRIMARY KEY
);

CREATE OR REPLACE FUNCTION update_osm_marine_point(full_update boolean) RETURNS void AS
$$
    -- etldoc: ne_10m_geography_marine_polys -> osm_marine_point
    -- etldoc: osm_marine_point              -> osm_marine_point

    WITH important_marine_point AS (
        SELECT osm.osm_id, ne.scalerank
        FROM osm_marine_point AS osm
             LEFT JOIN ne_10m_geography_marine_polys AS ne ON
            (
                lower(trim(regexp_replace(ne.name, '\\s+', ' ', 'g'))) IN (lower(osm.name), lower(osm.tags->'name:en'), lower(osm.tags->'name:es'))
                    OR substring(lower(trim(regexp_replace(ne.name, '\\s+', ' ', 'g'))) FROM 1 FOR length(lower(osm.name))) = lower(osm.name)
            )
            AND ST_DWithin(ne.geometry, osm.geometry, 50000)
    )
    UPDATE osm_marine_point AS osm
    SET "rank" = scalerank
    FROM important_marine_point AS ne
    WHERE (full_update OR osm.osm_id IN (SELECT osm_id FROM water_name_marine.osm_ids))
      AND osm.osm_id = ne.osm_id
      AND "rank" IS DISTINCT FROM scalerank;

    UPDATE osm_marine_point
    SET tags = update_tags(tags, geometry)
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM water_name_marine.osm_ids))
      AND COALESCE(tags->'name:latin', tags->'name:nonlatin', tags->'name_int') IS NULL
      AND tags != update_tags(tags, geometry);

$$ LANGUAGE SQL;

SELECT update_osm_marine_point(true);

CREATE INDEX IF NOT EXISTS osm_marine_point_rank_idx ON osm_marine_point ("rank");

-- Handle updates

CREATE OR REPLACE FUNCTION water_name_marine.store() RETURNS trigger AS
$$
BEGIN
    INSERT INTO water_name_marine.osm_ids VALUES (NEW.osm_id) ON CONFLICT (osm_id) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS water_name_marine.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION water_name_marine.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO water_name_marine.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION water_name_marine.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh water_name_marine rank';

    -- Analyze tracking and source tables before performing update
    ANALYZE water_name_marine.osm_ids;
    ANALYZE osm_marine_point;

    PERFORM update_osm_marine_point(false);
    -- noinspection SqlWithoutWhere
    DELETE FROM water_name_marine.osm_ids;
    -- noinspection SqlWithoutWhere
    DELETE FROM water_name_marine.updates;

    RAISE LOG 'Refresh water_name_marine done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE
    ON osm_marine_point
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE water_name_marine.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE
    ON osm_marine_point
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE water_name_marine.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON water_name_marine.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE water_name_marine.refresh();

-- Layer water_name - ./update_water_name.sql

DROP TRIGGER IF EXISTS trigger_store ON osm_water_polygon;
DROP TRIGGER IF EXISTS trigger_flag ON osm_water_polygon;
DROP TRIGGER IF EXISTS trigger_refresh ON water_name.updates;

CREATE INDEX IF NOT EXISTS lake_centerline_osm_id_idx ON lake_centerline (osm_id);
CREATE INDEX IF NOT EXISTS osm_water_polygon_update_idx ON osm_water_polygon (name, ST_IsValid(geometry))
    WHERE name <> '' AND ST_IsValid(geometry);;

CREATE OR REPLACE VIEW osm_water_lakeline_view AS
SELECT wp.osm_id,
       ll.wkb_geometry AS geometry,
       name,
       name_en,
       name_de,
       update_tags(tags, ll.wkb_geometry) AS tags,
       ST_Area(wp.geometry) AS area,
       is_intermittent
FROM osm_water_polygon AS wp
         INNER JOIN lake_centerline ll ON wp.osm_id = ll.osm_id
WHERE wp.name <> ''
  AND ST_IsValid(wp.geometry);

DROP TABLE IF EXISTS osm_water_lakeline CASCADE;

-- etldoc:  osm_water_polygon ->  osm_water_lakeline
-- etldoc:  lake_centerline  ->  osm_water_lakeline
CREATE TABLE IF NOT EXISTS osm_water_lakeline AS
SELECT *
FROM osm_water_lakeline_view;
DO
$$
    BEGIN
        ALTER TABLE osm_water_lakeline
            ADD CONSTRAINT osm_water_lakeline_pk PRIMARY KEY (osm_id);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'primary key osm_water_lakeline_pk already exists in osm_water_lakeline.';
    END;
$$;
CREATE INDEX IF NOT EXISTS osm_water_lakeline_geometry_idx ON osm_water_lakeline USING gist (geometry);

-- etldoc:  osm_water_polygon ->  osm_water_point_view
-- etldoc:  lake_centerline ->  osm_water_point_view
CREATE OR REPLACE VIEW osm_water_point_view AS
SELECT wp.osm_id,
       ST_PointOnSurface(wp.geometry) AS geometry,
       wp.name,
       wp.name_en,
       wp.name_de,
       CASE
           WHEN "natural" = 'bay' THEN 'bay'
           WHEN place = 'sea' THEN 'sea'
           ELSE 'lake'
       END AS class,
       update_tags(wp.tags, ST_PointOnSurface(wp.geometry)) AS tags,
       -- Area of the feature in square meters
       ST_Area(wp.geometry) AS area,
       wp.is_intermittent
FROM osm_water_polygon AS wp
         LEFT JOIN lake_centerline ll ON wp.osm_id = ll.osm_id
WHERE ll.osm_id IS NULL
  AND wp.name <> ''
  AND ST_IsValid(wp.geometry)
  AND (wp.leisure IS NULL OR wp.leisure != 'swimming_pool');

-- etldoc:  osm_water_point_view ->  osm_water_point_earth_view
CREATE OR REPLACE VIEW osm_water_point_earth_view AS
SELECT osm_id,
       geometry,
       name,
       name_en,
       name_de,
       class,
       tags,
       -- Percentage of the earth's surface covered by this feature (approximately)
       -- The constant below is 111,842^2 * 180 * 180, where 111,842 is the length of one degree of latitude at the equator in meters.
       area / (405279708033600 * COS(ST_Y(ST_Transform(geometry,4326))*PI()/180)) as earth_area,
       is_intermittent
FROM osm_water_point_view;

DROP TABLE IF EXISTS osm_water_point CASCADE;

-- etldoc:  osm_water_point_earth_view ->  osm_water_point
CREATE TABLE IF NOT EXISTS osm_water_point AS
SELECT *
FROM osm_water_point_earth_view;
DO
$$
    BEGIN
        ALTER TABLE osm_water_point
            ADD CONSTRAINT osm_water_point_pk PRIMARY KEY (osm_id);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'primary key osm_water_point_pk already exists in osm_water_point.';
    END;
$$;
CREATE INDEX IF NOT EXISTS osm_water_point_geometry_idx ON osm_water_point USING gist (geometry);

-- Handle updates

CREATE SCHEMA IF NOT EXISTS water_name;

CREATE TABLE IF NOT EXISTS water_name.osm_ids
(
    osm_id bigint,
    is_old bool,
    PRIMARY KEY (osm_id, is_old)
);

CREATE OR REPLACE FUNCTION update_osm_water_name() RETURNS void AS $$
BEGIN
    DELETE FROM osm_water_lakeline
    WHERE EXISTS(
        SELECT NULL
        FROM water_name.osm_ids
        WHERE water_name.osm_ids.osm_id = osm_water_lakeline.osm_id
              AND water_name.osm_ids.is_old IS TRUE
    );

    INSERT INTO osm_water_lakeline
    SELECT * FROM osm_water_lakeline_view
    WHERE EXISTS(
        SELECT NULL
        FROM water_name.osm_ids
        WHERE water_name.osm_ids.osm_id = osm_water_lakeline_view.osm_id
              AND water_name.osm_ids.is_old IS FALSE
    ) ON CONFLICT (osm_id) DO UPDATE SET geometry = excluded.geometry, name = excluded.name, name_en = excluded.name_en,
                                         name_de = excluded.name_de, tags = excluded.tags, area = excluded.area,
                                         is_intermittent = excluded.is_intermittent;

    DELETE FROM osm_water_point
    WHERE EXISTS(
        SELECT NULL
        FROM water_name.osm_ids
        WHERE water_name.osm_ids.osm_id = osm_water_point.osm_id
              AND water_name.osm_ids.is_old IS TRUE
    );

    INSERT INTO osm_water_point
    SELECT * FROM osm_water_point_earth_view
    WHERE EXISTS(
        SELECT NULL
        FROM water_name.osm_ids
        WHERE water_name.osm_ids.osm_id = osm_water_point_earth_view.osm_id
              AND water_name.osm_ids.is_old IS FALSE
    ) ON CONFLICT (osm_id) DO UPDATE SET geometry = excluded.geometry, name = excluded.name, name_en = excluded.name_en,
                                         name_de = excluded.name_de, class = excluded.class, tags = excluded.tags,
                                         earth_area = excluded.earth_area, is_intermittent = excluded.is_intermittent;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION water_name.store() RETURNS trigger AS $$
BEGIN
    IF (tg_op = 'DELETE') THEN
        INSERT INTO water_name.osm_ids (osm_id, is_old) VALUES (OLD.osm_id, TRUE) ON CONFLICT (osm_id, is_old) DO NOTHING;
    ELSE
        INSERT INTO water_name.osm_ids (osm_id, is_old) VALUES (NEW.osm_id, FALSE) ON CONFLICT (osm_id, is_old) DO NOTHING;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS water_name.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION water_name.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO water_name.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION water_name.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh water_name';

    -- Analyze tracking and source tables before performing update
    ANALYZE water_name.osm_ids;
    ANALYZE osm_water_lakeline;
    ANALYZE osm_water_point;

    PERFORM update_osm_water_name();
    -- noinspection SqlWithoutWhere
    DELETE FROM water_name.osm_ids;
    -- noinspection SqlWithoutWhere
    DELETE FROM water_name.updates;

    RAISE LOG 'Refresh water_name done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_water_polygon
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE water_name.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_water_polygon
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE water_name.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON water_name.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE water_name.refresh();

-- Layer water_name - ./water_name.sql

-- etldoc: layer_water_name[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="layer_water_name | <z0_8> z0_8 | <z9_13> z9_13 | <z14_> z14+" ] ;

CREATE OR REPLACE FUNCTION layer_water_name(bbox geometry, zoom_level integer)
    RETURNS TABLE
            (
                osm_id       bigint,
                geometry     geometry,
                name         text,
                name_en      text,
                name_de      text,
                tags         hstore,
                class        text,
                intermittent int
            )
AS
$$
SELECT
    -- etldoc: osm_water_lakeline ->  layer_water_name:z9_13
    -- etldoc: osm_water_lakeline ->  layer_water_name:z14_
    CASE
        WHEN osm_id < 0 THEN -osm_id * 10 + 4
        ELSE osm_id * 10 + 1
        END AS osm_id_hash,
    geometry,
    name,
    COALESCE(NULLIF(name_en, ''), name) AS name_en,
    COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
    tags,
    'lake'::text AS class,
    is_intermittent::int AS intermittent
FROM osm_water_lakeline
WHERE geometry && bbox
  AND ((zoom_level BETWEEN 3 AND 13 AND LineLabel(zoom_level, NULLIF(name, ''), geometry))
    OR (zoom_level >= 14))
UNION ALL
SELECT
    -- etldoc: osm_water_point ->  layer_water_name:z9_13
    -- etldoc: osm_water_point ->  layer_water_name:z14_
    CASE
        WHEN osm_id < 0 THEN -osm_id * 10 + 4
        ELSE osm_id * 10 + 1
        END AS osm_id_hash,
    geometry,
    name,
    COALESCE(NULLIF(name_en, ''), name) AS name_en,
    COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
    tags,
    class,
    is_intermittent::int AS intermittent
FROM osm_water_point
WHERE geometry && bbox
  AND (
        -- Show a label if a water feature covers at least 1/4 of a tile or z14+
        (tags->'place' IN ('sea', 'ocean') AND POWER(4,zoom_level) * earth_area > 0.25)
        OR (zoom_level BETWEEN 3 AND 13 AND POWER(4,zoom_level) * earth_area > 0.25)
        OR (zoom_level >= 14)
    )
UNION ALL
SELECT
    -- etldoc: osm_marine_point ->  layer_water_name:z0_8
    -- etldoc: osm_marine_point ->  layer_water_name:z9_13
    -- etldoc: osm_marine_point ->  layer_water_name:z14_
    osm_id * 10 AS osm_id_hash,
    geometry,
    name,
    COALESCE(NULLIF(name_en, ''), name) AS name_en,
    COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
    tags,
    COALESCE(NULLIF("natural",''), "place") AS class,
    is_intermittent::int AS intermittent
FROM osm_marine_point
WHERE geometry && bbox
  AND CASE
      WHEN place = 'ocean' THEN TRUE
      WHEN zoom_level >= "rank" AND "rank" IS NOT NULL THEN TRUE
      WHEN "natural" = 'bay' THEN zoom_level >= 13
      ELSE zoom_level >= 8 END;
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;

DO $$ BEGIN RAISE NOTICE 'Finished layer water_name'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer transportation'; END$$;

DO $$ BEGIN
    PERFORM 'ne_10m_admin_0_countries'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "transportation"';
END;
$$ LANGUAGE 'plpgsql';

-- Layer transportation - ./network_type.sql

DROP TRIGGER IF EXISTS trigger_store_transportation_route_member ON osm_route_member;
DROP TRIGGER IF EXISTS trigger_store_transportation_highway_linestring ON osm_highway_linestring;
DROP TRIGGER IF EXISTS trigger_flag_transportation_name ON transportation_name.network_changes;
DROP TRIGGER IF EXISTS trigger_refresh_network ON transportation_name.updates_network;

DROP TRIGGER IF EXISTS trigger_store_transportation_name_network ON osm_transportation_name_network;
DROP TRIGGER IF EXISTS trigger_flag_name ON transportation_name.name_changes;
DROP TRIGGER IF EXISTS trigger_refresh_name ON transportation_name.updates_name;

DO
$$
    BEGIN
        PERFORM 'route_network_type'::regtype;
    EXCEPTION
        WHEN undefined_object THEN
            CREATE TYPE route_network_type AS enum (
                'us-interstate', 'us-highway', 'us-state',
                'ca-transcanada', 'ca-provincial-arterial', 'ca-provincial',
                'gb-motorway', 'gb-trunk', 'gb-primary',
                'ie-motorway', 'ie-national', 'ie-regional',
                'e-road',
                'a-road'
                );
    END
$$;

-- Top-level national route networks that should display at the lowest zooms
CREATE OR REPLACE FUNCTION osm_national_network(network text) RETURNS boolean AS
$$
    SELECT network <> '' AND network IN (
        -- Canada
        'ca-transcanada', 'ca-provincial-arterial',
        -- United States
        'us-interstate', 'us-highway',
        -- UK
        'gb-motorway', 'gb-trunk',
        -- Ireland
        'ie-motorway', 'ie-national',
        -- Europe
        'e-road',
        -- Asia
        'a-road'
    );
$$ LANGUAGE sql IMMUTABLE
                PARALLEL SAFE;

CREATE OR REPLACE FUNCTION create_route_hstore(network TEXT, ref TEXT, name TEXT, colour TEXT, ref_colour TEXT)
RETURNS hstore AS $$
SELECT CASE
           WHEN network = '' THEN hstore('')
           ELSE hstore(
               ARRAY['network', 'ref', 'name', 'colour'],
               ARRAY[network, NULLIF(ref, ''), NULLIF(name, ''), COALESCE(NULLIF(colour, ''), NULLIF(ref_colour, ''))]
           )
       END;
$$ LANGUAGE sql IMMUTABLE
    PARALLEL SAFE;

-- Layer transportation - ./class.sql

CREATE OR REPLACE FUNCTION brunnel(is_bridge bool, is_tunnel bool, is_ford bool) RETURNS text AS
$$
SELECT CASE
           WHEN is_bridge THEN 'bridge'
           WHEN is_tunnel THEN 'tunnel'
           WHEN is_ford THEN 'ford'
           END;
$$ LANGUAGE SQL IMMUTABLE
                STRICT
                PARALLEL SAFE;

-- The classes for highways are derived from the classes used in ClearTables
-- https://github.com/ClearTables/ClearTables/blob/master/transportation.lua
CREATE OR REPLACE FUNCTION highway_class(highway text, public_transport text, construction text) RETURNS text AS
$$
SELECT CASE
           WHEN "highway" IN ('motorway', 'motorway_link') THEN 'motorway'
           WHEN "highway" IN ('trunk', 'trunk_link') THEN 'trunk'
           WHEN "highway" IN ('primary', 'primary_link') THEN 'primary'
           WHEN "highway" IN ('secondary', 'secondary_link') THEN 'secondary'
           WHEN "highway" IN ('tertiary', 'tertiary_link') THEN 'tertiary'
           WHEN "highway" IN ('unclassified', 'residential', 'living_street', 'road') THEN 'minor'
           WHEN "highway" IN ('pedestrian', 'path', 'footway', 'cycleway', 'steps', 'bridleway', 'corridor')
               OR "public_transport" = 'platform'
               THEN 'path'
           WHEN "highway" = 'service' THEN 'service'
           WHEN "highway" = 'track' THEN 'track'
           WHEN "highway" = 'raceway' THEN 'raceway'
           WHEN "highway" = 'busway' THEN 'busway'
           WHEN "highway" = 'bus_guideway' THEN 'bus_guideway'
           WHEN "highway" = 'shipway' THEN 'ferry'
           WHEN "highway" = 'construction'
               AND "construction" IN ('motorway', 'motorway_link')
               THEN 'motorway_construction'
           WHEN "highway" = 'construction'
               AND "construction" IN ('trunk', 'trunk_link')
               THEN 'trunk_construction'
           WHEN "highway" = 'construction'
               AND "construction" IN ('primary', 'primary_link')
               THEN 'primary_construction'
           WHEN "highway" = 'construction'
               AND "construction" IN ('secondary', 'secondary_link')
               THEN 'secondary_construction'
           WHEN "highway" = 'construction'
               AND "construction" IN ('tertiary', 'tertiary_link')
               THEN 'tertiary_construction'
           WHEN "highway" = 'construction'
               AND "construction" IN ('', 'unclassified', 'residential', 'living_street', 'road')
               THEN 'minor_construction'
           WHEN "highway" = 'construction'
               AND ("construction" IN ('pedestrian', 'path', 'footway', 'cycleway', 'steps', 'bridleway', 'corridor') OR "public_transport" = 'platform')
               THEN 'path_construction'
           WHEN "highway" = 'construction'
               AND "construction" = 'service'
               THEN 'service_construction'
           WHEN "highway" = 'construction'
               AND "construction" = 'track'
               THEN 'track_construction'
           WHEN "highway" = 'construction'
               AND "construction" = 'raceway'
               THEN 'raceway_construction'
           END;
$$ LANGUAGE SQL IMMUTABLE
                PARALLEL SAFE;

-- The classes for railways are derived from the classes used in ClearTables
-- https://github.com/ClearTables/ClearTables/blob/master/transportation.lua
CREATE OR REPLACE FUNCTION railway_class(railway text) RETURNS text AS
$$
SELECT CASE
           WHEN railway IN ('rail', 'narrow_gauge', 'preserved', 'funicular') THEN 'rail'
           WHEN railway IN ('subway', 'light_rail', 'monorail', 'tram') THEN 'transit'
           END;
$$ LANGUAGE SQL IMMUTABLE
                STRICT
                PARALLEL SAFE;

-- Limit service to only the most important values to ensure
-- we always know the values of service
CREATE OR REPLACE FUNCTION service_value(service text) RETURNS text AS
$$
SELECT CASE
           WHEN service IN ('spur', 'yard', 'siding', 'crossover', 'driveway', 'alley', 'parking_aisle') THEN service
           END;
$$ LANGUAGE SQL IMMUTABLE
                STRICT
                PARALLEL SAFE;

-- Limit surface to only the most important values to ensure
-- we always know the values of surface
CREATE OR REPLACE FUNCTION surface_value(surface text) RETURNS text AS
$$
SELECT CASE
           WHEN surface IN ('paved', 'asphalt', 'cobblestone', 'concrete', 'concrete:lanes', 'concrete:plates', 'metal',
                            'paving_stones', 'sett', 'unhewn_cobblestone', 'wood', 'grade1') THEN 'paved'
           WHEN surface IN ('unpaved', 'compacted', 'dirt', 'earth', 'fine_gravel', 'grass', 'grass_paver', 'gravel',
                            'gravel_turf', 'ground', 'ice', 'mud', 'pebblestone', 'salt', 'sand', 'snow', 'woodchips',
                            'rock', 'clay', 'laterite')
               THEN 'unpaved'
           END;
$$ LANGUAGE SQL IMMUTABLE
                STRICT
                PARALLEL SAFE;

-- Determine which transportation features are shown at zoom 12
CREATE OR REPLACE FUNCTION transportation_filter_z12(highway text, construction text) RETURNS boolean AS
$$
SELECT CASE
           WHEN highway IN ('unclassified', 'residential') THEN TRUE
           WHEN highway_class(highway, '', construction) IN
               (
                'motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'raceway',
                'motorway_construction', 'trunk_construction', 'primary_construction',
                'secondary_construction', 'tertiary_construction', 'raceway_construction',
                'busway', 'bus_guideway'
               ) THEN TRUE --includes ramps
           ELSE FALSE
       END
$$ LANGUAGE SQL IMMUTABLE
                STRICT
                PARALLEL SAFE;

-- Determine which transportation features are shown at zoom 13
-- Assumes that piers have already been excluded
CREATE OR REPLACE FUNCTION transportation_filter_z13(highway text,
                                                     public_transport text,
                                                     construction text,
                                                     service text) RETURNS boolean AS
$$
SELECT CASE
           WHEN transportation_filter_z12(highway, construction) THEN TRUE
           WHEN highway = 'service' OR construction = 'service' THEN service NOT IN ('driveway', 'parking_aisle')
           WHEN highway_class(highway, public_transport, construction) IN ('minor', 'minor_construction') THEN TRUE
           ELSE FALSE
       END
$$ LANGUAGE SQL IMMUTABLE
                STRICT
                PARALLEL SAFE;

-- Layer transportation - ./highway_name.sql

CREATE OR REPLACE FUNCTION transportation_name_tags(geometry geometry, tags hstore, name text, name_en text, name_de text) RETURNS hstore AS
$$
SELECT hstore(string_agg(nullif(slice_language_tags(tags ||
                     hstore(ARRAY [
                       'name',    CASE WHEN length(name) > 15    THEN osml10n_street_abbrev_all(name)   ELSE NULLIF(name, '') END,
                       'name:en', CASE WHEN length(name_en) > 15 THEN osml10n_street_abbrev_en(name_en) ELSE NULLIF(name_en, '') END,
                       'name:de', CASE WHEN length(name_de) > 15 THEN osml10n_street_abbrev_de(name_de) ELSE NULLIF(name_de, '') END
                     ]))::text,
                     ''), ','));
$$ LANGUAGE SQL IMMUTABLE
                PARALLEL SAFE;

-- Layer transportation - ./update_route_member.sql

DROP TRIGGER IF EXISTS trigger_store_transportation_highway_linestring ON osm_highway_linestring;

-- Create bounding windows for country-specific processing

-- etldoc: ne_10m_admin_0_countries ->  ne_10m_admin_0_gb_buffer
CREATE TABLE IF NOT EXISTS ne_10m_admin_0_gb_buffer AS
SELECT ST_Buffer(geometry, 10000)
FROM ne_10m_admin_0_countries
WHERE iso_a2 = 'GB';

-- etldoc: ne_10m_admin_0_countries ->  ne_10m_admin_0_ie_buffer
CREATE TABLE IF NOT EXISTS ne_10m_admin_0_ie_buffer AS
SELECT ST_Buffer(geometry, 10000)
FROM ne_10m_admin_0_countries
WHERE iso_a2 = 'IE';

-- Assign pseudo-networks based highway classification
-- etldoc:  osm_highway_linestring ->  gbr_route_members_view
-- etldoc:  ne_10m_admin_0_gb_buffer ->  gbr_route_members_view
CREATE OR REPLACE VIEW gbr_route_members_view AS
SELECT osm_id AS member,
       substring(ref FROM E'^[ABM][0-9ABM()]+') AS ref,
       -- See https://wiki.openstreetmap.org/wiki/Roads_in_the_United_Kingdom
       CASE WHEN highway = 'motorway' THEN 'omt-gb-motorway'
            WHEN highway = 'trunk' THEN 'omt-gb-trunk'
            WHEN highway IN ('primary','secondary') THEN 'omt-gb-primary' END AS network
FROM osm_highway_linestring
WHERE length(ref) > 1
  AND ST_Intersects(geometry, (SELECT * FROM ne_10m_admin_0_gb_buffer))
  AND highway IN ('motorway', 'trunk', 'primary', 'secondary')
;

-- etldoc:  osm_highway_linestring ->  ire_route_members_view
-- etldoc:  ne_10m_admin_0_ie_buffer ->  ire_route_members_view
CREATE OR REPLACE VIEW ire_route_members_view AS
SELECT osm_id AS member,
       substring(ref FROM E'^[MNRL][0-9]+') AS ref,
       -- See https://wiki.openstreetmap.org/wiki/Ireland/Roads
       CASE WHEN highway = 'motorway' THEN 'omt-ie-motorway'
            WHEN highway IN ('trunk','primary') THEN 'omt-ie-national'
            ELSE 'omt-ie-regional' END AS network
FROM osm_highway_linestring
WHERE length(ref) > 1
  AND ST_Intersects(geometry, (SELECT * FROM ne_10m_admin_0_ie_buffer))
  AND highway IN ('motorway', 'trunk', 'primary', 'secondary', 'unclassified')
;

CREATE OR REPLACE FUNCTION osm_route_member_network_type(network text, ref text) RETURNS route_network_type AS
$$
SELECT CASE
           -- https://wiki.openstreetmap.org/wiki/United_States_roads_tagging
           WHEN network = 'US:I' THEN 'us-interstate'::route_network_type
           WHEN network = 'US:US' THEN 'us-highway'::route_network_type
           WHEN network LIKE 'US:__' THEN 'us-state'::route_network_type
           -- https://en.wikipedia.org/wiki/Trans-Canada_Highway
           WHEN network LIKE 'CA:transcanada%' THEN 'ca-transcanada'::route_network_type
           WHEN network = 'CA:QC:A' THEN 'ca-provincial-arterial'::route_network_type
           WHEN network = 'CA:ON:primary' THEN
               CASE
                   WHEN ref LIKE '4__' THEN 'ca-provincial-arterial'::route_network_type
                   WHEN ref = 'QEW' THEN 'ca-provincial-arterial'::route_network_type
                   ELSE 'ca-provincial'::route_network_type
               END
           WHEN network = 'CA:MB:PTH' AND ref = '75' THEN 'ca-provincial-arterial'::route_network_type
           WHEN network = 'CA:AB:primary' AND ref IN ('2','3','4') THEN 'ca-provincial-arterial'::route_network_type
           WHEN network = 'CA:BC' AND ref IN ('3','5','99') THEN 'ca-provincial-arterial'::route_network_type
           WHEN network LIKE 'CA:__' OR network LIKE 'CA:__:%' THEN 'ca-provincial'::route_network_type
           WHEN network = 'omt-gb-motorway' THEN 'gb-motorway'::route_network_type
           WHEN network = 'omt-gb-trunk' THEN 'gb-trunk'::route_network_type
           WHEN network = 'omt-gb-primary' THEN 'gb-primary'::route_network_type
           WHEN network = 'omt-ie-motorway' THEN 'ie-motorway'::route_network_type
           WHEN network = 'omt-ie-national' THEN 'ie-national'::route_network_type
           WHEN network = 'omt-ie-regional' THEN 'ie-regional'::route_network_type
            END;
$$ LANGUAGE sql IMMUTABLE
                PARALLEL SAFE;

CREATE TABLE IF NOT EXISTS transportation_route_member_coalesced
(
    member            bigint,
    network           varchar,
    ref               varchar,
    osm_id            bigint not null,
    role              varchar,
    type              smallint,
    name              varchar,
    osmc_symbol       varchar,
    colour            varchar,
    ref_colour        varchar,
    network_type      route_network_type,
    concurrency_index integer,
    rank              integer,
    PRIMARY KEY (member, network, ref)
);

CREATE OR REPLACE FUNCTION update_osm_route_member(full_update bool) RETURNS void AS
$$
BEGIN
    -- Analyze tracking and source tables before performing update
    ANALYZE transportation_name.network_changes;
    ANALYZE osm_highway_linestring;
    ANALYZE osm_route_member;

    DELETE
    FROM transportation_route_member_coalesced
    USING transportation_name.network_changes c
    WHERE c.is_old IS TRUE AND transportation_route_member_coalesced.member = c.osm_id;

    -- etldoc: osm_route_member ->  transportation_route_member_coalesced
    INSERT INTO transportation_route_member_coalesced
    SELECT
      osm_route_member_filtered.*,
      osm_route_member_network_type(network, ref) AS network_type,
      DENSE_RANK() OVER (
          PARTITION BY member
          ORDER BY osm_route_member_network_type(network, ref), network, LENGTH(ref), ref
      ) AS concurrency_index,
      CASE
           WHEN network IN ('iwn', 'nwn', 'rwn') THEN 1
           WHEN network = 'lwn' THEN 2
           WHEN osmc_symbol || colour <> '' THEN 2
      END AS rank
    FROM (
        -- etldoc:  osm_route_member ->  osm_route_member
        -- etldoc:  gbr_route_members_view ->  osm_route_member
        -- etldoc:  ire_route_members_view ->  osm_route_member
        -- see http://wiki.openstreetmap.org/wiki/Relation:route#Road_routes
        SELECT DISTINCT ON (member, COALESCE(rel.network, ''), COALESCE(rel.ref, ''))
            rel.member,
            COALESCE(NULLIF(rel.network,''), gb_way.network, ir_way.network, '') AS network,
            COALESCE(rel.ref, '') AS ref,
            osm_id,
            role,
            type,
            name,
            osmc_symbol,
            colour,
            ref_colour
        FROM osm_route_member rel
        LEFT JOIN gbr_route_members_view gb_way ON (gb_way.member=rel.member)
        LEFT JOIN ire_route_members_view ir_way ON (ir_way.member=rel.member)
        WHERE full_update OR EXISTS(
            SELECT NULL
            FROM transportation_name.network_changes c
            WHERE c.is_old IS FALSE AND c.osm_id = rel.member
        )
    ) osm_route_member_filtered
    ON CONFLICT (member, network, ref) DO UPDATE SET osm_id = EXCLUDED.osm_id, role = EXCLUDED.role,
                                                     type = EXCLUDED.type, name = EXCLUDED.name,
                                                     osmc_symbol = EXCLUDED.osmc_symbol, colour = EXCLUDED.colour, ref_colour = EXCLUDED.ref_colour,
                                                     concurrency_index = EXCLUDED.concurrency_index,
                                                     rank = EXCLUDED.rank;
END;
$$ LANGUAGE plpgsql;

-- Indexes which can be utilized during full-update for queries originating from update_osm_route_member() function
CREATE INDEX IF NOT EXISTS osm_route_member_member_network_ref_idx
    ON osm_route_member (member, COALESCE(network, ''), COALESCE(ref, ''));

-- Analyze created index
ANALYZE osm_route_member;

-- Ensure transportation_name.network_changes table exists since it is required by update_osm_route_member
CREATE SCHEMA IF NOT EXISTS transportation_name;
CREATE TABLE IF NOT EXISTS transportation_name.network_changes
(
    is_old bool,
    osm_id bigint,
    PRIMARY KEY (is_old, osm_id)
);

-- Fill transportation_route_member_coalesced table
TRUNCATE transportation_route_member_coalesced;
SELECT update_osm_route_member(TRUE);

-- Index for queries against transportation_route_member_coalesced during transportation-name-network updates
CREATE INDEX IF NOT EXISTS transportation_route_member_member_idx ON
    transportation_route_member_coalesced ("member", "concurrency_index");

-- Analyze populated table with indexes
ANALYZE transportation_route_member_coalesced;

-- Ensure OSM-ID index exists on osm_highway_linestring
CREATE UNIQUE INDEX IF NOT EXISTS osm_highway_linestring_osm_id_idx ON osm_highway_linestring ("osm_id");

-- etldoc:  osm_route_member ->  osm_highway_linestring
UPDATE osm_highway_linestring hl
  SET network = rm.network_type
  FROM transportation_route_member_coalesced rm
  WHERE hl.osm_id=rm.member AND rm.concurrency_index=1;

-- etldoc:  osm_route_member ->  osm_highway_linestring_gen_z11
UPDATE osm_highway_linestring_gen_z11 hl
  SET network = rm.network_type
  FROM transportation_route_member_coalesced rm
  WHERE hl.osm_id=rm.member AND rm.concurrency_index=1;

-- Layer transportation - ./update_transportation_merge.sql

DROP TRIGGER IF EXISTS trigger_store_osm_transportation_merge_linestring_gen_z8 ON osm_transportation_merge_linestring_gen_z8;
DROP TRIGGER IF EXISTS trigger_store_transportation_highway_linestring_gen_z9 ON osm_transportation_merge_linestring_gen_z9;
DROP TRIGGER IF EXISTS trigger_flag_transportation_z9 ON osm_transportation_merge_linestring_gen_z9;
DROP TRIGGER IF EXISTS trigger_refresh_z8 ON transportation.updates_z9;
DROP TRIGGER IF EXISTS trigger_store_transportation_highway_linestring_gen_z11 ON osm_highway_linestring_gen_z11;
DROP TRIGGER IF EXISTS trigger_store_osm_transportation_merge_linestring_gen_z11 ON osm_transportation_merge_linestring_gen_z11;
DROP TRIGGER IF EXISTS trigger_flag_transportation_z11 ON osm_highway_linestring_gen_z11;
DROP TRIGGER IF EXISTS trigger_refresh_z11 ON transportation.updates_z11;
DROP TRIGGER IF EXISTS trigger_store_transportation_name_network ON osm_transportation_name_network;

-- Determine whether a segment is long enough to have bridge/tunnel attributes
-- Dropping small brunnel sections allow for generalization as distinct segments get too small
CREATE OR REPLACE FUNCTION visible_brunnel(g geometry, brunnel boolean, zoom_level integer)
    RETURNS boolean AS
$$
SELECT
    brunnel AND
    -- Width of a tile in meters (111,842 is the length of one degree of latitude at the equator in meters)
    -- 111,842 * 180 / 2^zoom_level
    --  = 20131560 / POW(2, zoom_level)
    -- Drop brunnel if length of way < 2% of tile width (less than 3 pixels)
    ST_Length(g) *
        COS(RADIANS(ST_Y(ST_Centroid(ST_Transform(g, 4326))))) *
        POW(2, zoom_level) / 20131560 > 0.02
$$ LANGUAGE SQL IMMUTABLE
                PARALLEL SAFE;

-- Determine whether a segment is long enough to have layer attributes
CREATE OR REPLACE FUNCTION visible_layer(g geometry, layer int, zoom_level integer)
    RETURNS int AS
$$
SELECT
    CASE WHEN
    -- Width of a tile in meters (111,842 is the length of one degree of latitude at the equator in meters)
    -- 111,842 * 180 / 2^zoom_level
    --  = 20131560 / POW(2, zoom_level)
    -- Drop brunnel if length of way < 2% of tile width (less than 3 pixels)
    ST_Length(g) *
        COS(RADIANS(ST_Y(ST_Centroid(ST_Transform(g, 4326))))) *
        POW(2, zoom_level) / 20131560 > 0.02
    THEN layer END
$$ LANGUAGE SQL IMMUTABLE
                PARALLEL SAFE;

-- Determine whether a segment is long enough to have an attribute
CREATE OR REPLACE FUNCTION visible_text(g geometry, attr text, zoom_level integer)
    RETURNS text AS
$$
SELECT
    CASE WHEN
    -- Width of a tile in meters (111,842 is the length of one degree of latitude at the equator in meters)
    -- 111,842 * 180 / 2^zoom_level
    --  = 20131560 / POW(2, zoom_level)
    -- Drop brunnel if length of way < 2% of tile width (less than 3 pixels)
    ST_Length(g) *
        COS(RADIANS(ST_Y(ST_Centroid(ST_Transform(g, 4326))))) *
        POW(2, zoom_level) / 20131560 > 0.02
    THEN attr END
$$ LANGUAGE SQL IMMUTABLE
                PARALLEL SAFE;

-- Instead of using relations to find out the road names we
-- stitch together the touching ways with the same name
-- to allow for nice label rendering
-- Because this works well for roads that do not have relations as well

-- etldoc: osm_highway_linestring ->  osm_transportation_name_network
-- etldoc: transportation_route_member_coalesced ->  osm_transportation_name_network
DROP TABLE IF EXISTS osm_transportation_name_network;
CREATE TABLE osm_transportation_name_network AS
SELECT
    geometry,
    osm_id,
    tags || get_basic_names(tags, geometry) AS tags,
    ref,
    highway,
    subclass,
    brunnel,
    "level",
    sac_scale,
    layer,
    indoor,
    network_type,
    route_1, route_2, route_3, route_4, route_5, route_6,
    z_order,
    route_rank
FROM (
    SELECT DISTINCT ON (hl.osm_id)
        hl.geometry,
        hl.osm_id,
        transportation_name_tags(hl.geometry, hl.tags, hl.name, hl.name_en, hl.name_de) AS tags,
        rm1.network_type,
        CASE
            WHEN rm1.network_type IS NOT NULL AND rm1.ref::text <> ''
                THEN rm1.ref::text
            ELSE NULLIF(hl.ref, '')
            END AS ref,
        hl.highway,
        NULLIF(hl.construction, '') AS subclass,
        brunnel(hl.is_bridge, hl.is_tunnel, hl.is_ford) AS brunnel,
        sac_scale,
        CASE WHEN highway IN ('footway', 'steps') THEN layer END AS layer,
        CASE WHEN highway IN ('footway', 'steps') THEN level END AS level,
        CASE WHEN highway IN ('footway', 'steps') THEN indoor END AS indoor,
        create_route_hstore(rm1.network, rm1.ref, rm1.name, rm1.colour, rm1.ref_colour) AS route_1,
        create_route_hstore(rm2.network, rm2.ref, rm2.name, rm2.colour, rm2.ref_colour) AS route_2,
        create_route_hstore(rm3.network, rm3.ref, rm3.name, rm3.colour, rm3.ref_colour) AS route_3,
        create_route_hstore(rm4.network, rm4.ref, rm4.name, rm4.colour, rm4.ref_colour) AS route_4,
        create_route_hstore(rm5.network, rm5.ref, rm5.name, rm5.colour, rm5.ref_colour) AS route_5,
        create_route_hstore(rm6.network, rm6.ref, rm6.name, rm6.colour, rm6.ref_colour) AS route_6,
        hl.z_order,
        LEAST(rm1.rank, rm2.rank, rm3.rank, rm4.rank, rm5.rank, rm6.rank) AS route_rank
    FROM osm_highway_linestring hl
            LEFT OUTER JOIN transportation_route_member_coalesced rm1 ON rm1.member = hl.osm_id AND rm1.concurrency_index=1
            LEFT OUTER JOIN transportation_route_member_coalesced rm2 ON rm2.member = hl.osm_id AND rm2.concurrency_index=2
            LEFT OUTER JOIN transportation_route_member_coalesced rm3 ON rm3.member = hl.osm_id AND rm3.concurrency_index=3
            LEFT OUTER JOIN transportation_route_member_coalesced rm4 ON rm4.member = hl.osm_id AND rm4.concurrency_index=4
            LEFT OUTER JOIN transportation_route_member_coalesced rm5 ON rm5.member = hl.osm_id AND rm5.concurrency_index=5
            LEFT OUTER JOIN transportation_route_member_coalesced rm6 ON rm6.member = hl.osm_id AND rm6.concurrency_index=6
    WHERE (hl.name <> '' OR hl.ref <> '' OR rm1.ref <> '' OR rm1.network <> '')
      AND hl.highway <> ''
) AS t;

-- Create Primary-Key for osm_transportation_name_network table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_transportation_name_network' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_transportation_name_network ADD PRIMARY KEY (osm_id);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Geometry Index
CREATE INDEX IF NOT EXISTS osm_transportation_name_network_geometry_idx
    ON osm_transportation_name_network USING gist (geometry);

-- etldoc: osm_highway_linestring_gen_z11 ->  osm_transportation_merge_linestring_gen_z11
CREATE TABLE IF NOT EXISTS osm_transportation_merge_linestring_gen_z11(
    geometry geometry('LineString'),
    id SERIAL,
    osm_id bigint,
    source_ids bigint[],
    new_source_ids bigint[],
    old_source_ids bigint[],
    highway character varying,
    network character varying,
    construction character varying,
    is_bridge boolean,
    is_tunnel boolean,
    is_ford boolean,
    expressway boolean,
    z_order integer,
    bicycle character varying,
    foot character varying,
    horse character varying,
    mtb_scale character varying,
    sac_scale character varying,
    operator character varying,
    informal character varying,
    access text,
    toll boolean,
    layer integer
);

ALTER TABLE osm_transportation_merge_linestring_gen_z11 ADD COLUMN IF NOT EXISTS source_ids bigint[];
ALTER TABLE osm_transportation_merge_linestring_gen_z11 ADD COLUMN IF NOT EXISTS new_source_ids BIGINT[];
ALTER TABLE osm_transportation_merge_linestring_gen_z11 ADD COLUMN IF NOT EXISTS old_source_ids BIGINT[];

CREATE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z11_n_source_ids_not_null_idx 
    ON osm_transportation_merge_linestring_gen_z11 ((new_source_ids IS NOT NULL));
CREATE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z11_o_source_ids_not_null_idx 
    ON osm_transportation_merge_linestring_gen_z11 ((old_source_ids IS NOT NULL));

-- Create osm_transportation_merge_linestring_gen_z10 as a copy of osm_transportation_merge_linestring_gen_z11 but
-- drop the "source_ids" column. This can be done because z10 and z9 tables are only simplified and not merged,
-- therefore relations to sources are direct via the id column.
CREATE TABLE IF NOT EXISTS osm_transportation_merge_linestring_gen_z10
    (LIKE osm_transportation_merge_linestring_gen_z11);
ALTER TABLE osm_transportation_merge_linestring_gen_z10 DROP COLUMN IF EXISTS source_ids;
ALTER TABLE osm_transportation_merge_linestring_gen_z10 DROP COLUMN IF EXISTS new_source_ids;
ALTER TABLE osm_transportation_merge_linestring_gen_z10 DROP COLUMN IF EXISTS old_source_ids;

-- Create osm_transportation_merge_linestring_gen_z9 as a copy of osm_transportation_merge_linestring_gen_z10
CREATE TABLE IF NOT EXISTS osm_transportation_merge_linestring_gen_z9
    (LIKE osm_transportation_merge_linestring_gen_z10);

-- Create OneToMany-Relation-Table storing relations of a Merged-LineString in table
-- osm_transportation_merge_linestring_gen_z11 to Source-LineStrings from table osm_highway_linestring_gen_z11
CREATE TABLE IF NOT EXISTS osm_transportation_merge_linestring_gen_z11_source_ids(
    id int,
    source_id bigint,
    PRIMARY KEY (id, source_id)
);

-- Index for storing OSM-IDs of Source-LineStrings
CREATE UNIQUE INDEX IF NOT EXISTS osm_highway_linestring_gen_z11_osm_id_idx ON osm_highway_linestring_gen_z11 ("osm_id");

-- Analyze created indexes
ANALYZE osm_highway_linestring_gen_z11;

-- Ensure tables are emtpy if they haven't been created
TRUNCATE osm_transportation_merge_linestring_gen_z11;
TRUNCATE osm_transportation_merge_linestring_gen_z11_source_ids;

-- Merge LineStrings from osm_highway_linestring_gen_z11 by grouping them and creating intersecting clusters of
-- each group via ST_ClusterDBSCAN
INSERT INTO osm_transportation_merge_linestring_gen_z11 (geometry, source_ids, highway, network, construction,
                                                         is_bridge, is_tunnel, is_ford, expressway, z_order,
                                                         bicycle, foot, horse, mtb_scale, sac_scale, operator,
                                                         informal, access, toll, layer)
SELECT (ST_Dump(ST_LineMerge(ST_Union(geometry)))).geom AS geometry,
       -- We use St_Union instead of St_Collect to ensure no overlapping points exist within the geometries to
       -- merge. https://postgis.net/docs/ST_Union.html
       -- ST_LineMerge only merges across singular intersections and groups its output into a MultiLineString if
       -- more than two LineStrings form an intersection or no intersection could be found.
       -- https://postgis.net/docs/ST_LineMerge.html
       -- In order to not end up with a mixture of LineStrings and MultiLineStrings we dump eventual
       -- MultiLineStrings via ST_Dump. https://postgis.net/docs/ST_Dump.html
       array_agg(osm_id) as source_ids,
       -- Temporary Merged-LineString to Source-LineStrings-ID column to store relations before they have been
       -- intersected
       highway,
       network,
       construction,
       is_bridge,
       is_tunnel,
       is_ford,
       expressway,
       min(z_order) as z_order,
       bicycle,
       foot,
       horse,
       mtb_scale,
       sac_scale,
       operator,
       informal,
       CASE
           WHEN access IN ('private', 'no') THEN 'no'
           ELSE NULL::text END AS access,
       toll,
       layer
FROM (
    SELECT osm_highway_linestring_normalized_brunnel_z11.*,
           -- Get intersecting clusters by setting minimum distance to 0 and minimum intersecting points to 1
           -- https://postgis.net/docs/ST_ClusterDBSCAN.html
           ST_ClusterDBSCAN(geometry, 0, 1) OVER (
               PARTITION BY highway, network, construction, is_bridge, is_tunnel, is_ford, expressway, bicycle,
                            foot, horse, mtb_scale, sac_scale, operator, informal, access, toll, layer
           ) AS cluster,
           -- ST_ClusterDBSCAN returns an increasing integer as the cluster-ids within each partition starting at 0.
           -- This leads to clusters having the same ID across multiple partitions therefore we generate a
           -- Cluster-Group-ID by utilizing the DENSE_RANK function sorted over the partition columns.
           DENSE_RANK() OVER (
               ORDER BY highway, network, construction, is_bridge, is_tunnel, is_ford, expressway, bicycle,
                        foot, horse, mtb_scale, sac_scale, operator, informal, access, toll, layer
           ) as cluster_group
    FROM (
        -- Remove bridge/tunnel/ford attributes from short sections of road so they can be merged
        SELECT geometry,
               osm_id,
               highway,
               network,
               construction,
               visible_brunnel(geometry, is_bridge, 11) AS is_bridge,
               visible_brunnel(geometry, is_tunnel, 11) AS is_tunnel,
               visible_brunnel(geometry, is_ford, 11) AS is_ford,
               expressway,
               z_order,
               bicycle,
               foot,
               horse,
               mtb_scale,
               sac_scale,
               operator,
               informal,
               access,
               toll,
               visible_layer(geometry, layer, 11) AS layer
        FROM osm_highway_linestring_gen_z11
    ) osm_highway_linestring_normalized_brunnel_z11
) q
GROUP BY cluster_group, cluster, highway, network, construction, is_bridge, is_tunnel, is_ford, expressway,
         bicycle, foot, horse, mtb_scale, sac_scale, operator, informal, access, toll, layer;

-- Geometry Index
CREATE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z11_geometry_idx
    ON osm_transportation_merge_linestring_gen_z11 USING gist (geometry);

-- Create Primary-Keys for osm_transportation_merge_linestring_gen_z11/z10/z9 tables
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_transportation_merge_linestring_gen_z11' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_transportation_merge_linestring_gen_z11 ADD PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_transportation_merge_linestring_gen_z10' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_transportation_merge_linestring_gen_z10 ADD PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_transportation_merge_linestring_gen_z9' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_transportation_merge_linestring_gen_z9 ADD PRIMARY KEY (id);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Indexes which can be utilized during full-update for queries originating from
-- insert_transportation_merge_linestring_gen_z10() function
CREATE UNIQUE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z11_update_partial_idx
    ON osm_transportation_merge_linestring_gen_z11 (id)
    WHERE highway NOT IN ('tertiary', 'tertiary_link', 'busway') AND
          construction NOT IN ('tertiary', 'tertiary_link', 'busway');

-- Analyze populated table with new indexes
ANALYZE osm_transportation_merge_linestring_gen_z11;

-- Store OSM-IDs of Source-LineStrings by intersecting Merged-LineStrings with their sources. This required because
-- ST_LineMerge only merges across singular intersections and groups its output into a MultiLineString if
-- more than two LineStrings form an intersection or no intersection could be found.
-- Execute after indexes have been created on osm_highway_linestring_gen_z11 to improve performance
INSERT INTO osm_transportation_merge_linestring_gen_z11_source_ids (id, source_id)
SELECT m.id, m.source_id
FROM (
    SELECT id, unnest(source_ids) AS source_id, geometry
    FROM osm_transportation_merge_linestring_gen_z11
) m
JOIN osm_highway_linestring_gen_z11 s ON (m.source_id = s.osm_id)
WHERE ST_Intersects(s.geometry, m.geometry)
ON CONFLICT (id, source_id) DO NOTHING;

-- Drop temporary Merged-LineString to Source-LineStrings-ID column
ALTER TABLE osm_transportation_merge_linestring_gen_z11 DROP COLUMN IF EXISTS source_ids;

CREATE SCHEMA IF NOT EXISTS transportation;

CREATE TABLE IF NOT EXISTS transportation.changes_z9_z10
(
    is_old boolean,
    id int,
    PRIMARY KEY (is_old, id)
);

CREATE OR REPLACE FUNCTION insert_transportation_merge_linestring_gen_z10(full_update bool) RETURNS void AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh transportation z9 10';

    -- Analyze tracking and source tables before performing update
    ANALYZE transportation.changes_z9_z10;
    ANALYZE osm_transportation_merge_linestring_gen_z11;

    -- Remove entries which have been deleted from source table
    DELETE FROM osm_transportation_merge_linestring_gen_z10
    USING transportation.changes_z9_z10
    WHERE full_update IS TRUE OR (
        transportation.changes_z9_z10.is_old IS TRUE AND
        transportation.changes_z9_z10.id = osm_transportation_merge_linestring_gen_z10.id
    );

    -- etldoc: osm_transportation_merge_linestring_gen_z11 -> osm_transportation_merge_linestring_gen_z10
    INSERT INTO osm_transportation_merge_linestring_gen_z10
    SELECT ST_Simplify(geometry, ZRes(12)) AS geometry,
        id,
        osm_id,
        highway,
        network,
        construction,
        -- Remove bridge/tunnel/ford attributes from short sections of road so they can be merged
        visible_brunnel(geometry, is_bridge, 11) AS is_bridge,
        visible_brunnel(geometry, is_tunnel, 11) AS is_tunnel,
        visible_brunnel(geometry, is_ford, 11) AS is_ford,
        expressway,
        z_order,
        bicycle,
        foot,
        horse,
        mtb_scale,
        sac_scale,
        operator,
        informal,
        access,
        toll,
        visible_layer(geometry, layer, 11) AS layer
    FROM osm_transportation_merge_linestring_gen_z11
    WHERE (full_update IS TRUE OR EXISTS(
            SELECT NULL FROM transportation.changes_z9_z10
            WHERE transportation.changes_z9_z10.is_old IS FALSE AND
                  transportation.changes_z9_z10.id = osm_transportation_merge_linestring_gen_z11.id
        ))
        AND (
            highway NOT IN ('tertiary', 'tertiary_link', 'busway', 'bus_guideway')
            AND construction NOT IN ('tertiary', 'tertiary_link', 'busway', 'bus_guideway')
        )
    ON CONFLICT (id) DO UPDATE SET osm_id = excluded.osm_id, highway = excluded.highway, network = excluded.network,
                                   construction = excluded.construction, is_bridge = excluded.is_bridge,
                                   is_tunnel = excluded.is_tunnel, is_ford = excluded.is_ford,
                                   expressway = excluded.expressway, z_order = excluded.z_order,
                                   bicycle = excluded.bicycle, foot = excluded.foot, horse = excluded.horse,
                                   mtb_scale = excluded.mtb_scale, sac_scale = excluded.sac_scale,
                                   operator = excluded.operator, informal = excluded.informal,
                                   access = excluded.access, toll = excluded.toll, layer = excluded.layer;

    -- Remove entries which have been deleted from source table
    DELETE FROM osm_transportation_merge_linestring_gen_z9
    USING transportation.changes_z9_z10
    WHERE full_update IS TRUE OR (
        transportation.changes_z9_z10.is_old IS TRUE AND
        transportation.changes_z9_z10.id = osm_transportation_merge_linestring_gen_z9.id
    );

    -- Analyze source table
    ANALYZE osm_transportation_merge_linestring_gen_z10;

    -- etldoc: osm_transportation_merge_linestring_gen_z10 -> osm_transportation_merge_linestring_gen_z9
    INSERT INTO osm_transportation_merge_linestring_gen_z9
    SELECT ST_Simplify(geometry, ZRes(11)) AS geometry,
        id,
        osm_id,
        highway,
        network,
        construction,
        -- Remove bridge/tunnel/ford attributes from short sections of road so they can be merged
        visible_brunnel(geometry, is_bridge, 10) AS is_bridge,
        visible_brunnel(geometry, is_tunnel, 10) AS is_tunnel,
        visible_brunnel(geometry, is_ford, 10) AS is_ford,
        expressway,
        z_order,
        bicycle,
        foot,
        horse,
        mtb_scale,
        sac_scale,
        operator,
        informal,
        access,
        toll,
        visible_layer(geometry, layer, 10) AS layer
    FROM osm_transportation_merge_linestring_gen_z10
    WHERE full_update IS TRUE OR EXISTS(
            SELECT NULL FROM transportation.changes_z9_z10
            WHERE transportation.changes_z9_z10.is_old IS FALSE AND
                  transportation.changes_z9_z10.id = osm_transportation_merge_linestring_gen_z10.id
            )
    ON CONFLICT (id) DO UPDATE SET osm_id = excluded.osm_id, highway = excluded.highway, network = excluded.network,
                                   construction = excluded.construction, is_bridge = excluded.is_bridge,
                                   is_tunnel = excluded.is_tunnel, is_ford = excluded.is_ford,
                                   expressway = excluded.expressway, z_order = excluded.z_order,
                                   bicycle = excluded.bicycle, foot = excluded.foot, horse = excluded.horse,
                                   mtb_scale = excluded.mtb_scale, sac_scale = excluded.sac_scale,
                                   operator = excluded.operator, informal = excluded.informal,
                                   access = excluded.access, toll = excluded.toll, layer = excluded.layer;

    -- noinspection SqlWithoutWhere
    DELETE FROM transportation.changes_z9_z10;

    RAISE LOG 'Refresh transportation z9 10 done in %', age(clock_timestamp(), t);
END;
$$ LANGUAGE plpgsql;

-- Ensure tables are emtpy if they haven't been created
TRUNCATE osm_transportation_merge_linestring_gen_z10;
TRUNCATE osm_transportation_merge_linestring_gen_z9;

SELECT insert_transportation_merge_linestring_gen_z10(TRUE);

-- Geometry Indexes
CREATE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z10_geometry_idx
    ON osm_transportation_merge_linestring_gen_z10 USING gist (geometry);
CREATE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z9_geometry_idx
    ON osm_transportation_merge_linestring_gen_z9 USING gist (geometry);

-- etldoc: osm_transportation_merge_linestring_gen_z9 -> osm_transportation_merge_linestring_gen_z8
CREATE TABLE IF NOT EXISTS osm_transportation_merge_linestring_gen_z8(
    geometry geometry,
    id SERIAL,
    osm_id bigint,
    source_ids int[],
    new_source_ids bigint[],
    old_source_ids bigint[],
    highway character varying,
    network character varying,
    construction character varying,
    is_bridge boolean,
    is_tunnel boolean,
    is_ford boolean,
    expressway boolean,
    z_order integer
);

ALTER TABLE osm_transportation_merge_linestring_gen_z8 ADD COLUMN IF NOT EXISTS source_ids bigint[];
ALTER TABLE osm_transportation_merge_linestring_gen_z8 ADD COLUMN IF NOT EXISTS new_source_ids bigint[];
ALTER TABLE osm_transportation_merge_linestring_gen_z8 ADD COLUMN IF NOT EXISTS old_source_ids bigint[];

CREATE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z8_n_source_ids_not_null_idx 
    ON osm_transportation_merge_linestring_gen_z8 ((new_source_ids IS NOT NULL));
CREATE INDEX IF NOT EXISTS  osm_transportation_merge_linestring_gen_z8_o_source_ids_not_null_idx 
    ON osm_transportation_merge_linestring_gen_z8 ((old_source_ids IS NOT NULL));

-- Create osm_transportation_merge_linestring_gen_z7 as a copy of osm_transportation_merge_linestring_gen_z8 but
-- drop the "source_ids" column. This can be done because z7 to z5 tables are only simplified and not merged,
-- therefore relations to sources are direct via the id column.
CREATE TABLE IF NOT EXISTS osm_transportation_merge_linestring_gen_z7
    (LIKE osm_transportation_merge_linestring_gen_z8);
ALTER TABLE osm_transportation_merge_linestring_gen_z7 DROP COLUMN IF EXISTS source_ids;
ALTER TABLE osm_transportation_merge_linestring_gen_z7 DROP COLUMN IF EXISTS new_source_ids;
ALTER TABLE osm_transportation_merge_linestring_gen_z7 DROP COLUMN IF EXISTS old_source_ids;

-- Create osm_transportation_merge_linestring_gen_z6 as a copy of osm_transportation_merge_linestring_gen_z7
CREATE TABLE IF NOT EXISTS osm_transportation_merge_linestring_gen_z6
    (LIKE osm_transportation_merge_linestring_gen_z7);

-- Create osm_transportation_merge_linestring_gen_z5 as a copy of osm_transportation_merge_linestring_gen_z6
CREATE TABLE IF NOT EXISTS osm_transportation_merge_linestring_gen_z5
    (LIKE osm_transportation_merge_linestring_gen_z6);

-- Create osm_transportation_merge_linestring_gen_z4 as a copy of osm_transportation_merge_linestring_gen_z5
CREATE TABLE IF NOT EXISTS osm_transportation_merge_linestring_gen_z4
    (LIKE osm_transportation_merge_linestring_gen_z5);

-- Create OneToMany-Relation-Table storing relations of a Merged-LineString in table
-- osm_transportation_merge_linestring_gen_z8 to Source-LineStrings from table
-- osm_transportation_merge_linestring_gen_z9
CREATE TABLE IF NOT EXISTS osm_transportation_merge_linestring_gen_z8_source_ids(
    id int,
    source_id bigint,
    PRIMARY KEY (id, source_id)
);

-- Ensure tables are emtpy if they haven't been created
TRUNCATE osm_transportation_merge_linestring_gen_z8;
TRUNCATE osm_transportation_merge_linestring_gen_z8_source_ids;

-- Indexes for filling and updating osm_transportation_merge_linestring_gen_z8 table
CREATE UNIQUE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z9_update_partial_idx
    ON osm_transportation_merge_linestring_gen_z9 (id)
    WHERE (
        highway IN ('motorway', 'trunk', 'primary') OR
        construction IN ('motorway', 'trunk', 'primary')
    ) AND ST_IsValid(geometry) AND access IS NULL;

-- Analyze populated table with indexes
ANALYZE osm_transportation_merge_linestring_gen_z9;

-- Merge LineStrings from osm_transportation_merge_linestring_gen_z9 by grouping them and creating intersecting
-- clusters of each group via ST_ClusterDBSCAN
INSERT INTO osm_transportation_merge_linestring_gen_z8(geometry, source_ids, highway, network, construction, is_bridge,
                                                       is_tunnel, is_ford, expressway, z_order)
SELECT (ST_Dump(ST_Simplify(ST_LineMerge(ST_Union(geometry)), ZRes(10)))).geom AS geometry,
       -- We use St_Union instead of St_Collect to ensure no overlapping points exist within the geometries to
       -- merge. https://postgis.net/docs/ST_Union.html
       -- ST_LineMerge only merges across singular intersections and groups its output into a MultiLineString if
       -- more than two LineStrings form an intersection or no intersection could be found.
       -- https://postgis.net/docs/ST_LineMerge.html
       -- In order to not end up with a mixture of LineStrings and MultiLineStrings we dump eventual
       -- MultiLineStrings via ST_Dump. https://postgis.net/docs/ST_Dump.html
       array_agg(id) AS source_ids,
       -- Temporary Merged-LineString to Source-LineStrings-ID column to store relations before they have been
       -- intersected
       highway,
       network,
       construction,
       is_bridge,
       is_tunnel,
       is_ford,
       expressway,
       min(z_order) as z_order
FROM (
    SELECT osm_highway_linestring_normalized_brunnel_z9.*,
           -- Get intersecting clusters by setting minimum distance to 0 and minimum intersecting points to 1
           -- https://postgis.net/docs/ST_ClusterDBSCAN.html
           ST_ClusterDBSCAN(geometry, 0, 1) OVER (
               PARTITION BY highway, network, construction, is_bridge, is_tunnel, is_ford, expressway
           ) AS cluster,
           -- ST_ClusterDBSCAN returns an increasing integer as the cluster-ids within each partition starting at 0.
           -- This leads to clusters having the same ID across multiple partitions therefore we generate a
           -- Cluster-Group-ID by utilizing the DENSE_RANK function sorted over the partition columns.
           DENSE_RANK() OVER (
               ORDER BY highway, network, construction, is_bridge, is_tunnel, is_ford, expressway
           ) as cluster_group
    FROM (
        -- Remove bridge/tunnel/ford attributes from short sections of road so they can be merged
        SELECT id,
               geometry,
               highway,
               network,
               construction,
               visible_brunnel(geometry, is_bridge, 9) AS is_bridge,
               visible_brunnel(geometry, is_tunnel, 9) AS is_tunnel,
               visible_brunnel(geometry, is_ford, 9) AS is_ford,
               expressway,
               z_order
        FROM osm_transportation_merge_linestring_gen_z9
        WHERE (
            highway IN ('motorway', 'trunk', 'primary') OR
            construction IN ('motorway', 'trunk', 'primary')
        ) AND ST_IsValid(geometry) AND access IS NULL
    ) osm_highway_linestring_normalized_brunnel_z9
) q
GROUP BY cluster_group, cluster, highway, network, construction, is_bridge, is_tunnel, is_ford, expressway;

-- Geometry Index
CREATE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z8_geometry_idx
    ON osm_transportation_merge_linestring_gen_z8 USING gist (geometry);

-- Create Primary-Keys for osm_transportation_merge_linestring_gen_z8/z7/z6/z5/z4 tables
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_transportation_merge_linestring_gen_z8' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_transportation_merge_linestring_gen_z8 ADD PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_transportation_merge_linestring_gen_z7' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_transportation_merge_linestring_gen_z7 ADD PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_transportation_merge_linestring_gen_z6' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_transportation_merge_linestring_gen_z6 ADD PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_transportation_merge_linestring_gen_z5' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_transportation_merge_linestring_gen_z5 ADD PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_transportation_merge_linestring_gen_z4' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_transportation_merge_linestring_gen_z4 ADD PRIMARY KEY (id);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Indexes which can be utilized during full-update for queries originating from
-- insert_transportation_merge_linestring_gen_z7() function
CREATE UNIQUE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z8_update_partial_idx
    ON osm_transportation_merge_linestring_gen_z8 (id)
    WHERE ST_Length(geometry) > 50;

-- Analyze populated table with indexes
ANALYZE osm_transportation_merge_linestring_gen_z8;

-- Store OSM-IDs of Source-LineStrings by intersecting Merged-LineStrings with their sources. This required because
-- ST_LineMerge only merges across singular intersections and groups its output into a MultiLineString if
-- more than two LineStrings form an intersection or no intersection could be found.
-- Execute after indexes have been created on osm_transportation_merge_linestring_gen_z11 to improve performance
INSERT INTO osm_transportation_merge_linestring_gen_z8_source_ids (id, source_id)
SELECT m.id, m.source_id
FROM (
    SELECT id, unnest(source_ids) AS source_id, geometry
    FROM osm_transportation_merge_linestring_gen_z8
) m
JOIN osm_transportation_merge_linestring_gen_z9 s ON (m.source_id = s.id)
WHERE ST_Intersects(s.geometry, m.geometry)
ON CONFLICT (id, source_id) DO NOTHING;

-- Drop temporary Merged-LineString to Source-LineStrings-ID column
ALTER TABLE osm_transportation_merge_linestring_gen_z8 DROP COLUMN IF EXISTS source_ids;

CREATE TABLE IF NOT EXISTS transportation.changes_z4_z5_z6_z7
(
    is_old boolean,
    id int,
    PRIMARY KEY (is_old, id)
);

CREATE OR REPLACE FUNCTION insert_transportation_merge_linestring_gen_z7(full_update boolean) RETURNS void AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh transportation z4 z5 z6 z7';

    -- Analyze tracking and source tables before performing update
    ANALYZE transportation.changes_z4_z5_z6_z7;
    ANALYZE osm_transportation_merge_linestring_gen_z8;

    -- Remove entries which have been deleted from source table
    DELETE FROM osm_transportation_merge_linestring_gen_z7
    USING transportation.changes_z4_z5_z6_z7
    WHERE full_update IS TRUE OR (
        transportation.changes_z4_z5_z6_z7.is_old IS TRUE AND
        transportation.changes_z4_z5_z6_z7.id = osm_transportation_merge_linestring_gen_z7.id
    );

    -- etldoc: osm_transportation_merge_linestring_gen_z8 -> osm_transportation_merge_linestring_gen_z7
    INSERT INTO osm_transportation_merge_linestring_gen_z7
    WITH roads_z8 AS (
        SELECT  id,
                osm_id,
                ST_SnapToGrid(
                    ST_Node(
                        ST_Collect(
                            ST_Simplify(geometry, ZRes(9))
                            )
                        ), ZRes(9)
                    ) AS geometry,
                highway, 
                NULLIF(network, '') as network,
                construction,
                is_bridge, 
                is_tunnel, 
                is_ford,
                expressway,
                z_order
        FROM osm_transportation_merge_linestring_gen_z8
        GROUP BY id, osm_id, highway, construction, network, is_bridge, is_tunnel, is_ford, expressway, z_order
        ),
    roads_z8_merge AS (
        SELECT  id,
                osm_id,
                ST_LineMerge(
                    ST_Union(geometry)
                    ) AS geometry,
                highway,
                network,
                construction,
                is_bridge,
                is_tunnel,
                is_ford,
                expressway,
                z_order
    FROM roads_z8
    GROUP BY id, osm_id, highway, network, construction, is_bridge, is_tunnel, is_ford, expressway, z_order
    )

    SELECT  CASE
             WHEN ST_StartPoint(geometry) = ST_EndPoint(geometry) 
                 THEN ST_RemovePoint(geometry, ST_NPoints(geometry) - 1)
             ELSE geometry
            END AS geometry,  
            id,
            osm_id,
            highway,
            network,
            construction,
            -- Remove bridge/tunnel/ford attributes from short sections of road so they can be merged
            visible_brunnel(geometry, is_bridge, 8) AS is_bridge,
            visible_brunnel(geometry, is_tunnel, 8) AS is_tunnel,
            visible_brunnel(geometry, is_ford, 8) AS is_ford,
            expressway,
            z_order
    FROM roads_z8_merge
        -- Current view: motorway/trunk/primary
    WHERE
        (full_update IS TRUE OR EXISTS(
            SELECT NULL FROM transportation.changes_z4_z5_z6_z7
            WHERE transportation.changes_z4_z5_z6_z7.is_old IS FALSE AND
                  transportation.changes_z4_z5_z6_z7.id = roads_z8_merge.id
        )) AND
        (ST_Length(geometry) > 50)
    ON CONFLICT (id) DO UPDATE SET osm_id = excluded.osm_id, highway = excluded.highway, network = excluded.network,
                                   construction = excluded.construction, is_bridge = excluded.is_bridge,
                                   is_tunnel = excluded.is_tunnel, is_ford = excluded.is_ford,
                                   expressway = excluded.expressway, z_order = excluded.z_order;

    -- Analyze source table
    ANALYZE osm_transportation_merge_linestring_gen_z7;

    -- Remove entries which have been deleted from source table
    DELETE FROM osm_transportation_merge_linestring_gen_z6
    USING transportation.changes_z4_z5_z6_z7
    WHERE full_update IS TRUE OR (
        transportation.changes_z4_z5_z6_z7.is_old IS TRUE AND
        transportation.changes_z4_z5_z6_z7.id = osm_transportation_merge_linestring_gen_z6.id
    );

    -- etldoc: osm_transportation_merge_linestring_gen_z7 -> osm_transportation_merge_linestring_gen_z6
    INSERT INTO osm_transportation_merge_linestring_gen_z6
    SELECT ST_Simplify(geometry, ZRes(8)) AS geometry,
        id,
        osm_id,
        highway,
        network,
        construction,
        -- Remove bridge/tunnel/ford attributes from short sections of road so they can be merged
        visible_brunnel(geometry, is_bridge, 7) AS is_bridge,
        visible_brunnel(geometry, is_tunnel, 7) AS is_tunnel,
        visible_brunnel(geometry, is_ford, 7) AS is_ford,
        expressway,
        z_order
    FROM osm_transportation_merge_linestring_gen_z7
    -- Current view: motorway/trunk/primary
    WHERE
        (full_update IS TRUE OR EXISTS(
            SELECT NULL FROM transportation.changes_z4_z5_z6_z7
            WHERE transportation.changes_z4_z5_z6_z7.is_old IS FALSE AND
                  transportation.changes_z4_z5_z6_z7.id = osm_transportation_merge_linestring_gen_z7.id
        )) AND
        (highway IN ('motorway', 'trunk') OR construction IN ('motorway', 'trunk')) AND
        ST_Length(geometry) > 100
    ON CONFLICT (id) DO UPDATE SET osm_id = excluded.osm_id, highway = excluded.highway, network = excluded.network,
                                   construction = excluded.construction, is_bridge = excluded.is_bridge,
                                   is_tunnel = excluded.is_tunnel, is_ford = excluded.is_ford,
                                   expressway = excluded.expressway, z_order = excluded.z_order;

    -- Analyze source table
    ANALYZE osm_transportation_merge_linestring_gen_z6;

    -- Remove entries which have been deleted from source table
    DELETE FROM osm_transportation_merge_linestring_gen_z5
    USING transportation.changes_z4_z5_z6_z7
    WHERE full_update IS TRUE OR (
        transportation.changes_z4_z5_z6_z7.is_old IS TRUE AND
        transportation.changes_z4_z5_z6_z7.id = osm_transportation_merge_linestring_gen_z5.id
        );

    -- etldoc: osm_transportation_merge_linestring_gen_z6 -> osm_transportation_merge_linestring_gen_z5
    INSERT INTO osm_transportation_merge_linestring_gen_z5
    WITH normalized_z6 AS (
        -- Step 1: Upgrade only small trunk chunks to motorway for merging purposes
        SELECT ST_Simplify(geometry, ZRes(7)) AS geometry,
            id,
            osm_id,
            -- Only upgrade small trunk chunks to motorway
            CASE 
                WHEN highway = 'trunk' AND ST_Length(geometry) < 500 THEN 'motorway'
                ELSE highway 
            END AS highway,
            network,
            CASE 
                WHEN construction = 'trunk' AND ST_Length(geometry) < 500 THEN 'motorway'
                ELSE construction 
            END AS construction,
            -- Remove bridge/tunnel/ford attributes from short sections of road so they can be merged
            visible_brunnel(geometry, is_bridge, 6) AS is_bridge,
            visible_brunnel(geometry, is_tunnel, 6) AS is_tunnel,
            visible_brunnel(geometry, is_ford, 6) AS is_ford,
            expressway,
            z_order
        FROM osm_transportation_merge_linestring_gen_z6
        WHERE
            (full_update IS TRUE OR EXISTS(
                SELECT NULL FROM transportation.changes_z4_z5_z6_z7
                WHERE transportation.changes_z4_z5_z6_z7.is_old IS FALSE AND
                      transportation.changes_z4_z5_z6_z7.id = osm_transportation_merge_linestring_gen_z6.id
            )) AND
            -- Include all motorway and trunk roads for merging
            (highway IN ('motorway', 'trunk') OR construction IN ('motorway', 'trunk'))
    ),
    merged_z5 AS (
        -- Step 2: Merge normalized geometry using ST_LineMerge
        SELECT ST_LineMerge(ST_Union(geometry)) AS geometry,
            array_agg(id) AS source_ids,
            array_agg(osm_id) AS osm_ids,
            highway,
            network,
            construction,
            bool_or(is_bridge) AS is_bridge,
            bool_or(is_tunnel) AS is_tunnel,
            bool_or(is_ford) AS is_ford,
            bool_or(expressway) AS expressway,
            min(z_order) AS z_order
        FROM normalized_z6
        GROUP BY highway, network, construction, is_bridge, is_tunnel, is_ford, expressway
    )
    -- Step 3: Apply final length filtering after merge
    SELECT geometry,
        source_ids[1] AS id,
        osm_ids[1] AS osm_id,
        highway,
        network,
        construction,
        is_bridge,
        is_tunnel,
        is_ford,
        expressway,
        z_order
    FROM merged_z5
    WHERE ST_Length(geometry) > 500  -- Drop small chunks after merge
    ON CONFLICT (id) DO UPDATE SET osm_id = excluded.osm_id, highway = excluded.highway, network = excluded.network,
                                   construction = excluded.construction, is_bridge = excluded.is_bridge,
                                   is_tunnel = excluded.is_tunnel, is_ford = excluded.is_ford,
                                   expressway = excluded.expressway, z_order = excluded.z_order;

    -- Analyze source table
    ANALYZE osm_transportation_merge_linestring_gen_z5;

    -- Remove entries which have been deleted from source table
    DELETE FROM osm_transportation_merge_linestring_gen_z4
    USING transportation.changes_z4_z5_z6_z7
    WHERE full_update IS TRUE OR (
        transportation.changes_z4_z5_z6_z7.is_old IS TRUE AND
        transportation.changes_z4_z5_z6_z7.id = osm_transportation_merge_linestring_gen_z4.id
    );

    -- etldoc: osm_transportation_merge_linestring_gen_z5 -> osm_transportation_merge_linestring_gen_z4
    INSERT INTO osm_transportation_merge_linestring_gen_z4
    WITH normalized_z5 AS (
        -- Step 1: Upgrade only small trunk chunks to motorway for merging purposes
        SELECT ST_Simplify(geometry, ZRes(6)) AS geometry,
            id,
            osm_id,
            -- Only upgrade small trunk chunks to motorway
            CASE 
                WHEN highway = 'trunk' AND ST_Length(geometry) < 1000 THEN 'motorway'
                ELSE highway 
            END AS highway,
            network,
            CASE 
                WHEN construction = 'trunk' AND ST_Length(geometry) < 1000 THEN 'motorway'
                ELSE construction 
            END AS construction,
            visible_brunnel(geometry, is_bridge, 5) AS is_bridge,
            visible_brunnel(geometry, is_tunnel, 5) AS is_tunnel,
            visible_brunnel(geometry, is_ford, 5) AS is_ford,
            expressway,
            z_order
        FROM osm_transportation_merge_linestring_gen_z5
        WHERE
            (full_update IS TRUE OR EXISTS(
                SELECT NULL FROM transportation.changes_z4_z5_z6_z7
                WHERE transportation.changes_z4_z5_z6_z7.is_old IS FALSE AND
                      transportation.changes_z4_z5_z6_z7.id = osm_transportation_merge_linestring_gen_z5.id
            )) AND
            -- Include all motorway and trunk roads for merging
            (highway IN ('motorway', 'trunk') OR construction IN ('motorway', 'trunk'))
    ),
    merged_z4 AS (
        -- Step 2: Merge normalized geometry using ST_LineMerge
        SELECT ST_LineMerge(ST_Union(geometry)) AS geometry,
            array_agg(id) AS source_ids,
            array_agg(osm_id) AS osm_ids,
            highway,
            network,
            construction,
            bool_or(is_bridge) AS is_bridge,
            bool_or(is_tunnel) AS is_tunnel,
            bool_or(is_ford) AS is_ford,
            bool_or(expressway) AS expressway,
            min(z_order) AS z_order
        FROM normalized_z5
        GROUP BY highway, network, construction, is_bridge, is_tunnel, is_ford, expressway
    )
    -- Step 3: Apply final length filtering after merge
    SELECT geometry,
        source_ids[1] AS id,  -- Use first ID from merged group
        osm_ids[1] AS osm_id,  -- Use first OSM ID from merged group
        highway,
        network,
        construction,
        is_bridge,
        is_tunnel,
        is_ford,
        expressway,
        z_order
    FROM merged_z4
    WHERE ST_Length(geometry) > 1000  -- Drop small chunks after merge
    ON CONFLICT (id) DO UPDATE SET osm_id = excluded.osm_id, highway = excluded.highway, network = excluded.network,
                                   construction = excluded.construction, is_bridge = excluded.is_bridge,
                                   is_tunnel = excluded.is_tunnel, is_ford = excluded.is_ford,
                                   expressway = excluded.expressway, z_order = excluded.z_order;

    -- noinspection SqlWithoutWhere
    DELETE FROM transportation.changes_z4_z5_z6_z7;

    RAISE LOG 'Refresh transportation z4 z5 z6 z7 done in %', age(clock_timestamp(), t);
END;
$$ LANGUAGE plpgsql;

-- Ensure tables are emtpy if they haven't been created
TRUNCATE osm_transportation_merge_linestring_gen_z7;
TRUNCATE osm_transportation_merge_linestring_gen_z6;
TRUNCATE osm_transportation_merge_linestring_gen_z5;
TRUNCATE osm_transportation_merge_linestring_gen_z4;

SELECT insert_transportation_merge_linestring_gen_z7(TRUE);

-- Indexes for queries originating from insert_transportation_merge_linestring_gen_z7() function
CREATE UNIQUE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z7_update_partial_idx
    ON osm_transportation_merge_linestring_gen_z7 (id)
    WHERE (highway IN ('motorway', 'trunk') OR construction IN ('motorway', 'trunk')) AND
          ST_Length(geometry) > 100;
CREATE UNIQUE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z6_update_partial_idx
    ON osm_transportation_merge_linestring_gen_z6 (id)
    WHERE (highway = 'motorway'
            OR construction = 'motorway'
            OR (highway = 'trunk' AND osm_national_network(network))
        ) AND
        ST_Length(geometry) > 500;
CREATE UNIQUE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z5_update_partial_idx
    ON osm_transportation_merge_linestring_gen_z5 (id)
    WHERE osm_national_network(network) AND ST_Length(geometry) > 1000;

-- Geometry Indexes
CREATE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z7_geometry_idx
    ON osm_transportation_merge_linestring_gen_z7 USING gist (geometry);
CREATE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z6_geometry_idx
    ON osm_transportation_merge_linestring_gen_z6 USING gist (geometry);
CREATE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z5_geometry_idx
    ON osm_transportation_merge_linestring_gen_z5 USING gist (geometry);
CREATE INDEX IF NOT EXISTS osm_transportation_merge_linestring_gen_z4_geometry_idx
    ON osm_transportation_merge_linestring_gen_z4 USING gist (geometry);


-- Handle updates on
-- osm_highway_linestring_gen_z11 -> osm_transportation_merge_linestring_gen_z11
-- osm_transportation_merge_linestring_gen_z11 -> osm_transportation_merge_linestring_gen_z10
-- osm_transportation_merge_linestring_gen_z11 -> osm_transportation_merge_linestring_gen_z9
CREATE OR REPLACE AGGREGATE array_cat_agg(anycompatiblearray) (
  SFUNC=array_cat,
  STYPE=anycompatiblearray,
  INITCOND = '{}'
);

CREATE TABLE IF NOT EXISTS transportation.changes_z11
(
    is_old boolean NULL,
    osm_id bigint,
    PRIMARY KEY (is_old, osm_id)
);

-- Store IDs of changed elements from osm_highway_linestring_gen_z11 table.
CREATE OR REPLACE FUNCTION transportation.store_gen_z11() RETURNS trigger AS
$$
BEGIN
    IF (tg_op = 'INSERT' OR tg_op = 'UPDATE') THEN
        INSERT INTO transportation.changes_z11(is_old, osm_id)
        VALUES (FALSE, new.osm_id)
        ON CONFLICT (is_old, osm_id) DO NOTHING;
    END IF;
    IF (tg_op = 'DELETE' OR tg_op = 'UPDATE') THEN
        INSERT INTO transportation.changes_z11(is_old, osm_id)
        VALUES (TRUE, old.osm_id)
        ON CONFLICT (is_old, osm_id) DO NOTHING;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Store IDs of changed elements from osm_highway_linestring_gen_z9 table.
CREATE OR REPLACE FUNCTION transportation.store_merge_z11() RETURNS trigger AS
$$
BEGIN
    IF (tg_op = 'INSERT' OR tg_op = 'UPDATE') THEN
        INSERT INTO transportation.changes_z9_z10(is_old, id)
        VALUES (FALSE, new.id)
        ON CONFLICT (is_old, id) DO NOTHING;
    END IF;
    IF tg_op = 'DELETE' THEN
        INSERT INTO transportation.changes_z9_z10(is_old, id)
        VALUES (TRUE, old.id)
        ON CONFLICT (is_old, id) DO NOTHING;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS transportation.updates_z11
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION transportation.flag_z11() RETURNS trigger AS
$$
BEGIN
    INSERT INTO transportation.updates_z11(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transportation.refresh_z11() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh transportation z11';

    -- Analyze tracking and source tables before performing update
    ANALYZE transportation.changes_z11;
    ANALYZE osm_highway_linestring_gen_z11;

    -- Fetch updated and deleted Merged-LineString from relation-table filtering for each Merged-LineString which
    -- contains an updated Source-LineString.
    -- Additionally attach a list of Source-LineString-IDs to each Merged-LineString in order to unnest them later.
    CREATE TEMPORARY TABLE affected_merged_linestrings AS
    SELECT m.id, array_agg(source_id) AS source_ids
    FROM osm_transportation_merge_linestring_gen_z11_source_ids m
    WHERE EXISTS(
        SELECT NULL
        FROM transportation.changes_z11 c
        WHERE c.is_old IS TRUE AND c.osm_id = m.source_id
    )
    GROUP BY id;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE affected_merged_linestrings;

    -- Delete all Merged-LineStrings which contained an updated or deleted Source-LineString
    DELETE
    FROM osm_transportation_merge_linestring_gen_z11 m
    USING affected_merged_linestrings
    WHERE affected_merged_linestrings.id = m.id;
    DELETE
    FROM osm_transportation_merge_linestring_gen_z11_source_ids m
    USING affected_merged_linestrings
    WHERE affected_merged_linestrings.id = m.id;

    -- Analyze the tables affected by the delete-query in order to speed up subsequent queries
    ANALYZE osm_transportation_merge_linestring_gen_z11;
    ANALYZE osm_transportation_merge_linestring_gen_z11_source_ids;

    -- Create a table containing all LineStrings which should be merged
    CREATE TEMPORARY TABLE linestrings_to_merge AS
    -- Add all Source-LineStrings affected by this update
    SELECT osm_highway_linestring_gen_z11.osm_id, NULL::INTEGER AS id, NULL::BIGINT[] AS source_ids,
           geometry, highway, network, construction,
           visible_brunnel(geometry, is_bridge, 11) AS is_bridge,
           visible_brunnel(geometry, is_tunnel, 11) AS is_tunnel,
           visible_brunnel(geometry, is_ford, 11) AS is_ford,
           expressway, bicycle, foot, horse, mtb_scale, sac_scale, operator, informal,
           CASE WHEN access IN ('private', 'no') THEN 'no' ELSE NULL::text END AS access, toll,
           visible_layer(geometry, layer, 11) AS layer, z_order
    -- Table containing the IDs of all Source-LineStrings affected by this update
    FROM (
        -- Get Source-LineString-IDs of deleted or updated elements
        SELECT unnest(affected_merged_linestrings.source_ids)::bigint AS source_id FROM affected_merged_linestrings
        UNION
        -- Get Source-LineString-IDs of inserted or updated elements
        SELECT osm_id AS source_id FROM transportation.changes_z11 WHERE is_old IS FALSE
        ORDER BY source_id
    ) affected_source_linestrings
    JOIN osm_highway_linestring_gen_z11 ON (
        affected_source_linestrings.source_id = osm_highway_linestring_gen_z11.osm_id
    );

    -- Drop temporary tables early to save resources
    DROP TABLE affected_merged_linestrings;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE linestrings_to_merge;

    -- Add all Merged-LineStrings intersecting with Source-LineStrings affected by this update
    INSERT INTO linestrings_to_merge
    SELECT NULL::BIGINT AS osm_id, m.id,
           ARRAY(
               SELECT s.source_id FROM osm_transportation_merge_linestring_gen_z11_source_ids s WHERE s.id = m.id
           )::BIGINT[] AS source_ids, m.geometry, m.highway, m.network, m.construction,
           visible_brunnel(m.geometry, m.is_bridge, 11) AS is_bridge,
           visible_brunnel(m.geometry, m.is_tunnel, 11) AS is_tunnel,
           visible_brunnel(m.geometry, m.is_ford, 11) AS is_ford,
           m.expressway, m.bicycle, m.foot, m.horse, m.mtb_scale, m.sac_scale,
           m.operator, m.informal, m.access, m.toll,
           visible_layer(m.geometry, m.layer, 11) AS layer, m.z_order
    FROM linestrings_to_merge
    JOIN osm_transportation_merge_linestring_gen_z11 m ON (ST_Intersects(linestrings_to_merge.geometry, m.geometry));

    -- Analyze the created table to speed up subsequent queries
    ANALYZE linestrings_to_merge;

    -- Delete all Merged-LineStrings intersecting with Source-LineStrings affected by this update.
    -- We can use the linestrings_to_merge table since Source-LineStrings affected by this update and present in the
    -- table will have their ID-Column set to NULL by the previous query.
    DELETE
    FROM osm_transportation_merge_linestring_gen_z11 m
    USING linestrings_to_merge
    WHERE m.id = linestrings_to_merge.id;
    DELETE
    FROM osm_transportation_merge_linestring_gen_z11_source_ids m
    USING linestrings_to_merge
    WHERE linestrings_to_merge.id = m.id;

    -- Create table containing all LineStrings to and create clusters of intersecting LineStrings partitioned by their
    -- groups
    CREATE TEMPORARY TABLE clustered_linestrings_to_merge AS
    SELECT *,
           -- Get intersecting clusters by setting minimum distance to 0 and minimum intersecting points to 1
           -- https://postgis.net/docs/ST_ClusterDBSCAN.html
           ST_ClusterDBSCAN(geometry, 0, 1) OVER (
               PARTITION BY highway, network, construction, is_bridge, is_tunnel, is_ford, expressway, bicycle, foot,
               horse, mtb_scale, sac_scale, operator, informal, access, toll, layer
           ) AS cluster,
           -- ST_ClusterDBSCAN returns an increasing integer as the cluster-ids within each partition starting at 0.
           -- This leads to clusters having the same ID across multiple partitions therefore we generate a
           -- Cluster-Group-ID by utilizing the DENSE_RANK function sorted over the partition columns.
           DENSE_RANK() OVER (
               ORDER BY highway, network, construction, is_bridge, is_tunnel, is_ford, expressway, bicycle, foot, horse,
               mtb_scale, sac_scale, operator, informal, access, toll, layer
           ) as cluster_group
    FROM linestrings_to_merge;

    -- Drop temporary tables early to save resources
    DROP TABLE linestrings_to_merge;

    -- Create index on cluster columns and analyze the created table to speed up subsequent queries
    CREATE INDEX ON clustered_linestrings_to_merge (cluster_group, cluster);
    ANALYZE clustered_linestrings_to_merge;

    WITH inserted_linestrings AS (
        -- Merge LineStrings of each cluster and insert them
        INSERT INTO osm_transportation_merge_linestring_gen_z11(geometry, new_source_ids, old_source_ids, highway,
                                                                network, construction, is_bridge, is_tunnel, is_ford,
                                                                expressway, z_order, bicycle, foot, horse, mtb_scale,
                                                                sac_scale, operator, informal, access, toll, layer)
        SELECT (ST_Dump(ST_LineMerge(ST_Union(geometry)))).geom AS geometry,
               -- We use St_Union instead of St_Collect to ensure no overlapping points exist within the geometries to
               -- merge. https://postgis.net/docs/ST_Union.html
               -- ST_LineMerge only merges across singular intersections and groups its output into a MultiLineString if
               -- more than two LineStrings form an intersection or no intersection could be found.
               -- https://postgis.net/docs/ST_LineMerge.html
               -- In order to not end up with a mixture of LineStrings and MultiLineStrings we dump eventual
               -- MultiLineStrings via ST_Dump. https://postgis.net/docs/ST_Dump.html
               coalesce( array_agg(osm_id) FILTER (WHERE osm_id IS NOT NULL), '{}' )::BIGINT[] AS new_source_ids,
               array_cat_agg(source_ids)::BIGINT[] AS old_source_ids,
               highway,
               network,
               construction,
               is_bridge,
               is_tunnel,
               is_ford,
               expressway,
               min(z_order) as z_order,
               bicycle,
               foot,
               horse,
               mtb_scale,
               sac_scale,
               operator,
               informal,
               access,
               toll,
               layer
        FROM clustered_linestrings_to_merge
        GROUP BY cluster_group, cluster, highway, network, construction, is_bridge, is_tunnel, is_ford, expressway,
                 bicycle, foot, horse, mtb_scale, sac_scale, operator, informal, access, toll, layer
        RETURNING id, new_source_ids, old_source_ids, geometry
    )
    -- Store OSM-IDs of Source-LineStrings by intersecting Merged-LineStrings with their sources.
    -- This is required because ST_LineMerge only merges across singular intersections and groups its output into a
    -- MultiLineString if more than two LineStrings form an intersection or no intersection could be found.
    INSERT INTO osm_transportation_merge_linestring_gen_z11_source_ids (id, source_id)
    SELECT m.id, source_id
    FROM (
        SELECT id, source_id, geometry
        FROM inserted_linestrings
        CROSS JOIN LATERAL (
            SELECT DISTINCT all_source_ids.source_id
            FROM unnest(
                array_cat(inserted_linestrings.new_source_ids, inserted_linestrings.old_source_ids)
            ) AS all_source_ids(source_id)
        ) source_ids
    ) m
    JOIN osm_highway_linestring_gen_z11 s ON (m.source_id = s.osm_id)
    WHERE ST_Intersects(s.geometry, m.geometry)
    ON CONFLICT (id, source_id) DO NOTHING;

    -- Cleanup remaining table
    DROP TABLE clustered_linestrings_to_merge;

    -- Restore temporary Merged-LineString to Source-LineStrings-ID columns
    UPDATE osm_transportation_merge_linestring_gen_z11 SET new_source_ids = NULL WHERE new_source_ids IS NOT NULL;
    UPDATE osm_transportation_merge_linestring_gen_z11 SET old_source_ids = NULL WHERE old_source_ids IS NOT NULL;

    -- noinspection SqlWithoutWhere
    DELETE FROM transportation.changes_z11;
    -- noinspection SqlWithoutWhere
    DELETE FROM transportation.updates_z11;

    RAISE LOG 'Refresh transportation z11 done in %', age(clock_timestamp(), t);

    -- Update z10 and z9 tables
    PERFORM insert_transportation_merge_linestring_gen_z10(FALSE);

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store_transportation_highway_linestring_gen_z11
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_highway_linestring_gen_z11
    FOR EACH ROW
EXECUTE PROCEDURE transportation.store_gen_z11();

CREATE TRIGGER trigger_store_osm_transportation_merge_linestring_gen_z11
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_transportation_merge_linestring_gen_z11
    FOR EACH ROW
EXECUTE PROCEDURE transportation.store_merge_z11();

CREATE TRIGGER trigger_flag_transportation_z11
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_highway_linestring_gen_z11
    FOR EACH STATEMENT
EXECUTE PROCEDURE transportation.flag_z11();

CREATE CONSTRAINT TRIGGER trigger_refresh_z11
    AFTER INSERT
    ON transportation.updates_z11
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE transportation.refresh_z11();


-- Handle updates on
-- osm_transportation_merge_linestring_gen_z9 -> osm_transportation_merge_linestring_gen_z8
-- osm_transportation_merge_linestring_gen_z8 -> osm_transportation_merge_linestring_gen_z7
-- osm_transportation_merge_linestring_gen_z8 -> osm_transportation_merge_linestring_gen_z6
-- osm_transportation_merge_linestring_gen_z8 -> osm_transportation_merge_linestring_gen_z5
-- osm_transportation_merge_linestring_gen_z8 -> osm_transportation_merge_linestring_gen_z4

CREATE TABLE IF NOT EXISTS transportation.changes_z9
(
    is_old boolean,
    id bigint,
    PRIMARY KEY (is_old, id)
);

-- Store IDs of changed elements from osm_highway_linestring_gen_z9 table.
CREATE OR REPLACE FUNCTION transportation.store_z9() RETURNS trigger AS
$$
BEGIN
    IF (tg_op = 'INSERT' OR tg_op = 'UPDATE') THEN
        INSERT INTO transportation.changes_z9(is_old, id)
        VALUES (FALSE, new.id)
        ON CONFLICT (is_old, id) DO NOTHING;
    END IF;
    IF (tg_op = 'DELETE' OR tg_op = 'UPDATE') THEN
        INSERT INTO transportation.changes_z9(is_old, id)
        VALUES (TRUE, old.id)
        ON CONFLICT (is_old, id) DO NOTHING;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Store IDs of changed elements from osm_highway_linestring_gen_z8 table.
CREATE OR REPLACE FUNCTION transportation.store_z8() RETURNS trigger AS
$$
BEGIN
    IF (tg_op = 'INSERT' OR tg_op = 'UPDATE') THEN
        INSERT INTO transportation.changes_z4_z5_z6_z7(is_old, id)
        VALUES (FALSE, new.id)
        ON CONFLICT (is_old, id) DO NOTHING;
    END IF;
    IF tg_op = 'DELETE' THEN
        INSERT INTO transportation.changes_z4_z5_z6_z7(is_old, id)
        VALUES (TRUE, old.id)
        ON CONFLICT (is_old, id) DO NOTHING;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS transportation.updates_z9
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION transportation.flag_z9() RETURNS trigger AS
$$
BEGIN
    INSERT INTO transportation.updates_z9(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transportation.refresh_z8() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh transportation z8';

    -- Analyze tracking and source tables before performing update
    ANALYZE transportation.changes_z9;
    ANALYZE osm_transportation_merge_linestring_gen_z9;

    -- Fetch updated and deleted Merged-LineString from relation-table filtering for each Merged-LineString which
    -- contains an updated Source-LineString.
    -- Additionally attach a list of Source-LineString-IDs to each Merged-LineString in order to unnest them later.
    CREATE TEMPORARY TABLE affected_merged_linestrings AS
    SELECT m.id, array_agg(source_id) AS source_ids
    FROM osm_transportation_merge_linestring_gen_z8_source_ids m
    WHERE EXISTS(
        SELECT NULL
        FROM transportation.changes_z9 c
        WHERE c.is_old IS TRUE AND c.id = m.source_id
    )
    GROUP BY id;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE affected_merged_linestrings;

    -- Delete all Merged-LineStrings which contained an updated or deleted Source-LineString
    DELETE
    FROM osm_transportation_merge_linestring_gen_z8 m
    USING affected_merged_linestrings
    WHERE affected_merged_linestrings.id = m.id;
    DELETE
    FROM osm_transportation_merge_linestring_gen_z8_source_ids m
    USING affected_merged_linestrings
    WHERE affected_merged_linestrings.id = m.id;

    -- Analyze the tables affected by the delete-query in order to speed up subsequent queries
    ANALYZE osm_transportation_merge_linestring_gen_z8;
    ANALYZE osm_transportation_merge_linestring_gen_z8_source_ids;

    -- Create a table containing all LineStrings which should be merged
    CREATE TEMPORARY TABLE linestrings_to_merge AS
    -- Add all Source-LineStrings affected by this update
    SELECT id AS source_id, NULL::INT AS id, NULL::INT[] AS source_ids, geometry, highway, network, construction,
           visible_brunnel(geometry, is_bridge, 9) AS is_bridge,
           visible_brunnel(geometry, is_tunnel, 9) AS is_tunnel,
           visible_brunnel(geometry, is_ford, 9) AS is_ford, expressway, z_order
    -- Create a table containing the IDs of all Source-LineStrings affected by this update
    FROM (
        -- Get Source-LineString-IDs of deleted or updated elements
        SELECT unnest(affected_merged_linestrings.source_ids)::bigint AS source_id FROM affected_merged_linestrings
        UNION
        -- Get Source-LineString-IDs of inserted or updated elements
        SELECT id AS source_id FROM transportation.changes_z9 WHERE transportation.changes_z9.is_old IS FALSE
        ORDER BY source_id
    ) affected_source_linestrings
    JOIN osm_transportation_merge_linestring_gen_z9 ON (
        affected_source_linestrings.source_id = osm_transportation_merge_linestring_gen_z9.id
    )
    WHERE (
        highway IN ('motorway', 'trunk', 'primary') OR
        construction IN ('motorway', 'trunk', 'primary')
    ) AND
    ST_IsValid(geometry) AND
    access IS NULL;

    -- Drop temporary tables early to save resources
    DROP TABLE affected_merged_linestrings;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE linestrings_to_merge;

    -- Add all Merged-LineStrings intersecting with Source-LineStrings affected by this update
    INSERT INTO linestrings_to_merge
    SELECT NULL::INT AS source_id, m.id,
           ARRAY(
               SELECT s.source_id FROM osm_transportation_merge_linestring_gen_z8_source_ids s WHERE s.id = m.id
           )::INT[] AS source_ids, m.geometry, m.highway, m.network, m.construction,
           visible_brunnel(m.geometry, m.is_bridge, 9) AS is_bridge,
           visible_brunnel(m.geometry, m.is_tunnel, 9) AS is_tunnel,
           visible_brunnel(m.geometry, m.is_ford, 9) AS is_ford, m.expressway, m.z_order
    FROM linestrings_to_merge
    JOIN osm_transportation_merge_linestring_gen_z8 m ON (ST_Intersects(linestrings_to_merge.geometry, m.geometry));

    -- Analyze the created table to speed up subsequent queries
    ANALYZE linestrings_to_merge;

    -- Delete all Merged-LineStrings intersecting with Source-LineStrings affected by this update.
    -- We can use the linestrings_to_merge table since Source-LineStrings affected by this update and present in the
    -- table will have their ID-Column set to NULL by the previous query.
    DELETE
    FROM osm_transportation_merge_linestring_gen_z8 m
    USING linestrings_to_merge
    WHERE m.id = linestrings_to_merge.id;
    DELETE
    FROM osm_transportation_merge_linestring_gen_z8_source_ids m
    USING linestrings_to_merge
    WHERE m.id = linestrings_to_merge.id;

    -- Create table containing all LineStrings to and create clusters of intersecting LineStrings partitioned by their
    -- groups
    CREATE TEMPORARY TABLE clustered_linestrings_to_merge AS
    SELECT *,
           -- Get intersecting clusters by setting minimum distance to 0 and minimum intersecting points to 1
           -- https://postgis.net/docs/ST_ClusterDBSCAN.html
           ST_ClusterDBSCAN(geometry, 0, 1) OVER (
               PARTITION BY highway, network, construction, is_bridge, is_tunnel, is_ford, expressway
           ) AS cluster,
           -- ST_ClusterDBSCAN returns an increasing integer as the cluster-ids within each partition starting at 0.
           -- This leads to clusters having the same ID across multiple partitions therefore we generate a
           -- Cluster-Group-ID by utilizing the DENSE_RANK function sorted over the partition columns.
           DENSE_RANK() OVER (
               ORDER BY highway, network, construction, is_bridge, is_tunnel, is_ford, expressway
           ) as cluster_group
    FROM linestrings_to_merge;

    -- Drop temporary tables early to save resources
    DROP TABLE linestrings_to_merge;

    -- Create index on cluster columns and analyze the created table to speed up subsequent queries
    CREATE INDEX ON clustered_linestrings_to_merge (cluster_group, cluster);
    ANALYZE clustered_linestrings_to_merge;

    -- Create temporary Merged-LineString to Source-LineStrings-ID columns to store relations before they have been
    -- intersected
    WITH inserted_linestrings AS (
        -- Merge LineStrings of each cluster and insert them
        INSERT INTO osm_transportation_merge_linestring_gen_z8(geometry, new_source_ids, old_source_ids, highway,
                                                               network, construction, is_bridge, is_tunnel, is_ford,
                                                               expressway, z_order)
        SELECT (ST_Dump(ST_Simplify(ST_LineMerge(ST_Union(geometry)), ZRes(10)))).geom AS geometry,
               -- We use St_Union instead of St_Collect to ensure no overlapping points exist within the geometries to
               -- merge. https://postgis.net/docs/ST_Union.html
               -- ST_LineMerge only merges across singular intersections and groups its output into a MultiLineString if
               -- more than two LineStrings form an intersection or no intersection could be found.
               -- https://postgis.net/docs/ST_LineMerge.html
               -- In order to not end up with a mixture of LineStrings and MultiLineStrings we dump eventual
               -- MultiLineStrings via ST_Dump. https://postgis.net/docs/ST_Dump.html
            coalesce( array_agg(source_id) FILTER (WHERE source_id IS NOT NULL), '{}' )::INT[] AS new_source_ids,
            array_cat_agg(source_ids)::INT[] as old_source_ids,
            highway,
            network,
            construction,
            is_bridge,
            is_tunnel,
            is_ford,
            expressway,
            min(z_order) as z_order
        FROM clustered_linestrings_to_merge
        GROUP BY cluster_group, cluster, highway, network, construction, is_bridge, is_tunnel, is_ford, expressway
        RETURNING id, new_source_ids, old_source_ids, geometry
    )
    -- Store OSM-IDs of Source-LineStrings by intersecting Merged-LineStrings with their sources. This required because
    -- ST_LineMerge only merges across singular intersections and groups its output into a MultiLineString if
    -- more than two LineStrings form an intersection or no intersection could be found.
    INSERT INTO osm_transportation_merge_linestring_gen_z8_source_ids (id, source_id)
    SELECT m.id, m.source_id
    FROM (
        SELECT id, source_id, geometry
        FROM inserted_linestrings
        CROSS JOIN LATERAL (
            SELECT DISTINCT all_source_ids.source_id
            FROM unnest(
                array_cat(inserted_linestrings.new_source_ids, inserted_linestrings.old_source_ids)
            ) AS all_source_ids(source_id)
        ) source_ids
    ) m
    JOIN osm_transportation_merge_linestring_gen_z9 s ON (m.source_id = s.id)
    WHERE ST_Intersects(s.geometry, m.geometry)
    ON CONFLICT (id, source_id) DO NOTHING;

    -- Cleanup
    DROP TABLE clustered_linestrings_to_merge;

    -- Restore temporary Merged-LineString to Source-LineStrings-ID columns

    UPDATE osm_transportation_merge_linestring_gen_z8 SET new_source_ids = NULL WHERE new_source_ids IS NOT NULL;
    UPDATE osm_transportation_merge_linestring_gen_z8 SET old_source_ids = NULL WHERE old_source_ids IS NOT NULL;
    -- noinspection SqlWithoutWhere
    DELETE FROM transportation.changes_z9;
    -- noinspection SqlWithoutWhere
    DELETE FROM transportation.updates_z9;

    RAISE LOG 'Refresh transportation z8 done in %', age(clock_timestamp(), t);

    -- Update z7, z6, z5 and z4 tables
    PERFORM insert_transportation_merge_linestring_gen_z7(FALSE);

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store_transportation_highway_linestring_gen_z9
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_transportation_merge_linestring_gen_z9
    FOR EACH ROW
EXECUTE PROCEDURE transportation.store_z9();

CREATE TRIGGER trigger_store_osm_transportation_merge_linestring_gen_z8
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_transportation_merge_linestring_gen_z8
    FOR EACH ROW
EXECUTE PROCEDURE transportation.store_z8();

CREATE TRIGGER trigger_flag_transportation_z9
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_transportation_merge_linestring_gen_z9
    FOR EACH STATEMENT
EXECUTE PROCEDURE transportation.flag_z9();

CREATE CONSTRAINT TRIGGER trigger_refresh_z8
    AFTER INSERT
    ON transportation.updates_z9
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE transportation.refresh_z8();

-- Layer transportation - ./transportation.sql

CREATE OR REPLACE FUNCTION highway_is_link(highway text) RETURNS boolean AS
$$
SELECT highway LIKE '%_link';
$$ LANGUAGE SQL IMMUTABLE
                STRICT
                PARALLEL SAFE;


-- etldoc: layer_transportation[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="<sql> layer_transportation |<z4> z4 |<z5> z5 |<z6> z6 |<z7> z7 |<z8> z8 |<z9> z9 |<z10> z10 |<z11> z11 |<z12> z12|<z13> z13|<z14_> z14+" ] ;
CREATE OR REPLACE FUNCTION layer_transportation(bbox geometry, zoom_level int)
    RETURNS TABLE
            (
                osm_id     bigint,
                geometry   geometry,
                class      text,
                subclass   text,
                network    text,
                ramp       int,
                oneway     int,
                brunnel    text,
                service    text,
                access     text,
                toll       int,
                expressway int,
                layer      int,
                level      int,
                indoor     int,
                bicycle    text,
                foot       text,
                horse      text,
                mtb_scale  text,
                official   int,
                surface    text
            )
AS
$$
SELECT osm_id,
       geometry,
       CASE
           WHEN highway <> '' OR public_transport <> ''
               THEN highway_class(highway, public_transport, construction)
           WHEN railway <> '' THEN railway_class(railway)
           WHEN aerialway <> '' THEN 'aerialway'
           WHEN shipway <> '' THEN shipway
           WHEN man_made <> '' THEN man_made
           END AS class,
       CASE
           WHEN railway IS NOT NULL THEN railway
           WHEN (highway IS NOT NULL OR public_transport IS NOT NULL)
               AND highway_class(highway, public_transport, construction) = 'path'
               THEN COALESCE(NULLIF(public_transport, ''), highway)
           WHEN aerialway IS NOT NULL THEN aerialway
           END AS subclass,
       NULLIF(network, '') AS network,
       -- All links are considered as ramps as well
       CASE
           WHEN highway_is_link(highway)
             OR is_ramp
               THEN 1 END AS ramp,
       CASE WHEN is_oneway <> 0 THEN is_oneway::int END AS oneway,
       brunnel(is_bridge, is_tunnel, is_ford) AS brunnel,
       NULLIF(service, '') AS service,
       access,
       CASE WHEN toll = TRUE THEN 1 END AS toll,
       CASE WHEN highway NOT IN ('', 'motorway') AND NOT is_ramp AND expressway = TRUE THEN 1 END AS expressway,
       NULLIF(layer, 0) AS layer,
       "level",
       CASE WHEN indoor = TRUE THEN 1 END AS indoor,
       NULLIF(bicycle, '') AS bicycle,
       NULLIF(foot, '') AS foot,
       NULLIF(horse, '') AS horse,
       NULLIF(mtb_scale, '') AS mtb_scale,
       CASE WHEN highway IN ('path', 'footway', 'cycleway', 'bridleway')
            THEN
                CASE WHEN informal = 'yes' THEN 0
                     WHEN informal = 'no' OR operator != '' THEN 1
                     ELSE NULL
                END
            ELSE NULL
       END AS official,
       NULLIF(surface, '') AS surface
FROM (
         -- etldoc: osm_transportation_merge_linestring_gen_z4 -> layer_transportation:z4
         SELECT osm_id,
                geometry,
                highway,
                construction,
                network,
                NULL AS railway,
                NULL AS aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                NULL AS service,
                NULL AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                NULL::boolean AS is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                NULL::int AS layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_transportation_merge_linestring_gen_z4
         WHERE zoom_level = 4
         UNION ALL

         -- etldoc: osm_transportation_merge_linestring_gen_z5 -> layer_transportation:z5
         SELECT osm_id,
                geometry,
                highway,
                construction,
                network,
                NULL AS railway,
                NULL AS aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                NULL AS service,
                NULL AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                NULL::boolean AS is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                NULL::int AS layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_transportation_merge_linestring_gen_z5
         WHERE zoom_level = 5
         UNION ALL

         -- etldoc: osm_transportation_merge_linestring_gen_z6 -> layer_transportation:z6
         SELECT osm_id,
                geometry,
                highway,
                construction,
                network,
                NULL AS railway,
                NULL AS aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                NULL AS service,
                NULL AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                NULL::boolean AS is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                NULL::int AS layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_transportation_merge_linestring_gen_z6
         WHERE zoom_level = 6
         UNION ALL

         -- etldoc: osm_transportation_merge_linestring_gen_z7  ->  layer_transportation:z7
         SELECT osm_id,
                geometry,
                highway,
                construction,
                network,
                NULL AS railway,
                NULL AS aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                NULL AS service,
                NULL AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                expressway,
                NULL::boolean AS is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                NULL::int AS layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_transportation_merge_linestring_gen_z7
         WHERE zoom_level = 7
         UNION ALL

         -- etldoc: osm_transportation_merge_linestring_gen_z8  ->  layer_transportation:z8
         SELECT osm_id,
                geometry,
                highway,
                construction,
                network,
                NULL AS railway,
                NULL AS aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                NULL AS service,
                NULL AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                expressway,
                NULL::boolean AS is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                NULL::int AS layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_transportation_merge_linestring_gen_z8
         WHERE zoom_level = 8
         UNION ALL

         -- etldoc: osm_transportation_merge_linestring_gen_z9  ->  layer_transportation:z9
         SELECT osm_id,
                geometry,
                highway,
                construction,
                network,
                NULL AS railway,
                NULL AS aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                NULL AS service,
                access,
                toll,
                is_bridge,
                is_tunnel,
                is_ford,
                expressway,
                NULL::boolean AS is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                bicycle,
                foot,
                horse,
                mtb_scale,
                operator,
                informal,
                NULL AS surface,
                z_order
         FROM osm_transportation_merge_linestring_gen_z9
         WHERE zoom_level = 9
         UNION ALL

         -- etldoc: osm_transportation_merge_linestring_gen_z10  ->  layer_transportation:z10
         SELECT osm_id,
                geometry,
                highway,
                construction,
                network,
                NULL AS railway,
                NULL AS aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                NULL AS service,
                access,
                toll,
                is_bridge,
                is_tunnel,
                is_ford,
                expressway,
                NULL::boolean AS is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                bicycle,
                foot,
                horse,
                mtb_scale,
                operator,
                informal,
                NULL AS surface,
                z_order
         FROM osm_transportation_merge_linestring_gen_z10
         WHERE zoom_level = 10
         UNION ALL

         -- etldoc: osm_transportation_merge_linestring_gen_z11  ->  layer_transportation:z11
         SELECT osm_id,
                geometry,
                highway,
                construction,
                network,
                NULL AS railway,
                NULL AS aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                NULL AS service,
                access,
                toll,
                is_bridge,
                is_tunnel,
                is_ford,
                expressway,
                NULL::boolean AS is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                bicycle,
                foot,
                horse,
                mtb_scale,
                operator,
                informal,
                NULL AS surface,
                z_order
         FROM osm_transportation_merge_linestring_gen_z11
         WHERE zoom_level = 11
         UNION ALL

         -- etldoc: osm_highway_linestring  ->  layer_transportation:z12
         -- etldoc: osm_highway_linestring  ->  layer_transportation:z13
         -- etldoc: osm_highway_linestring  ->  layer_transportation:z14_
         -- etldoc: osm_transportation_name_network  ->  layer_transportation:z12
         -- etldoc: osm_transportation_name_network  ->  layer_transportation:z13
         -- etldoc: osm_transportation_name_network  ->  layer_transportation:z14_
         SELECT hl.osm_id,
                hl.geometry,
                hl.highway,
                construction,
                network,
                NULL AS railway,
                NULL AS aerialway,
                NULL AS shipway,
                public_transport,
                service_value(service) AS service,
                CASE WHEN access IN ('private', 'no') THEN 'no' END AS access,
                toll,
                is_bridge,
                is_tunnel,
                is_ford,
                expressway,
                is_ramp,
                is_oneway,
                man_made,
                hl.layer,
                CASE WHEN hl.highway IN ('footway', 'steps') THEN hl.level END AS level,
                CASE WHEN hl.highway IN ('footway', 'steps') THEN hl.indoor END AS indoor,
                bicycle,
                foot,
                horse,
                mtb_scale,
                hl.operator,
                hl.informal,
                surface_value(COALESCE(NULLIF(surface, ''), tracktype)) AS "surface",
                hl.z_order
         FROM osm_highway_linestring hl
         LEFT OUTER JOIN osm_transportation_name_network n ON hl.osm_id = n.osm_id
         WHERE zoom_level > 11 AND NOT is_area
           AND
               CASE WHEN zoom_level = 12 THEN
                         CASE WHEN transportation_filter_z12(hl.highway, hl.construction) THEN TRUE
                              WHEN hl.highway IN ('track', 'path') THEN n.route_rank = 1
                         END
                    WHEN zoom_level = 13 THEN
                         CASE WHEN man_made='pier' THEN NOT ST_IsClosed(hl.geometry)
                              WHEN hl.highway IN ('track', 'path') THEN (hl.name <> ''
                                                                   OR n.route_rank BETWEEN 1 AND 2
                                                                   OR hl.sac_scale <> ''
                                                                   )
                              ELSE transportation_filter_z13(hl.highway, public_transport, hl.construction, service)
                         END
                    WHEN zoom_level >= 14 THEN
                         CASE WHEN man_made='pier' THEN NOT ST_IsClosed(hl.geometry)
                              ELSE TRUE
                         END
               END
         UNION ALL

         -- etldoc: osm_railway_linestring_gen_z8  ->  layer_transportation:z8
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                railway,
                NULL AS aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                NULL::boolean AS is_bridge,
                NULL::boolean AS is_tunnel,
                NULL::boolean AS is_ford,
                NULL::boolean AS expressway,
                NULL::boolean AS is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                NULL::int AS layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_railway_linestring_gen_z8
         WHERE zoom_level = 8
           AND railway = 'rail'
           AND service = ''
           AND usage = 'main'
         UNION ALL

         -- etldoc: osm_railway_linestring_gen_z9  ->  layer_transportation:z9
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                railway,
                NULL AS aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                NULL::boolean AS is_bridge,
                NULL::boolean AS is_tunnel,
                NULL::boolean AS is_ford,
                NULL::boolean AS expressway,
                NULL::boolean AS is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_railway_linestring_gen_z9
         WHERE zoom_level = 9
           AND railway = 'rail'
           AND service = ''
           AND usage = 'main'
         UNION ALL

         -- etldoc: osm_railway_linestring_gen_z10  ->  layer_transportation:z10
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                railway,
                NULL AS aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_railway_linestring_gen_z10
         WHERE zoom_level = 10
           AND railway IN ('rail', 'narrow_gauge')
           AND service = ''
         UNION ALL

         -- etldoc: osm_railway_linestring_gen_z11  ->  layer_transportation:z11
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                railway,
                NULL AS aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_railway_linestring_gen_z11
         WHERE zoom_level = 11
           AND railway IN ('rail', 'narrow_gauge', 'light_rail')
           AND service = ''
         UNION ALL

         -- etldoc: osm_railway_linestring_gen_z12  ->  layer_transportation:z12
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                railway,
                NULL AS aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_railway_linestring_gen_z12
         WHERE zoom_level = 12
           AND railway IN ('rail', 'narrow_gauge', 'light_rail')
           AND service = ''
         UNION ALL

         -- etldoc: osm_railway_linestring ->  layer_transportation:z13
         -- etldoc: osm_railway_linestring ->  layer_transportation:z14_
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                railway,
                NULL AS aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_railway_linestring
         WHERE zoom_level = 13
           AND railway IN ('rail', 'narrow_gauge', 'light_rail')
           AND service = ''
           OR zoom_level >= 14
         UNION ALL

         -- etldoc: osm_aerialway_linestring_gen_z12  ->  layer_transportation:z12
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                NULL AS railway,
                aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_aerialway_linestring_gen_z12
         WHERE zoom_level = 12
         UNION ALL

         -- etldoc: osm_aerialway_linestring ->  layer_transportation:z13
         -- etldoc: osm_aerialway_linestring ->  layer_transportation:z14_
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                NULL AS railway,
                aerialway,
                NULL AS shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_aerialway_linestring
         WHERE zoom_level >= 13
         UNION ALL

         -- etldoc: osm_shipway_linestring_gen_z4  ->  layer_transportation:z4
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                NULL AS railway,
                NULL AS aerialway,
                shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_shipway_linestring_gen_z4
         WHERE zoom_level = 4
         UNION ALL

         -- etldoc: osm_shipway_linestring_gen_z5  ->  layer_transportation:z5
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                NULL AS railway,
                NULL AS aerialway,
                shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_shipway_linestring_gen_z5
         WHERE zoom_level = 5
         UNION ALL

         -- etldoc: osm_shipway_linestring_gen_z6  ->  layer_transportation:z6
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                NULL AS railway,
                NULL AS aerialway,
                shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_shipway_linestring_gen_z6
         WHERE zoom_level = 6
         UNION ALL

         -- etldoc: osm_shipway_linestring_gen_z7  ->  layer_transportation:z7
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                NULL AS railway,
                NULL AS aerialway,
                shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_shipway_linestring_gen_z7
         WHERE zoom_level = 7
         UNION ALL

         -- etldoc: osm_shipway_linestring_gen_z8  ->  layer_transportation:z8
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                NULL AS railway,
                NULL AS aerialway,
                shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_shipway_linestring_gen_z8
         WHERE zoom_level = 8
         UNION ALL

         -- etldoc: osm_shipway_linestring_gen_z9  ->  layer_transportation:z9
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                NULL AS railway,
                NULL AS aerialway,
                shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_shipway_linestring_gen_z9
         WHERE zoom_level = 9
         UNION ALL

         -- etldoc: osm_shipway_linestring_gen_z10  ->  layer_transportation:z10
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                NULL AS railway,
                NULL AS aerialway,
                shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_shipway_linestring_gen_z10
         WHERE zoom_level = 10
         UNION ALL

         -- etldoc: osm_shipway_linestring_gen_z11  ->  layer_transportation:z11
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                NULL AS railway,
                NULL AS aerialway,
                shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_shipway_linestring_gen_z11
         WHERE zoom_level = 11
         UNION ALL

         -- etldoc: osm_shipway_linestring_gen_z12  ->  layer_transportation:z12
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                NULL AS railway,
                NULL AS aerialway,
                shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_shipway_linestring_gen_z12
         WHERE zoom_level = 12
         UNION ALL

         -- etldoc: osm_shipway_linestring ->  layer_transportation:z13
         -- etldoc: osm_shipway_linestring ->  layer_transportation:z14_
         SELECT osm_id,
                geometry,
                NULL AS highway,
                NULL AS construction,
                NULL AS network,
                NULL AS railway,
                NULL AS aerialway,
                shipway,
                NULL AS public_transport,
                service_value(service) AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                is_bridge,
                is_tunnel,
                is_ford,
                NULL::boolean AS expressway,
                is_ramp,
                NULL::int AS is_oneway,
                NULL AS man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_shipway_linestring
         WHERE zoom_level >= 13
         UNION ALL

         -- NOTE: We limit the selection of polys because we need to be
         -- careful to net get false positives here because
         -- it is possible that closed linestrings appear both as
         -- highway linestrings and as polygon
         -- etldoc: osm_highway_polygon ->  layer_transportation:z13
         -- etldoc: osm_highway_polygon ->  layer_transportation:z14_
         SELECT osm_id,
                geometry,
                highway,
                NULL AS construction,
                NULL AS network,
                NULL AS railway,
                NULL AS aerialway,
                NULL AS shipway,
                public_transport,
                NULL AS service,
                NULL::text AS access,
                NULL::boolean AS toll,
                CASE
                    WHEN man_made IN ('bridge') THEN TRUE
                    ELSE FALSE
                    END AS is_bridge,
                FALSE AS is_tunnel,
                FALSE AS is_ford,
                NULL::boolean AS expressway,
                FALSE AS is_ramp,
                FALSE::int AS is_oneway,
                man_made,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor,
                NULL AS bicycle,
                NULL AS foot,
                NULL AS horse,
                NULL AS mtb_scale,
                NULL AS operator,
                NULL AS informal,
                NULL AS surface,
                z_order
         FROM osm_highway_polygon
              -- We do not want underground pedestrian areas for now
         WHERE zoom_level >= 13
           AND (
                 man_made IN ('bridge', 'pier')
                 OR (is_area AND COALESCE(layer, 0) >= 0)
             )
     ) AS zoom_levels
WHERE geometry && bbox
ORDER BY z_order ASC;
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;

DO $$ BEGIN RAISE NOTICE 'Finished layer transportation'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer transportation_name'; END$$;

-- Layer transportation_name - ./highway_classification.sql

CREATE OR REPLACE FUNCTION highway_to_val(hwy_class varchar)
RETURNS int
IMMUTABLE
LANGUAGE sql
AS $$
  SELECT CASE hwy_class
    WHEN 'motorway'     THEN 6
    WHEN 'trunk'        THEN 5
    WHEN 'primary'      THEN 4
    WHEN 'secondary'    THEN 3
    WHEN 'tertiary'     THEN 2
    WHEN 'unclassified' THEN 1
    ELSE 0
  END;
$$;

CREATE OR REPLACE FUNCTION val_to_highway(hwy_val int)
RETURNS varchar
IMMUTABLE
LANGUAGE sql
AS $$
  SELECT CASE hwy_val
    WHEN 6 THEN 'motorway'
    WHEN 5 THEN 'trunk'
    WHEN 4 THEN 'primary'
    WHEN 3 THEN 'secondary'
    WHEN 2 THEN 'tertiary'
    WHEN 1 THEN 'unclassified'
    ELSE null
  END;
$$;

CREATE OR REPLACE FUNCTION highest_hwy_sfunc(agg_state varchar, hwy_class varchar)
RETURNS varchar
IMMUTABLE
LANGUAGE sql
AS $$
  SELECT val_to_highway(
    GREATEST(
      highway_to_val(agg_state),
      highway_to_val(hwy_class)
    )
  );
$$;

DROP AGGREGATE IF EXISTS highest_highway (varchar);
CREATE AGGREGATE highest_highway (varchar)
(
    sfunc = highest_hwy_sfunc,
    stype = varchar
);

-- Layer transportation_name - ./update_transportation_name.sql

DROP TRIGGER IF EXISTS trigger_store_transportation_route_member ON osm_route_member;
DROP TRIGGER IF EXISTS trigger_store_transportation_superroute_member ON osm_superroute_member;
DROP TRIGGER IF EXISTS trigger_store_transportation_highway_linestring ON osm_highway_linestring;
DROP TRIGGER IF EXISTS trigger_flag_transportation_name ON transportation_name.network_changes;
DROP TRIGGER IF EXISTS trigger_refresh_network ON transportation_name.updates_network;
DROP TRIGGER IF EXISTS trigger_store_transportation_name_network ON osm_transportation_name_network;
DROP TRIGGER IF EXISTS trigger_store_transportation_name_shipway ON osm_shipway_linestring;
DROP TRIGGER IF EXISTS trigger_store_transportation_name_aerialway ON osm_aerialway_linestring;
DROP TRIGGER IF EXISTS trigger_store_transportation_name_linestring ON osm_transportation_name_linestring;
DROP TRIGGER IF EXISTS trigger_flag_name ON transportation_name.name_changes;
DROP TRIGGER IF EXISTS trigger_flag_shipway ON transportation_name.shipway_changes;
DROP TRIGGER IF EXISTS trigger_flag_aerialway ON transportation_name.aerialway_changes;
DROP TRIGGER IF EXISTS trigger_refresh_name ON transportation_name.updates_name;
DROP TRIGGER IF EXISTS trigger_refresh_shipway ON transportation_name.updates_shipway;
DROP TRIGGER IF EXISTS trigger_refresh_aerialway ON transportation_name.updates_aerialway;

-- Instead of using relations to find out the road names we
-- stitch together the touching ways with the same name
-- to allow for nice label rendering
-- Because this works well for roads that do not have relations as well

-- Indexes for filling and updating osm_transportation_name_linestring table
CREATE UNIQUE INDEX IF NOT EXISTS osm_shipway_linestring_update_partial_idx ON osm_shipway_linestring (osm_id)
    WHERE name <> '';
CREATE UNIQUE INDEX IF NOT EXISTS osm_aerialway_linestring_update_partial_idx ON osm_aerialway_linestring (osm_id)
    WHERE name <> '';
CREATE UNIQUE INDEX IF NOT EXISTS osm_transportation_name_network_update_partial_idx
    ON osm_transportation_name_network (osm_id)
    WHERE coalesce(tags->'name', '') <> '' OR
          coalesce(ref, '') <> '';
CREATE UNIQUE INDEX IF NOT EXISTS osm_transportation_name_network_osm_id_idx ON osm_transportation_name_network (osm_id);

-- Analyze tables with indexes created on them
ANALYZE osm_aerialway_linestring, osm_shipway_linestring, osm_transportation_name_network;

-- etldoc: osm_transportation_name_network ->  osm_transportation_name_linestring
-- etldoc: osm_shipway_linestring ->  osm_transportation_name_linestring
-- etldoc: osm_aerialway_linestring ->  osm_transportation_name_linestring
CREATE TABLE IF NOT EXISTS osm_transportation_name_linestring(
    id SERIAL,
    source integer,
    geometry geometry('LineString'),
    source_ids bigint[],
    new_source_ids bigint[],
    old_source_ids bigint[],
    tags hstore,
    ref text,
    highway varchar,
    subclass text,
    brunnel text,
    sac_scale varchar,
    "level" integer,
    layer integer,
    indoor boolean,
    network route_network_type,
    route_1 hstore,
    route_2 hstore,
    route_3 hstore,
    route_4 hstore,
    route_5 hstore,
    route_6 hstore,
    z_order integer,
    route_rank integer
);

ALTER TABLE osm_transportation_name_linestring ADD COLUMN IF NOT EXISTS source_ids bigint[];
-- Create temporary Merged-LineString to Source-LineStrings-ID columns to store relations before they have been
-- intersected.
ALTER TABLE osm_transportation_name_linestring ADD COLUMN IF NOT EXISTS new_source_ids BIGINT[];
ALTER TABLE osm_transportation_name_linestring ADD COLUMN IF NOT EXISTS old_source_ids BIGINT[];

CREATE INDEX IF NOT EXISTS osm_transportation_name_linestring_n_source_ids_not_null_idx 
    ON osm_transportation_name_linestring ((new_source_ids IS NOT NULL));
CREATE INDEX IF NOT EXISTS osm_transportation_name_linestring_o_source_ids_not_null_idx 
    ON osm_transportation_name_linestring ((old_source_ids IS NOT NULL));

-- Create OneToMany-Relation-Table storing relations of a Merged-LineString in table
-- osm_transportation_name_linestring to Source-LineStrings from tables osm_transportation_name_network,
-- osm_shipway_linestring and osm_aerialway_linestring
CREATE TABLE IF NOT EXISTS osm_transportation_name_linestring_source_ids(
    source int,
    id int,
    source_id bigint,
    PRIMARY KEY (source, id, source_id)
);

-- Ensure tables are emtpy if they haven't been created
TRUNCATE osm_transportation_name_linestring;
TRUNCATE osm_transportation_name_linestring_source_ids;

INSERT INTO osm_transportation_name_linestring(source, geometry, source_ids, tags, ref, highway, subclass, brunnel,
                                               sac_scale, "level", layer, indoor, network, route_1, route_2,
                                               route_3, route_4, route_5, route_6,z_order, route_rank)
SELECT source,
       geometry,
       source_ids,
       tags || get_basic_names(tags, geometry) AS tags,
       ref,
       highway,
       subclass,
       brunnel,
       sac_scale,
       "level",
       layer,
       indoor,
       network_type AS network,
       route_1, route_2, route_3, route_4, route_5, route_6,
       z_order,
       route_rank
FROM (
         -- Merge LineStrings from osm_transportation_name_network by grouping them and creating intersecting
         -- clusters of each group via ST_ClusterDBSCAN
         SELECT (ST_Dump(ST_LineMerge(ST_Union(geometry)))).geom AS geometry,
                -- We use St_Union instead of St_Collect to ensure no overlapping points exist within the
                -- geometries to merge. https://postgis.net/docs/ST_Union.html
                -- ST_LineMerge only merges across singular intersections and groups its output into a
                -- MultiLineString if more than two LineStrings form an intersection or no intersection could be
                -- found. https://postgis.net/docs/ST_LineMerge.html
                -- In order to not end up with a mixture of LineStrings and MultiLineStrings we dump eventual
                -- MultiLineStrings via ST_Dump. https://postgis.net/docs/ST_Dump.html
                array_agg(osm_id) AS source_ids,
                0 AS source,
                tags,
                ref,
                highway,
                subclass,
                brunnel,
                sac_scale,
                level,
                layer,
                indoor,
                network_type,
                route_1, route_2, route_3, route_4, route_5, route_6,
                min(z_order) AS z_order,
                min(route_rank) AS route_rank
         FROM (
             SELECT *,
                    -- Get intersecting clusters by setting minimum distance to 0 and minimum intersecting points
                    -- to 1. https://postgis.net/docs/ST_ClusterDBSCAN.html
                    ST_ClusterDBSCAN(geometry, 0, 1) OVER (
                        PARTITION BY tags, ref, highway, subclass, brunnel, level, layer, sac_scale, indoor,
                                     network_type, route_1, route_2, route_3, route_4, route_5, route_6
                    ) AS cluster,
                    -- ST_ClusterDBSCAN returns an increasing integer as the cluster-ids within each partition
                    -- starting at 0. This leads to clusters having the same ID across multiple partitions
                    -- therefore we generate a Cluster-Group-ID by utilizing the DENSE_RANK function sorted over the
                    -- partition columns.
                    DENSE_RANK() OVER (
                        ORDER BY tags, ref, highway, subclass, brunnel, level, layer, sac_scale, indoor,
                                 network_type, route_1, route_2, route_3, route_4, route_5, route_6
                    ) as cluster_group
             FROM osm_transportation_name_network
             WHERE coalesce(tags->'name', '') <> '' OR
                   coalesce(ref, '') <> ''
         ) q
         GROUP BY cluster_group, cluster, tags, ref, highway, subclass, brunnel, level, layer, sac_scale, indoor,
                  network_type, route_1, route_2, route_3, route_4, route_5, route_6
         UNION ALL

         -- Merge LineStrings from osm_shipway_linestring by grouping them and creating intersecting
         -- clusters of each group via ST_ClusterDBSCAN
         SELECT (ST_Dump(ST_LineMerge(ST_Union(geometry)))).geom AS geometry,
                -- We use St_Union instead of St_Collect to ensure no overlapping points exist within the
                -- geometries to merge. https://postgis.net/docs/ST_Union.html
                -- ST_LineMerge only merges across singular intersections and groups its output into a
                -- MultiLineString if more than two LineStrings form an intersection or no intersection could be
                -- found. https://postgis.net/docs/ST_LineMerge.html
                -- In order to not end up with a mixture of LineStrings and MultiLineStrings we dump eventual
                -- MultiLineStrings via ST_Dump. https://postgis.net/docs/ST_Dump.html
                array_agg(osm_id) AS source_ids,
                1 AS source,
                transportation_name_tags(
                    NULL::geometry, tags, name, name_en, name_de
                ) AS tags,
                NULL AS ref,
                'shipway' AS highway,
                shipway AS subclass,
                NULL AS brunnel,
                NULL AS sac_scale,
                NULL::int AS level,
                layer,
                NULL AS indoor,
                NULL AS network_type,
                NULL::hstore AS route_1,
                NULL::hstore AS route_2,
                NULL::hstore AS route_3,
                NULL::hstore AS route_4,
                NULL::hstore AS route_5,
                NULL::hstore AS route_6,
                min(z_order) AS z_order,
                NULL::int AS route_rank
         FROM (
             SELECT *,
                    -- Get intersecting clusters by setting minimum distance to 0 and minimum intersecting points
                    -- to 1. https://postgis.net/docs/ST_ClusterDBSCAN.html
                    ST_ClusterDBSCAN(geometry, 0, 1) OVER (
                        PARTITION BY transportation_name_tags(
                            NULL::geometry, tags, name, name_en, name_de
                        ), shipway, layer
                    ) AS cluster,
                    -- ST_ClusterDBSCAN returns an increasing integer as the cluster-ids within each partition
                    -- starting at 0. This leads to clusters having the same ID across multiple partitions
                    -- therefore we generate a Cluster-Group-ID by utilizing the DENSE_RANK function sorted over the
                    -- partition columns.
                    DENSE_RANK() OVER (
                        ORDER BY transportation_name_tags(
                            NULL::geometry, tags, name, name_en, name_de
                        ), shipway, layer
                    ) as cluster_group
             FROM osm_shipway_linestring
             WHERE name <> ''
         ) q
         GROUP BY cluster_group, cluster, transportation_name_tags(
             NULL::geometry, tags, name, name_en, name_de
         ), shipway, layer
         UNION ALL

         -- Merge LineStrings from osm_aerialway_linestring by grouping them and creating intersecting
         -- clusters of each group via ST_ClusterDBSCAN
         SELECT (ST_Dump(ST_LineMerge(ST_Union(geometry)))).geom AS geometry,
                -- We use St_Union instead of St_Collect to ensure no overlapping points exist within the
                -- geometries to merge. https://postgis.net/docs/ST_Union.html
                -- ST_LineMerge only merges across singular intersections and groups its output into a
                -- MultiLineString if more than two LineStrings form an intersection or no intersection could be
                -- found. https://postgis.net/docs/ST_LineMerge.html
                -- In order to not end up with a mixture of LineStrings and MultiLineStrings we dump eventual
                -- MultiLineStrings via ST_Dump. https://postgis.net/docs/ST_Dump.html
                array_agg(osm_id) AS source_ids,
                2 AS source,
                transportation_name_tags(
                    NULL::geometry, tags, name, name_en, name_de
                ) AS tags,
                NULL AS ref,
                'aerialway' AS highway,
                aerialway AS subclass,
                NULL AS brunnel,
                NULL AS sac_scale,
                NULL::int AS level,
                layer,
                NULL AS indoor,
                NULL AS network_type,
                NULL::hstore AS route_1,
                NULL::hstore AS route_2,
                NULL::hstore AS route_3,
                NULL::hstore AS route_4,
                NULL::hstore AS route_5,
                NULL::hstore AS route_6,
                min(z_order) AS z_order,
                NULL::int AS route_rank
         FROM (
             SELECT *,
                    -- Get intersecting clusters by setting minimum distance to 0 and minimum intersecting points
                    -- to 1. https://postgis.net/docs/ST_ClusterDBSCAN.html
                    ST_ClusterDBSCAN(geometry, 0, 1) OVER (
                        PARTITION BY transportation_name_tags(
                            NULL::geometry, tags, name, name_en, name_de
                        ), aerialway, layer
                    ) AS cluster,
                    -- ST_ClusterDBSCAN returns an increasing integer as the cluster-ids within each partition
                    -- starting at 0. This leads to clusters having the same ID across multiple partitions
                    -- therefore we generate a Cluster-Group-ID by utilizing the DENSE_RANK function sorted over the
                    -- partition columns.
                    DENSE_RANK() OVER (
                        ORDER BY transportation_name_tags(
                            NULL::geometry, tags, name, name_en, name_de
                        ), aerialway, layer
                    ) as cluster_group
             FROM osm_aerialway_linestring
             WHERE name <> ''
         ) q
         GROUP BY cluster_group, cluster, transportation_name_tags(
             NULL::geometry, tags, name, name_en, name_de
         ), aerialway, layer
     ) AS highway_union;

-- Geometry Index
CREATE INDEX IF NOT EXISTS osm_transportation_name_linestring_geometry_idx
    ON osm_transportation_name_linestring USING gist (geometry);

-- Create table for simplified LineStrings
CREATE TABLE IF NOT EXISTS osm_transportation_name_linestring_gen1 (
    id integer,
    geometry geometry,
    tags hstore,
    ref text,
    highway varchar,
    subclass text,
    brunnel text,
    network route_network_type,
    route_1 hstore,
    route_2 hstore,
    route_3 hstore,
    route_4 hstore,
    route_5 hstore,
    route_6 hstore,
    z_order integer
);

-- Create osm_transportation_name_linestring_gen2 as a copy of osm_transportation_name_linestring_gen1
CREATE TABLE IF NOT EXISTS osm_transportation_name_linestring_gen2
(LIKE osm_transportation_name_linestring_gen1);

-- Create osm_transportation_name_linestring_gen3 as a copy of osm_transportation_name_linestring_gen2
CREATE TABLE IF NOT EXISTS osm_transportation_name_linestring_gen3
(LIKE osm_transportation_name_linestring_gen2);

-- Create osm_transportation_name_linestring_gen4 as a copy of osm_transportation_name_linestring_gen3
CREATE TABLE IF NOT EXISTS osm_transportation_name_linestring_gen4
(LIKE osm_transportation_name_linestring_gen3);

-- Create Primary-Keys for osm_transportation_name_linestring and
-- osm_transportation_name_linestring_gen1/gen2/gen3/gen4 tables
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_transportation_name_linestring' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_transportation_name_linestring ADD PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_transportation_name_linestring_gen1' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_transportation_name_linestring_gen1 ADD PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_transportation_name_linestring_gen2' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_transportation_name_linestring_gen2 ADD PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_transportation_name_linestring_gen3' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_transportation_name_linestring_gen3 ADD PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'osm_transportation_name_linestring_gen4' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE osm_transportation_name_linestring_gen4 ADD PRIMARY KEY (id);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Indexes which can be utilized during full-update for queries originating from
-- update_transportation_name_linestring_gen() function
CREATE UNIQUE INDEX IF NOT EXISTS osm_transportation_name_linestring_update_partial_idx
    ON osm_transportation_name_linestring (id)
    WHERE (highway IN ('motorway', 'trunk') OR highway = 'construction' AND subclass IN ('motorway', 'trunk'))
          AND ST_Length(geometry) > 8000;

-- Temporary index for filling source tables
CREATE INDEX IF NOT EXISTS osm_transportation_name_linestring_source_idx ON osm_transportation_name_linestring (source);

-- Analyze populated table with indexes
ANALYZE osm_transportation_name_linestring;

-- Store OSM-IDs of Source-LineStrings by intersecting Merged-LineStrings with their sources. This required because
-- ST_LineMerge only merges across singular intersections and groups its output into a MultiLineString if
-- more than two LineStrings form an intersection or no intersection could be found.
-- Execute after indexes have been created on osm_transportation_merge_linestring_gen_z11 to improve performance
INSERT INTO osm_transportation_name_linestring_source_ids(source, id, source_id)
SELECT m.source, m.id, source_id
FROM (
    SELECT id, source, unnest(source_ids) AS source_id, geometry
    FROM osm_transportation_name_linestring
    WHERE osm_transportation_name_linestring.source = 0
) m
JOIN osm_transportation_name_network s ON (m.source_id = s.osm_id)
WHERE ST_Intersects(s.geometry, m.geometry)
ON CONFLICT (source, id, source_id) DO NOTHING;
INSERT INTO osm_transportation_name_linestring_source_ids(source, id, source_id)
SELECT m.source, m.id, source_id
FROM (
    SELECT id, source, unnest(source_ids) AS source_id, geometry
    FROM osm_transportation_name_linestring
    WHERE osm_transportation_name_linestring.source = 1
) m
JOIN osm_shipway_linestring s ON (m.source_id = s.osm_id)
WHERE ST_Intersects(s.geometry, m.geometry)
ON CONFLICT (source, id, source_id) DO NOTHING;
INSERT INTO osm_transportation_name_linestring_source_ids(source, id, source_id)
SELECT m.source, m.id, source_id
FROM (
    SELECT id, source, unnest(source_ids) AS source_id, geometry
    FROM osm_transportation_name_linestring
    WHERE osm_transportation_name_linestring.source = 2
) m
JOIN osm_aerialway_linestring s ON (m.source_id = s.osm_id)
WHERE ST_Intersects(s.geometry, m.geometry)
ON CONFLICT (source, id, source_id) DO NOTHING;

-- Drop temporary Merged-LineString to Source-LineStrings-ID column
ALTER TABLE osm_transportation_name_linestring DROP COLUMN IF EXISTS source_ids;

-- Drop temporary index
DROP INDEX IF EXISTS osm_transportation_name_linestring_source_idx;

CREATE SCHEMA IF NOT EXISTS transportation_name;

CREATE TABLE IF NOT EXISTS transportation_name.name_changes_gen
(
    is_old boolean,
    id int,
    PRIMARY KEY (is_old, id)
);

CREATE OR REPLACE FUNCTION update_transportation_name_linestring_gen (full_update bool) RETURNS VOID AS $$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh transportation_name merged';

    -- Analyze tracking and source tables before performing update
    ANALYZE transportation_name.name_changes_gen;
    ANALYZE osm_transportation_name_linestring;

    -- Remove entries which have been deleted from source table
    DELETE FROM osm_transportation_name_linestring_gen1
    USING transportation_name.name_changes_gen
    WHERE full_update IS TRUE OR (
        transportation_name.name_changes_gen.is_old IS TRUE AND
        transportation_name.name_changes_gen.id = osm_transportation_name_linestring_gen1.id
    );

    -- etldoc: osm_transportation_name_linestring -> osm_transportation_name_linestring_gen1
    INSERT INTO osm_transportation_name_linestring_gen1 (id, geometry, tags, ref, highway, subclass, brunnel, network,
                                                         route_1, route_2, route_3, route_4, route_5, route_6, z_order)
    SELECT MIN(id) as id,
           ST_Simplify(ST_LineMerge(ST_Collect(geometry)), 50) AS geometry,
           tags, ref, highway, subclass, brunnel, network,
           route_1, route_2, route_3, route_4, route_5, route_6,
           MIN(z_order) AS z_order
    FROM (
        SELECT id,
               geometry,
               tags, ref, highway, subclass,
               visible_text(geometry, brunnel, 9) AS brunnel,
               network, route_1, route_2, route_3, route_4, route_5, route_6,
               z_order
        FROM osm_transportation_name_linestring
    ) osm_transportation_name_linestring_gen1_pre_merge
    WHERE (
        full_update IS TRUE OR EXISTS (
            SELECT NULL
            FROM transportation_name.name_changes_gen
            WHERE transportation_name.name_changes_gen.is_old IS FALSE AND
                  transportation_name.name_changes_gen.id = osm_transportation_name_linestring_gen1_pre_merge.id
        )
    ) AND (
        (highway IN ('motorway', 'trunk') OR highway = 'construction' AND subclass IN ('motorway', 'trunk'))
    )
    GROUP BY tags, ref, highway, subclass, brunnel, network, route_1, route_2, route_3, route_4, route_5, route_6
    ON CONFLICT (id) DO UPDATE SET geometry = excluded.geometry, tags = excluded.tags, ref = excluded.ref,
                                     highway = excluded.highway, subclass = excluded.subclass,
                                     brunnel = excluded.brunnel, network = excluded.network, route_1 = excluded.route_1,
                                     route_2 = excluded.route_2, route_3 = excluded.route_3, route_4 = excluded.route_4,
                                     route_5 = excluded.route_5, route_6 = excluded.route_6, z_order = excluded.z_order;

    -- Analyze source table
    ANALYZE osm_transportation_name_linestring_gen1;

    -- Remove entries which have been deleted from source table
    DELETE FROM osm_transportation_name_linestring_gen2
    USING transportation_name.name_changes_gen
    WHERE full_update IS TRUE OR (
        transportation_name.name_changes_gen.is_old IS TRUE AND
        transportation_name.name_changes_gen.id = osm_transportation_name_linestring_gen2.id
    );

    -- etldoc: osm_transportation_name_linestring_gen1 -> osm_transportation_name_linestring_gen2
    INSERT INTO osm_transportation_name_linestring_gen2 (id, geometry, tags, ref, highway, subclass, brunnel, network,
                                                         route_1, route_2, route_3, route_4, route_5, route_6)
    SELECT MIN(id) as id,
           ST_Simplify(ST_LineMerge(ST_Collect(geometry)), 120) AS geometry,
           tags, ref, highway, subclass, brunnel, network,
           route_1, route_2, route_3, route_4, route_5, route_6
    FROM (
        SELECT id,
               (ST_Dump(geometry)).geom AS geometry,
               tags, ref, highway, subclass,
               visible_text(geometry, brunnel, 8) AS brunnel,
               network, route_1, route_2, route_3, route_4, route_5, route_6
        FROM osm_transportation_name_linestring_gen1
    ) osm_transportation_name_linestring_gen2_pre_merge
    WHERE (
        full_update IS TRUE OR EXISTS (
            SELECT NULL
            FROM transportation_name.name_changes_gen
            WHERE transportation_name.name_changes_gen.is_old IS FALSE AND
                  transportation_name.name_changes_gen.id = osm_transportation_name_linestring_gen2_pre_merge.id
        )
    ) AND (
        (highway IN ('motorway', 'trunk') OR highway = 'construction' AND subclass IN ('motorway', 'trunk'))
    )
    GROUP BY tags, ref, highway, subclass, brunnel, network, route_1, route_2, route_3, route_4, route_5, route_6
    ON CONFLICT (id) DO UPDATE SET geometry = excluded.geometry, tags = excluded.tags, ref = excluded.ref,
                                     highway = excluded.highway, subclass = excluded.subclass,
                                     brunnel = excluded.brunnel, network = excluded.network, route_1 = excluded.route_1,
                                     route_2 = excluded.route_2, route_3 = excluded.route_3, route_4 = excluded.route_4,
                                     route_5 = excluded.route_5, route_6 = excluded.route_6;

    -- Analyze source table
    ANALYZE osm_transportation_name_linestring_gen2;

    -- Remove entries which have been deleted from source table
    DELETE FROM osm_transportation_name_linestring_gen3
    USING transportation_name.name_changes_gen
    WHERE full_update IS TRUE OR (
        transportation_name.name_changes_gen.is_old IS TRUE AND
        transportation_name.name_changes_gen.id = osm_transportation_name_linestring_gen3.id
    );

    -- etldoc: osm_transportation_name_linestring_gen2 -> osm_transportation_name_linestring_gen3
    INSERT INTO osm_transportation_name_linestring_gen3 (id, geometry, tags, ref, highway, subclass, brunnel, network,
                                                         route_1, route_2, route_3, route_4, route_5, route_6)
    SELECT MIN(id) as id,
           ST_Simplify(ST_LineMerge(ST_Collect(geometry)), 200) AS geometry,
           tags, ref, highway, subclass, brunnel, network,
           route_1, route_2, route_3, route_4, route_5, route_6
    FROM (
        SELECT id,
               (ST_Dump(geometry)).geom AS geometry,
               tags, ref, highway, subclass,
               visible_text(geometry, brunnel, 7) AS brunnel,
               network, route_1, route_2, route_3, route_4, route_5, route_6
        FROM osm_transportation_name_linestring_gen2
    ) osm_transportation_name_linestring_gen3_pre_merge
    WHERE (
        full_update IS TRUE OR EXISTS (
            SELECT NULL
            FROM transportation_name.name_changes_gen
            WHERE transportation_name.name_changes_gen.is_old IS FALSE AND
                  transportation_name.name_changes_gen.id = osm_transportation_name_linestring_gen3_pre_merge.id
        )
    ) AND (
        (highway = 'motorway' OR highway = 'construction' AND subclass = 'motorway')
    )
    GROUP BY tags, ref, highway, subclass, brunnel, network, route_1, route_2, route_3, route_4, route_5, route_6
    ON CONFLICT (id) DO UPDATE SET geometry = excluded.geometry, tags = excluded.tags, ref = excluded.ref,
                                     highway = excluded.highway, subclass = excluded.subclass,
                                     brunnel = excluded.brunnel, network = excluded.network, route_1 = excluded.route_1,
                                     route_2 = excluded.route_2, route_3 = excluded.route_3, route_4 = excluded.route_4,
                                     route_5 = excluded.route_5, route_6 = excluded.route_6;

    -- Analyze source table
    ANALYZE osm_transportation_name_linestring_gen3;

    -- Remove entries which have been deleted from source table
    DELETE FROM osm_transportation_name_linestring_gen4
    USING transportation_name.name_changes_gen
    WHERE full_update IS TRUE OR (
        transportation_name.name_changes_gen.is_old IS TRUE AND
        transportation_name.name_changes_gen.id = osm_transportation_name_linestring_gen4.id
    );

    -- etldoc: osm_transportation_name_linestring_gen3 -> osm_transportation_name_linestring_gen4
    INSERT INTO osm_transportation_name_linestring_gen4 (id, geometry, tags, ref, highway, subclass, brunnel, network,
                                                         route_1, route_2, route_3, route_4, route_5, route_6)
    SELECT MIN(id) as id,
           ST_Simplify(ST_LineMerge(ST_Collect(geometry)), 500) AS geometry,
           tags, ref, highway, subclass, brunnel, network,
           route_1, route_2, route_3, route_4, route_5, route_6
    FROM (
        SELECT id,
               (ST_Dump(geometry)).geom AS geometry,
               tags, ref, highway, subclass,
               visible_text(geometry, brunnel, 6) AS brunnel,
               network, route_1, route_2, route_3, route_4, route_5, route_6
        FROM osm_transportation_name_linestring_gen3
    ) osm_transportation_name_linestring_gen4_pre_merge
    WHERE (
        full_update IS TRUE OR EXISTS (
            SELECT NULL
            FROM transportation_name.name_changes_gen
            WHERE transportation_name.name_changes_gen.is_old IS FALSE AND
                  transportation_name.name_changes_gen.id = osm_transportation_name_linestring_gen4_pre_merge.id
        )
    ) AND (
        ST_Length(geometry) > 20000 AND
        (highway = 'motorway' OR highway = 'construction' AND subclass = 'motorway')
    )
    GROUP BY tags, ref, highway, subclass, brunnel, network, route_1, route_2, route_3, route_4, route_5, route_6
    ON CONFLICT (id) DO UPDATE SET geometry = excluded.geometry, tags = excluded.tags, ref = excluded.ref,
                                     highway = excluded.highway, subclass = excluded.subclass,
                                     brunnel = excluded.brunnel, network = excluded.network, route_1 = excluded.route_1,
                                     route_2 = excluded.route_2, route_3 = excluded.route_3, route_4 = excluded.route_4,
                                     route_5 = excluded.route_5, route_6 = excluded.route_6;

    -- noinspection SqlWithoutWhere
    DELETE FROM transportation_name.name_changes_gen;

    RAISE LOG 'Refresh transportation_name merged done in %', age(clock_timestamp(), t);
END;
$$ LANGUAGE plpgsql;

-- Ensure tables are emtpy if they haven't been created
TRUNCATE osm_transportation_name_linestring_gen1;
TRUNCATE osm_transportation_name_linestring_gen2;
TRUNCATE osm_transportation_name_linestring_gen3;
TRUNCATE osm_transportation_name_linestring_gen4;

SELECT update_transportation_name_linestring_gen(TRUE);

-- Indexes for queries originating from update_transportation_name_linestring_gen() function
CREATE UNIQUE INDEX IF NOT EXISTS osm_transportation_name_linestring_gen1_update_partial_idx
    ON osm_transportation_name_linestring_gen1 (id)
    WHERE (highway IN ('motorway', 'trunk') OR highway = 'construction' AND subclass IN ('motorway', 'trunk'))
          AND ST_Length(geometry) > 14000;
CREATE UNIQUE INDEX IF NOT EXISTS osm_transportation_name_linestring_gen2_update_partial_idx
    ON osm_transportation_name_linestring_gen2 (id)
    WHERE (highway = 'motorway' OR highway = 'construction' AND subclass = 'motorway')
          AND ST_Length(geometry) > 20000;
CREATE UNIQUE INDEX IF NOT EXISTS osm_transportation_name_linestring_gen3_update_partial_idx
    ON osm_transportation_name_linestring_gen3 (id)
    WHERE (highway = 'motorway' OR highway = 'construction' AND subclass = 'motorway')
          AND ST_Length(geometry) > 20000;

-- Geometry Indexes
CREATE INDEX IF NOT EXISTS osm_transportation_name_linestring_gen1_geometry_idx
    ON osm_transportation_name_linestring_gen1 USING gist (geometry);
CREATE INDEX IF NOT EXISTS osm_transportation_name_linestring_gen2_geometry_idx
    ON osm_transportation_name_linestring_gen2 USING gist (geometry);
CREATE INDEX IF NOT EXISTS osm_transportation_name_linestring_gen3_geometry_idx
    ON osm_transportation_name_linestring_gen3 USING gist (geometry);
CREATE INDEX IF NOT EXISTS osm_transportation_name_linestring_gen4_geometry_idx
    ON osm_transportation_name_linestring_gen4 USING gist (geometry);

-- Handle updates

-- Trigger to update "osm_transportation_name_network" from "osm_route_member" and "osm_highway_linestring"

CREATE TABLE IF NOT EXISTS transportation_name.network_changes
(
    is_old bool,
    osm_id bigint,
    PRIMARY KEY (is_old, osm_id)
);

-- Store IDs of changed elements from osm_route_member table.
CREATE OR REPLACE FUNCTION transportation_name.route_member_store() RETURNS trigger AS
$$
BEGIN
    IF tg_op = 'DELETE' OR (tg_op = 'UPDATE' AND (old.member IS DISTINCT FROM new.member))
    THEN
        INSERT INTO transportation_name.network_changes(is_old, osm_id)
        VALUES (TRUE, old.member)
        ON CONFLICT(is_old, osm_id) DO NOTHING;
    END IF;
    IF (tg_op IN ('UPDATE', 'INSERT'))
    THEN
        INSERT INTO transportation_name.network_changes(is_old, osm_id)
        VALUES (FALSE, new.member)
        ON CONFLICT(is_old, osm_id) DO NOTHING;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Store IDs of changed elements from osm_highway_linestring table.
CREATE OR REPLACE FUNCTION transportation_name.highway_linestring_store() RETURNS trigger AS
$$
BEGIN
    IF tg_op = 'DELETE' OR (tg_op = 'UPDATE' AND (old.osm_id IS DISTINCT FROM new.osm_id))
    THEN
        INSERT INTO transportation_name.network_changes(is_old, osm_id)
        VALUES (TRUE, old.osm_id)
        ON CONFLICT(is_old, osm_id) DO NOTHING;
    END IF;
    IF (tg_op IN ('UPDATE', 'INSERT'))
    THEN
        INSERT INTO transportation_name.network_changes(is_old, osm_id)
        VALUES (FALSE, new.osm_id)
        ON CONFLICT(is_old, osm_id) DO NOTHING;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS transportation_name.updates_network
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION transportation_name.flag_network() RETURNS trigger AS
$$
BEGIN
    INSERT INTO transportation_name.updates_network(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transportation_name.refresh_network() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh transportation_name_network';

    -- Update Way-Relations and analyze table afterwards
    PERFORM update_osm_route_member(FALSE);
    ANALYZE transportation_route_member_coalesced;

    -- REFRESH osm_transportation_name_network
    DELETE
    FROM osm_transportation_name_network
    USING transportation_name.network_changes c
    WHERE c.is_old IS TRUE AND osm_transportation_name_network.osm_id = c.osm_id;

    UPDATE osm_highway_linestring
    SET network = NULL
    FROM transportation_name.network_changes c
    WHERE c.is_old IS TRUE AND osm_highway_linestring.osm_id = c.osm_id;

    UPDATE osm_highway_linestring_gen_z11
    SET network = NULL
    FROM transportation_name.network_changes c
    WHERE c.is_old IS TRUE AND osm_highway_linestring_gen_z11.osm_id = c.osm_id;

    UPDATE osm_highway_linestring
    SET network = rm.network_type
    FROM transportation_name.network_changes c
    JOIN transportation_route_member_coalesced rm ON (c.osm_id = rm.member AND rm.concurrency_index=1)
    WHERE c.is_old IS FALSE AND osm_highway_linestring.osm_id=c.osm_id;

    UPDATE osm_highway_linestring_gen_z11
    SET network = rm.network_type
    FROM transportation_name.network_changes c
    JOIN transportation_route_member_coalesced rm ON (c.osm_id = rm.member AND rm.concurrency_index=1)
    WHERE c.is_old IS FALSE AND osm_highway_linestring_gen_z11.osm_id=c.osm_id;

    INSERT INTO osm_transportation_name_network
    SELECT
        geometry,
        osm_id,
        tags || get_basic_names(tags, geometry) AS tags,
        ref,
        highway,
        subclass,
        brunnel,
        level,
        sac_scale,
        layer,
        indoor,
        network_type,
        route_1, route_2, route_3, route_4, route_5, route_6,
        z_order,
        route_rank
    FROM (
        SELECT hl.geometry,
            hl.osm_id,
            transportation_name_tags(hl.geometry, hl.tags, hl.name, hl.name_en, hl.name_de) AS tags,
            rm1.network_type,
            CASE
                WHEN rm1.network_type IS NOT NULL AND rm1.ref::text <> ''
                    THEN rm1.ref::text
                ELSE NULLIF(hl.ref, '')
                END AS ref,
            hl.highway,
            NULLIF(hl.construction, '') AS subclass,
            brunnel(hl.is_bridge, hl.is_tunnel, hl.is_ford) AS brunnel,
            sac_scale,
            CASE WHEN highway IN ('footway', 'steps') THEN layer END AS layer,
            CASE WHEN highway IN ('footway', 'steps') THEN level END AS level,
            CASE WHEN highway IN ('footway', 'steps') THEN indoor END AS indoor,
            create_route_hstore(rm1.network, rm1.ref, rm1.name, rm1.colour, rm1.ref_colour) AS route_1,
            create_route_hstore(rm2.network, rm2.ref, rm2.name, rm2.colour, rm2.ref_colour) AS route_2,
            create_route_hstore(rm3.network, rm3.ref, rm3.name, rm3.colour, rm3.ref_colour) AS route_3,
            create_route_hstore(rm4.network, rm4.ref, rm4.name, rm4.colour, rm4.ref_colour) AS route_4,
            create_route_hstore(rm5.network, rm5.ref, rm5.name, rm5.colour, rm5.ref_colour) AS route_5,
            create_route_hstore(rm6.network, rm6.ref, rm6.name, rm6.colour, rm6.ref_colour) AS route_6,
	    hl.z_order,
            LEAST(rm1.rank, rm2.rank, rm3.rank, rm4.rank, rm5.rank, rm6.rank) AS route_rank
        FROM osm_highway_linestring hl
                JOIN transportation_name.network_changes AS c ON
                c.is_old IS FALSE AND hl.osm_id = c.osm_id
		LEFT OUTER JOIN transportation_route_member_coalesced rm1 ON rm1.member = hl.osm_id AND rm1.concurrency_index=1
		LEFT OUTER JOIN transportation_route_member_coalesced rm2 ON rm2.member = hl.osm_id AND rm2.concurrency_index=2
		LEFT OUTER JOIN transportation_route_member_coalesced rm3 ON rm3.member = hl.osm_id AND rm3.concurrency_index=3
		LEFT OUTER JOIN transportation_route_member_coalesced rm4 ON rm4.member = hl.osm_id AND rm4.concurrency_index=4
		LEFT OUTER JOIN transportation_route_member_coalesced rm5 ON rm5.member = hl.osm_id AND rm5.concurrency_index=5
		LEFT OUTER JOIN transportation_route_member_coalesced rm6 ON rm6.member = hl.osm_id AND rm6.concurrency_index=6
	WHERE (hl.name <> '' OR hl.ref <> '' OR rm1.ref <> '' OR rm1.network <> '')
          AND hl.highway <> ''
    ) AS t
    ON CONFLICT DO NOTHING;

    -- noinspection SqlWithoutWhere
    DELETE FROM transportation_name.network_changes;
    -- noinspection SqlWithoutWhere
    DELETE FROM transportation_name.updates_network;

    RAISE LOG 'Refresh transportation_name network done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trigger_store_transportation_route_member
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_route_member
    FOR EACH ROW
EXECUTE PROCEDURE transportation_name.route_member_store();

CREATE TRIGGER trigger_store_transportation_highway_linestring
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_highway_linestring
    FOR EACH ROW
EXECUTE PROCEDURE transportation_name.highway_linestring_store();

CREATE TRIGGER trigger_flag_transportation_name
    AFTER INSERT
    ON transportation_name.network_changes
    FOR EACH STATEMENT
EXECUTE PROCEDURE transportation_name.flag_network();

CREATE CONSTRAINT TRIGGER trigger_refresh_network
    AFTER INSERT
    ON transportation_name.updates_network
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE transportation_name.refresh_network();

-- Handle updates on
-- osm_transportation_name_network -> osm_transportation_name_linestring
-- osm_shipway_linestring -> osm_transportation_name_linestring
-- osm_aerialway_linestring -> osm_transportation_name_linestring
-- osm_transportation_name_linestring -> osm_transportation_name_linestring_gen1
-- osm_transportation_name_linestring -> osm_transportation_name_linestring_gen2
-- osm_transportation_name_linestring -> osm_transportation_name_linestring_gen3
-- osm_transportation_name_linestring -> osm_transportation_name_linestring_gen4

CREATE OR REPLACE AGGREGATE array_cat_agg(anycompatiblearray) (
  SFUNC=array_cat,
  STYPE=anycompatiblearray,
  INITCOND = '{}'
);

CREATE TABLE IF NOT EXISTS transportation_name.name_changes
(
    is_old boolean,
    osm_id bigint,
    PRIMARY KEY (is_old, osm_id)
);
CREATE TABLE IF NOT EXISTS transportation_name.shipway_changes
(
    is_old boolean,
    osm_id bigint,
    PRIMARY KEY (is_old, osm_id)
);
CREATE TABLE IF NOT EXISTS transportation_name.aerialway_changes
(
    is_old boolean,
    osm_id bigint,
    PRIMARY KEY (is_old, osm_id)
);

-- Store IDs of changed elements from osm_transportation_name_network table.
CREATE OR REPLACE FUNCTION transportation_name.name_network_store() RETURNS trigger AS
$$
BEGIN
    IF (tg_op IN ('DELETE', 'UPDATE'))
    THEN
        INSERT INTO transportation_name.name_changes(is_old, osm_id)
        VALUES (TRUE, old.osm_id)
        ON CONFLICT (is_old, osm_id) DO NOTHING;
    END IF;
    IF (tg_op IN ('UPDATE', 'INSERT'))
    THEN
        INSERT INTO transportation_name.name_changes(is_old, osm_id)
        VALUES (FALSE, new.osm_id)
        ON CONFLICT (is_old, osm_id) DO NOTHING;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Store IDs of changed elements from osm_shipway_linestring table.
CREATE OR REPLACE FUNCTION transportation_name.name_shipway_store() RETURNS trigger AS
$$
BEGIN
    IF (tg_op IN ('DELETE', 'UPDATE'))
    THEN
        INSERT INTO transportation_name.shipway_changes(is_old, osm_id)
        VALUES (TRUE, old.osm_id)
        ON CONFLICT (is_old, osm_id) DO NOTHING;
    END IF;
    IF (tg_op IN ('UPDATE', 'INSERT'))
    THEN
        INSERT INTO transportation_name.shipway_changes(is_old, osm_id)
        VALUES (FALSE, new.osm_id)
        ON CONFLICT (is_old, osm_id) DO NOTHING;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Store IDs of changed elements from osm_aerialway_linestring table.
CREATE OR REPLACE FUNCTION transportation_name.name_aerialway_store() RETURNS trigger AS
$$
BEGIN
    IF (tg_op IN ('DELETE', 'UPDATE'))
    THEN
        INSERT INTO transportation_name.aerialway_changes(is_old, osm_id)
        VALUES (TRUE, old.osm_id)
        ON CONFLICT (is_old, osm_id) DO NOTHING;
    END IF;
    IF (tg_op IN ('UPDATE', 'INSERT'))
    THEN
        INSERT INTO transportation_name.aerialway_changes(is_old, osm_id)
        VALUES (FALSE, new.osm_id)
        ON CONFLICT (is_old, osm_id) DO NOTHING;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Store IDs of changed elements from osm_transportation_name_linestring table.
CREATE OR REPLACE FUNCTION transportation_name.name_linestring_store() RETURNS trigger AS
$$
BEGIN
    IF (tg_op = 'DELETE')
    THEN
        INSERT INTO transportation_name.name_changes_gen(is_old, id)
        VALUES (TRUE, old.id)
        ON CONFLICT (is_old, id) DO NOTHING;
    END IF;
    IF (tg_op = 'UPDATE' OR tg_op = 'INSERT')
    THEN
        INSERT INTO transportation_name.name_changes_gen(is_old, id)
        VALUES (FALSE, new.id)
        ON CONFLICT (is_old, id) DO NOTHING;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS transportation_name.updates_name
(
    id serial PRIMARY KEY,
    t  text,
    UNIQUE (t)
);
CREATE TABLE IF NOT EXISTS transportation_name.updates_shipway
(
    id serial PRIMARY KEY,
    t  text,
    UNIQUE (t)
);
CREATE TABLE IF NOT EXISTS transportation_name.updates_aerialway
(
    id serial PRIMARY KEY,
    t  text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION transportation_name.flag_name() RETURNS trigger AS
$$
BEGIN
    INSERT INTO transportation_name.updates_name(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transportation_name.flag_shipway() RETURNS trigger AS
$$
BEGIN
    INSERT INTO transportation_name.updates_shipway(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transportation_name.flag_aerialway() RETURNS trigger AS
$$
BEGIN
    INSERT INTO transportation_name.updates_aerialway(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transportation_name.refresh_name() RETURNS trigger AS
$BODY$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh transportation_name';

    -- REFRESH osm_transportation_name_linestring from osm_transportation_name_network

    -- Analyze tracking and source tables before performing update
    ANALYZE transportation_name.name_changes;
    ANALYZE osm_transportation_name_network;

    -- Fetch updated and deleted Merged-LineString from relation-table filtering for each Merged-LineString which
    -- contains an updated Source-LineString.
    -- Additionally attach a list of Source-LineString-IDs to each Merged-LineString in order to unnest them later.
    CREATE TEMPORARY TABLE affected_merged_linestrings AS
    SELECT m.id, array_agg(source_id) AS source_ids
    FROM osm_transportation_name_linestring_source_ids m
    WHERE m.source = 0 AND EXISTS(
        SELECT NULL
        FROM transportation_name.name_changes c
        WHERE c.is_old IS TRUE AND c.osm_id = m.source_id
    )
    GROUP BY id;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE affected_merged_linestrings;

    -- Delete all Merged-LineStrings which contained an updated or deleted Source-LineString
    DELETE
    FROM osm_transportation_name_linestring m
    USING affected_merged_linestrings
    WHERE affected_merged_linestrings.id = m.id;
    DELETE
    FROM osm_transportation_name_linestring_source_ids m
    USING affected_merged_linestrings
    WHERE affected_merged_linestrings.id = m.id;

    -- Analyze the tables affected by the delete-query in order to speed up subsequent queries
    ANALYZE osm_transportation_name_linestring;
    ANALYZE osm_transportation_name_linestring_source_ids;

    -- Create a table containing all LineStrings which should be merged
    CREATE TEMPORARY TABLE linestrings_to_merge AS
    -- Add all Source-LineStrings affected by this update
    SELECT osm_id, NULL::INTEGER AS id, NULL::BIGINT[] AS source_ids, geometry, tags, ref, highway, subclass, brunnel,
           sac_scale, level, layer, indoor, network_type, route_1, route_2, route_3, route_4, route_5, route_6,
           z_order, route_rank
    FROM (
        -- Get Source-LineString-IDs of deleted or updated elements
        SELECT unnest(affected_merged_linestrings.source_ids)::bigint AS source_id
        FROM affected_merged_linestrings
        UNION
        -- Get Source-LineString-IDs of inserted or updated elements
        SELECT osm_id AS source_id FROM transportation_name.name_changes WHERE is_old IS FALSE
        ORDER BY source_id
    ) affected_source_linestrings
    JOIN osm_transportation_name_network ON (
        affected_source_linestrings.source_id = osm_transportation_name_network.osm_id
    )
    WHERE coalesce(tags->'name', '') <> '' OR coalesce(ref, '') <> '';

    -- Drop temporary tables early to save resources
    DROP TABLE affected_merged_linestrings;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE linestrings_to_merge;

    -- Add all Merged-LineStrings intersecting with Source-LineStrings affected by this update
    INSERT INTO linestrings_to_merge
    SELECT NULL::BIGINT AS osm_id, m.id,
           ARRAY(
               SELECT s.source_id
               FROM osm_transportation_name_linestring_source_ids s
               WHERE s.source = 0 AND m.id = s.id
           )::BIGINT[] AS source_ids,
           m.geometry, m.tags, m.ref, m.highway, m.subclass, m.brunnel, m.sac_scale,
           m.level, m.layer, m.indoor, m.network AS network_type, m.route_1, m.route_2, m.route_3,
           m.route_4, m.route_5, m.route_6, m.z_order, m.route_rank
    FROM linestrings_to_merge
    JOIN osm_transportation_name_linestring m ON (ST_Intersects(linestrings_to_merge.geometry, m.geometry))
    WHERE m.source = 0;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE linestrings_to_merge;

    -- Delete all Merged-LineStrings intersecting with Source-LineStrings affected by this update.
    -- We can use the linestrings_to_merge table since Source-LineStrings affected by this update and present in the
    -- table will have their ID-Column set to NULL by the previous query.
    DELETE
    FROM osm_transportation_name_linestring m
    USING linestrings_to_merge
    WHERE m.id = linestrings_to_merge.id;
    DELETE
    FROM osm_transportation_name_linestring_source_ids m
    USING linestrings_to_merge
    WHERE m.id = linestrings_to_merge.id;

    -- Create table containing all LineStrings to and create clusters of intersecting LineStrings partitioned by their
    -- groups
    CREATE TEMPORARY TABLE clustered_linestrings_to_merge AS
    SELECT *,
           -- Get intersecting clusters by setting minimum distance to 0 and minimum intersecting points to 1.
           -- https://postgis.net/docs/ST_ClusterDBSCAN.html
           ST_ClusterDBSCAN(geometry, 0, 1) OVER (
               PARTITION BY tags, ref, highway, subclass, brunnel, level, layer, sac_scale, indoor, network_type,
                            route_1, route_2, route_3, route_4, route_5, route_6
           ) AS cluster,
           -- ST_ClusterDBSCAN returns an increasing integer as the cluster-ids within each partition starting at 0.
           -- This leads to clusters having the same ID across multiple partitions therefore we generate a
           -- Cluster-Group-ID by utilizing the DENSE_RANK function sorted over the partition columns.
           DENSE_RANK() OVER (
               ORDER BY tags, ref, highway, subclass, brunnel, level, layer, sac_scale, indoor, network_type, route_1,
                        route_2, route_3, route_4, route_5, route_6
           ) as cluster_group
    FROM linestrings_to_merge;

    -- Drop temporary tables early to save resources
    DROP TABLE linestrings_to_merge;

    -- Create index on cluster columns and analyze the created table to speed up subsequent queries
    CREATE INDEX ON clustered_linestrings_to_merge (cluster_group, cluster);
    ANALYZE clustered_linestrings_to_merge;


    WITH inserted_linestrings AS (
        -- Merge LineStrings of each cluster and insert them
        INSERT INTO osm_transportation_name_linestring(source, geometry, new_source_ids, old_source_ids, tags, ref,
                                                       highway, subclass, brunnel, sac_scale, "level", layer, indoor,
                                                       network, route_1, route_2, route_3, route_4, route_5, route_6,
                                                       z_order, route_rank)
        SELECT 0 AS source, (ST_Dump(ST_LineMerge(ST_Union(geometry)))).geom AS geometry,
               -- We use St_Union instead of St_Collect to ensure no overlapping points exist within the geometries
               -- to merge. https://postgis.net/docs/ST_Union.html
               -- ST_LineMerge only merges across singular intersections and groups its output into a MultiLineString
               -- if more than two LineStrings form an intersection or no intersection could be found.
               -- https://postgis.net/docs/ST_LineMerge.html
               -- In order to not end up with a mixture of LineStrings and MultiLineStrings we dump eventual
               -- MultiLineStrings via ST_Dump. https://postgis.net/docs/ST_Dump.html
               coalesce( array_agg(osm_id) FILTER (WHERE osm_id IS NOT NULL), '{}' )::BIGINT[] AS new_source_ids,
               array_cat_agg(source_ids)::BIGINT[] as old_source_ids,
               tags, ref, highway, subclass, brunnel, sac_scale, level, layer,
               indoor, network_type, route_1, route_2, route_3, route_4, route_5, route_6,
               min(z_order) AS z_order, min(route_rank) AS route_rank
        FROM clustered_linestrings_to_merge
        GROUP BY cluster_group, cluster, tags, ref, highway, subclass, brunnel, level, layer, sac_scale, indoor,
                 network_type, route_1, route_2, route_3, route_4, route_5, route_6
        RETURNING source, id, new_source_ids, old_source_ids, geometry
    )
    -- Store OSM-IDs of Source-LineStrings by intersecting Merged-LineStrings with their sources.
    -- This is required because ST_LineMerge only merges across singular intersections and groups its output into a
    -- MultiLineString if more than two LineStrings form an intersection or no intersection could be found.
    INSERT INTO osm_transportation_name_linestring_source_ids (source, id, source_id)
    SELECT m.source, m.id, source_id
    FROM (
        SELECT source, id, source_id, geometry
        FROM inserted_linestrings
        CROSS JOIN LATERAL (
            SELECT DISTINCT all_source_ids.source_id
            FROM unnest(
                array_cat(inserted_linestrings.new_source_ids, inserted_linestrings.old_source_ids)
            ) AS all_source_ids(source_id)
        ) source_ids
    ) m
    JOIN osm_transportation_name_network s ON (m.source_id = s.osm_id)
    WHERE ST_Intersects(s.geometry, m.geometry)
    ON CONFLICT (source, id, source_id) DO NOTHING;

    -- Cleanup remaining table
    DROP TABLE clustered_linestrings_to_merge;

    -- Restore temporary Merged-LineString to Source-LineStrings-ID columns
    UPDATE osm_transportation_name_linestring SET new_source_ids = NULL WHERE new_source_ids IS NOT NULL;
    UPDATE osm_transportation_name_linestring SET old_source_ids = NULL WHERE old_source_ids IS NOT NULL;

    -- noinspection SqlWithoutWhere
    DELETE FROM transportation_name.name_changes;
    -- noinspection SqlWithoutWhere
    DELETE FROM transportation_name.updates_name;

    RAISE LOG 'Refresh transportation_name done in %', age(clock_timestamp(), t);

    -- Update gen1, gen2, gen3 and gen4 tables
    PERFORM update_transportation_name_linestring_gen(FALSE);

    RETURN NULL;
END;
$BODY$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transportation_name.refresh_shipway_linestring() RETURNS trigger AS
$BODY$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh transportation_name shiwpway';

    -- REFRESH osm_transportation_name_linestring from osm_shipway_linestring

    -- Analyze tracking and source tables before performing update
    ANALYZE transportation_name.shipway_changes;
    ANALYZE osm_shipway_linestring;

    -- Fetch updated and deleted Merged-LineString from relation-table filtering for each Merged-LineString which
    -- contains an updated Source-LineString.
    -- Additionally attach a list of Source-LineString-IDs to each Merged-LineString in order to unnest them later.
    CREATE TEMPORARY TABLE affected_merged_linestrings AS
    SELECT m.id, array_agg(source_id) AS source_ids
    FROM osm_transportation_name_linestring_source_ids m
    WHERE m.source = 1 AND EXISTS(
        SELECT NULL
        FROM transportation_name.shipway_changes c
        WHERE c.is_old IS TRUE AND c.osm_id = m.source_id
    )
    GROUP BY id;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE affected_merged_linestrings;

    -- Delete all Merged-LineStrings which contained an updated or deleted Source-LineString
    DELETE
    FROM osm_transportation_name_linestring m
    USING affected_merged_linestrings
    WHERE affected_merged_linestrings.id = m.id;
    DELETE
    FROM osm_transportation_name_linestring_source_ids m
    USING affected_merged_linestrings
    WHERE affected_merged_linestrings.id = m.id;

    -- Analyze the tables affected by the delete-query in order to speed up subsequent queries
    ANALYZE osm_transportation_name_linestring;
    ANALYZE osm_transportation_name_linestring_source_ids;

    -- Create a table containing all LineStrings which should be merged
    CREATE TEMPORARY TABLE linestrings_to_merge AS
    -- Add all Source-LineStrings affected by this update
    SELECT osm_id, NULL::INTEGER AS id, NULL::BIGINT[] AS source_ids, geometry,
           transportation_name_tags(
               NULL::geometry, tags, name, name_en, name_de
           ) AS tags, shipway AS subclass, layer, z_order
    FROM (
        -- Get Source-LineString-IDs of deleted or updated elements
        SELECT unnest(affected_merged_linestrings.source_ids)::bigint AS source_id
        FROM affected_merged_linestrings
        UNION
        -- Get Source-LineString-IDs of inserted or updated elements
        SELECT osm_id AS source_id FROM transportation_name.shipway_changes WHERE is_old IS FALSE
        ORDER BY source_id
    ) affected_source_linestrings
    JOIN osm_shipway_linestring ON (
        affected_source_linestrings.source_id = osm_shipway_linestring.osm_id
    )
    WHERE name <> '';

    -- Drop temporary tables early to save resources
    DROP TABLE affected_merged_linestrings;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE linestrings_to_merge;

    -- Add all Merged-LineStrings intersecting with Source-LineStrings affected by this update
    INSERT INTO linestrings_to_merge
    SELECT NULL::BIGINT AS osm_id, m.id,
           ARRAY(
               SELECT s.source_id
               FROM osm_transportation_name_linestring_source_ids s
               WHERE s.source = 1 AND m.id = s.id
           )::BIGINT[] AS source_ids,
           m.geometry, m.tags, m.subclass, m.layer, m.z_order
    FROM linestrings_to_merge
    JOIN osm_transportation_name_linestring m ON (ST_Intersects(linestrings_to_merge.geometry, m.geometry))
    WHERE m.source = 1;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE linestrings_to_merge;

    -- Delete all Merged-LineStrings intersecting with Source-LineStrings affected by this update.
    -- We can use the linestrings_to_merge table since Source-LineStrings affected by this update and present in the
    -- table will have their ID-Column set to NULL by the previous query.
    DELETE
    FROM osm_transportation_name_linestring m
    USING linestrings_to_merge
    WHERE m.id = linestrings_to_merge.id;
    DELETE
    FROM osm_transportation_name_linestring_source_ids m
    USING linestrings_to_merge
    WHERE  m.id = linestrings_to_merge.id;

    -- Create table containing all LineStrings to and create clusters of intersecting LineStrings partitioned by their
    -- groups
    CREATE TEMPORARY TABLE clustered_linestrings_to_merge AS
    SELECT *,
           -- Get intersecting clusters by setting minimum distance to 0 and minimum intersecting points to 1.
           -- https://postgis.net/docs/ST_ClusterDBSCAN.html
           ST_ClusterDBSCAN(geometry, 0, 1) OVER (PARTITION BY tags, subclass, layer) AS cluster,
           -- ST_ClusterDBSCAN returns an increasing integer as the cluster-ids within each partition starting at 0.
           -- This leads to clusters having the same ID across multiple partitions therefore we generate a
           -- Cluster-Group-ID by utilizing the DENSE_RANK function sorted over the partition columns.
           DENSE_RANK() OVER (ORDER BY tags, subclass, layer) as cluster_group
    FROM linestrings_to_merge;

    -- Drop temporary tables early to save resources
    DROP TABLE linestrings_to_merge;

    -- Create index on cluster columns and analyze the created table to speed up subsequent queries
    CREATE INDEX ON clustered_linestrings_to_merge (cluster_group, cluster);
    ANALYZE clustered_linestrings_to_merge;


    WITH inserted_linestrings AS (
        -- Merge LineStrings of each cluster and insert them
        INSERT INTO osm_transportation_name_linestring(source, geometry, new_source_ids, old_source_ids, tags, highway,
                                                       subclass, z_order)
        SELECT 1 AS source, (ST_Dump(ST_LineMerge(ST_Union(geometry)))).geom AS geometry,
               -- We use St_Union instead of St_Collect to ensure no overlapping points exist within the geometries
               -- to merge. https://postgis.net/docs/ST_Union.html
               -- ST_LineMerge only merges across singular intersections and groups its output into a MultiLineString
               -- if more than two LineStrings form an intersection or no intersection could be found.
               -- https://postgis.net/docs/ST_LineMerge.html
               -- In order to not end up with a mixture of LineStrings and MultiLineStrings we dump eventual
               -- MultiLineStrings via ST_Dump. https://postgis.net/docs/ST_Dump.html
               coalesce( array_agg(osm_id) FILTER (WHERE osm_id IS NOT NULL), '{}' )::BIGINT[] AS new_source_ids,
               array_cat_agg(source_ids)::BIGINT[] as old_source_ids,
               tags, 'shipway' AS highway, subclass, min(z_order) AS z_order
        FROM clustered_linestrings_to_merge
        GROUP BY cluster_group, cluster, tags, subclass, layer
        RETURNING source, id, new_source_ids, old_source_ids, geometry
    )
    -- Store OSM-IDs of Source-LineStrings by intersecting Merged-LineStrings with their sources.
    -- This is required because ST_LineMerge only merges across singular intersections and groups its output into a
    -- MultiLineString if more than two LineStrings form an intersection or no intersection could be found.
    INSERT INTO osm_transportation_name_linestring_source_ids (source, id, source_id)
    SELECT m.source, m.id, source_id
    FROM (
        SELECT source, id, source_id, geometry
        FROM inserted_linestrings
        CROSS JOIN LATERAL (
            SELECT DISTINCT all_source_ids.source_id
            FROM unnest(
                array_cat(inserted_linestrings.new_source_ids, inserted_linestrings.old_source_ids)
            ) AS all_source_ids(source_id)
        ) source_ids
    ) m
    JOIN osm_shipway_linestring s ON (m.source_id = s.osm_id)
    WHERE ST_Intersects(s.geometry, m.geometry)
    ON CONFLICT (source, id, source_id) DO NOTHING;

    -- Cleanup remaining table
    DROP TABLE clustered_linestrings_to_merge;

    -- Restore temporary Merged-LineString to Source-LineStrings-ID columns
    UPDATE osm_transportation_name_linestring SET new_source_ids = NULL WHERE new_source_ids IS NOT NULL;
    UPDATE osm_transportation_name_linestring SET old_source_ids = NULL WHERE old_source_ids IS NOT NULL;

    -- noinspection SqlWithoutWhere
    DELETE FROM transportation_name.shipway_changes;
    -- noinspection SqlWithoutWhere
    DELETE FROM transportation_name.updates_shipway;

    RAISE LOG 'Refresh transportation_name shipway done in %', age(clock_timestamp(), t);

    -- Update gen1, gen2, gen3 and gen4 tables
    PERFORM update_transportation_name_linestring_gen(FALSE);

    RETURN NULL;
END;
$BODY$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transportation_name.refresh_aerialway_linestring() RETURNS trigger AS
$BODY$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh transportation_name aerialway';

    -- REFRESH osm_transportation_name_linestring from osm_aerialway_linestring

    -- Analyze tracking and source tables before performing update
    ANALYZE transportation_name.aerialway_changes;
    ANALYZE osm_aerialway_linestring;

    -- Fetch updated and deleted Merged-LineString from relation-table filtering for each Merged-LineString which
    -- contains an updated Source-LineString.
    -- Additionally attach a list of Source-LineString-IDs to each Merged-LineString in order to unnest them later.
    CREATE TEMPORARY TABLE affected_merged_linestrings AS
    SELECT m.id, array_agg(source_id) AS source_ids
    FROM osm_transportation_name_linestring_source_ids m
    WHERE m.source = 2 AND EXISTS(
        SELECT NULL
        FROM transportation_name.aerialway_changes c
        WHERE c.is_old IS TRUE AND c.osm_id = m.source_id
    )
    GROUP BY id;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE affected_merged_linestrings;

    -- Delete all Merged-LineStrings which contained an updated or deleted Source-LineString
    DELETE
    FROM osm_transportation_name_linestring m
    USING affected_merged_linestrings
    WHERE affected_merged_linestrings.id = m.id;
    DELETE
    FROM osm_transportation_name_linestring_source_ids m
    USING affected_merged_linestrings
    WHERE affected_merged_linestrings.id = m.id;

    -- Analyze the tables affected by the delete-query in order to speed up subsequent queries
    ANALYZE osm_transportation_name_linestring;
    ANALYZE osm_transportation_name_linestring_source_ids;

    -- Create a table containing all LineStrings which should be merged
    CREATE TEMPORARY TABLE linestrings_to_merge AS
    -- Add all Source-LineStrings affected by this update
    SELECT osm_id, NULL::INTEGER AS id, NULL::BIGINT[] AS source_ids, geometry,
           transportation_name_tags(
               NULL::geometry, tags, name, name_en, name_de
           ) AS tags, aerialway AS subclass, layer, z_order
    FROM (
        -- Get Source-LineString-IDs of deleted or updated elements
        SELECT unnest(affected_merged_linestrings.source_ids)::bigint AS source_id
        FROM affected_merged_linestrings
        UNION
        -- Get Source-LineString-IDs of inserted or updated elements
        SELECT osm_id AS source_id FROM transportation_name.aerialway_changes WHERE is_old IS FALSE
        ORDER BY source_id
    ) affected_source_linestrings
    JOIN osm_aerialway_linestring ON (
        affected_source_linestrings.source_id = osm_aerialway_linestring.osm_id
    )
    WHERE name <> '';

    -- Drop temporary tables early to save resources
    DROP TABLE affected_merged_linestrings;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE linestrings_to_merge;

    -- Add all Merged-LineStrings intersecting with Source-LineStrings affected by this update
    INSERT INTO linestrings_to_merge
    SELECT NULL::BIGINT AS osm_id, m.id,
           ARRAY(
               SELECT s.source_id
               FROM osm_transportation_name_linestring_source_ids s
               WHERE s.source = 2 AND m.id = s.id
           )::BIGINT[] AS source_ids,
           m.geometry, m.tags, m.subclass, m.layer, m.z_order
    FROM linestrings_to_merge
    JOIN osm_transportation_name_linestring m ON (ST_Intersects(linestrings_to_merge.geometry, m.geometry))
    WHERE m.source = 2;

    -- Analyze the created table to speed up subsequent queries
    ANALYZE linestrings_to_merge;

    -- Delete all Merged-LineStrings intersecting with Source-LineStrings affected by this update.
    -- We can use the linestrings_to_merge table since Source-LineStrings affected by this update and present in the
    -- table will have their ID-Column set to NULL by the previous query.
    DELETE
    FROM osm_transportation_name_linestring m
    USING linestrings_to_merge
    WHERE m.id = linestrings_to_merge.id;
    DELETE
    FROM osm_transportation_name_linestring_source_ids m
    USING linestrings_to_merge
    WHERE m.id = linestrings_to_merge.id;

    -- Create table containing all LineStrings to and create clusters of intersecting LineStrings partitioned by their
    -- groups
    CREATE TEMPORARY TABLE clustered_linestrings_to_merge AS
    SELECT *,
           -- Get intersecting clusters by setting minimum distance to 0 and minimum intersecting points to 1.
           -- https://postgis.net/docs/ST_ClusterDBSCAN.html
           ST_ClusterDBSCAN(geometry, 0, 1) OVER (PARTITION BY tags, subclass, layer) AS cluster,
           -- ST_ClusterDBSCAN returns an increasing integer as the cluster-ids within each partition starting at 0.
           -- This leads to clusters having the same ID across multiple partitions therefore we generate a
           -- Cluster-Group-ID by utilizing the DENSE_RANK function sorted over the partition columns.
           DENSE_RANK() OVER (ORDER BY tags, subclass, layer) as cluster_group
    FROM linestrings_to_merge;

    -- Drop temporary tables early to save resources
    DROP TABLE linestrings_to_merge;

    -- Create index on cluster columns and analyze the created table to speed up subsequent queries
    CREATE INDEX ON clustered_linestrings_to_merge (cluster_group, cluster);
    ANALYZE clustered_linestrings_to_merge;


    WITH inserted_linestrings AS (
        -- Merge LineStrings of each cluster and insert them
        INSERT INTO osm_transportation_name_linestring(source, geometry, new_source_ids, old_source_ids, tags, highway,
                                                       subclass, z_order)
        SELECT 2 AS source, (ST_Dump(ST_LineMerge(ST_Union(geometry)))).geom AS geometry,
               -- We use St_Union instead of St_Collect to ensure no overlapping points exist within the geometries
               -- to merge. https://postgis.net/docs/ST_Union.html
               -- ST_LineMerge only merges across singular intersections and groups its output into a MultiLineString
               -- if more than two LineStrings form an intersection or no intersection could be found.
               -- https://postgis.net/docs/ST_LineMerge.html
               -- In order to not end up with a mixture of LineStrings and MultiLineStrings we dump eventual
               -- MultiLineStrings via ST_Dump. https://postgis.net/docs/ST_Dump.html
               coalesce( array_agg(osm_id) FILTER (WHERE osm_id IS NOT NULL), '{}' )::BIGINT[] AS new_source_ids,
               array_cat_agg(source_ids)::BIGINT[] as old_source_ids,
               tags, 'aerialway' AS highway, subclass, min(z_order) AS z_order
        FROM clustered_linestrings_to_merge
        GROUP BY cluster_group, cluster, tags, subclass, layer
        RETURNING source, id, new_source_ids, old_source_ids, geometry
    )
    -- Store OSM-IDs of Source-LineStrings by intersecting Merged-LineStrings with their sources.
    -- This is required because ST_LineMerge only merges across singular intersections and groups its output into a
    -- MultiLineString if more than two LineStrings form an intersection or no intersection could be found.
    INSERT INTO osm_transportation_name_linestring_source_ids (source, id, source_id)
    SELECT m.source, m.id, source_id
    FROM (
        SELECT source, id, source_id, geometry
        FROM inserted_linestrings
        CROSS JOIN LATERAL (
            SELECT DISTINCT all_source_ids.source_id
            FROM unnest(
                array_cat(inserted_linestrings.new_source_ids, inserted_linestrings.old_source_ids)
            ) AS all_source_ids(source_id)
        ) source_ids
    ) m
    JOIN osm_aerialway_linestring s ON (m.source_id = s.osm_id)
    WHERE ST_Intersects(s.geometry, m.geometry)
    ON CONFLICT (source, id, source_id) DO NOTHING;

    -- Cleanup remaining table
    DROP TABLE clustered_linestrings_to_merge;

    -- Restore temporary Merged-LineString to Source-LineStrings-ID columns
    UPDATE osm_transportation_name_linestring SET new_source_ids = NULL WHERE new_source_ids IS NOT NULL;
    UPDATE osm_transportation_name_linestring SET old_source_ids = NULL WHERE old_source_ids IS NOT NULL;

    -- noinspection SqlWithoutWhere
    DELETE FROM transportation_name.aerialway_changes;
    -- noinspection SqlWithoutWhere
    DELETE FROM transportation_name.updates_aerialway;

    RAISE LOG 'Refresh transportation_name aerialway done in %', age(clock_timestamp(), t);

    -- Update gen1, gen2, gen3 and gen4 tables
    PERFORM update_transportation_name_linestring_gen(FALSE);

    RETURN NULL;
END;
$BODY$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store_transportation_name_network
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_transportation_name_network
    FOR EACH ROW
EXECUTE PROCEDURE transportation_name.name_network_store();

CREATE TRIGGER trigger_store_transportation_name_shipway
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_shipway_linestring
    FOR EACH ROW
EXECUTE PROCEDURE transportation_name.name_shipway_store();

CREATE TRIGGER trigger_store_transportation_name_aerialway
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_aerialway_linestring
    FOR EACH ROW
EXECUTE PROCEDURE transportation_name.name_aerialway_store();

CREATE TRIGGER trigger_store_transportation_name_linestring
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_transportation_name_linestring
    FOR EACH ROW
EXECUTE PROCEDURE transportation_name.name_linestring_store();

CREATE TRIGGER trigger_flag_name
    AFTER INSERT
    ON transportation_name.name_changes
    FOR EACH STATEMENT
EXECUTE PROCEDURE transportation_name.flag_name();

CREATE TRIGGER trigger_flag_shipway
    AFTER INSERT
    ON transportation_name.shipway_changes
    FOR EACH STATEMENT
EXECUTE PROCEDURE transportation_name.flag_shipway();

CREATE TRIGGER trigger_flag_aerialway
    AFTER INSERT
    ON transportation_name.aerialway_changes
    FOR EACH STATEMENT
EXECUTE PROCEDURE transportation_name.flag_aerialway();

CREATE CONSTRAINT TRIGGER trigger_refresh_name
    AFTER INSERT
    ON transportation_name.updates_name
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE transportation_name.refresh_name();

CREATE CONSTRAINT TRIGGER trigger_refresh_shipway
    AFTER INSERT
    ON transportation_name.updates_shipway
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE transportation_name.refresh_shipway_linestring();

CREATE CONSTRAINT TRIGGER trigger_refresh_aerialway
    AFTER INSERT
    ON transportation_name.updates_aerialway
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE transportation_name.refresh_aerialway_linestring();

-- Layer transportation_name - ./transportation_name.sql

-- etldoc: layer_transportation_name[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="layer_transportation_name | <z6> z6 | <z7> z7 | <z8> z8 |<z9> z9 |<z10> z10 |<z11> z11 |<z12> z12|<z13> z13|<z14_> z14+" ] ;

CREATE OR REPLACE FUNCTION layer_transportation_name(bbox geometry, zoom_level integer)
    RETURNS TABLE
            (
                geometry        geometry,
                name            text,
                name_en         text,
                name_de         text,
                tags            hstore,
                ref             text,
                ref_length      int,
                network         text,
                route_1_network text,
                route_1_ref     text,
                route_1_name    text,
                route_1_colour  text,
                route_2_network text,
                route_2_ref     text,
                route_2_name    text,
                route_2_colour  text,
                route_3_network text,
                route_3_ref     text,
                route_3_name    text,
                route_3_colour  text,
                route_4_network text,
                route_4_ref     text,
                route_4_name    text,
                route_4_colour  text,
                route_5_network text,
                route_5_ref     text,
                route_5_name    text,
                route_5_colour  text,
                route_6_network text,
                route_6_ref     text,
                route_6_name    text,
                route_6_colour  text,
                class           text,
                subclass        text,
                brunnel         text,
                layer           int,
                level           int,
                indoor          int
            )
AS
$$
SELECT geometry,
       tags->'name' AS name,
       COALESCE(tags->'name:en', tags->'name') AS name_en,
       COALESCE(tags->'name:de', tags->'name', tags->'name:en') AS name_de,
       tags,
       ref,
       NULLIF(LENGTH(ref), 0) AS ref_length,
       CASE
           WHEN network IS NOT NULL
               THEN network::text
           WHEN length(coalesce(ref, '')) > 0
               THEN 'road'
           END AS network,
       route_1->'network' AS route_1_network,
       route_1->'ref' AS route_1_ref,
       route_1->'name' AS route_1_name,
       route_1->'colour' AS route_1_colour,

       route_2->'network' AS route_2_network,
       route_2->'ref' AS route_2_ref,
       route_2->'name' AS route_2_name,
       route_2->'colour' AS route_2_colour,

       route_3->'network' AS route_3_network,
       route_3->'ref' AS route_3_ref,
       route_3->'name' AS route_3_name,
       route_3->'colour' AS route_3_colour,

       route_4->'network' AS route_4_network,
       route_4->'ref' AS route_4_ref,
       route_4->'name' AS route_4_name,
       route_4->'colour' AS route_4_colour,

       route_5->'network' AS route_5_network,
       route_5->'ref' AS route_5_ref,
       route_5->'name' AS route_5_name,
       route_5->'colour' AS route_5_colour,

       route_6->'network' AS route_6_network,
       route_6->'ref' AS route_6_ref,
       route_6->'name' AS route_6_name,
       route_6->'colour' AS route_6_colour,
       highway_class(highway, '', subclass) AS class,
       CASE
           WHEN highway IS NOT NULL AND highway_class(highway, '', subclass) = 'path'
               THEN highway
           ELSE subclass
           END AS subclass,
       NULLIF(brunnel, '') AS brunnel,
       NULLIF(layer, 0) AS layer,
       "level",
       CASE WHEN indoor = TRUE THEN 1 END AS indoor
FROM (

         -- etldoc: osm_transportation_name_linestring_gen4 ->  layer_transportation_name:z6
         SELECT geometry,
                tags,
                ref,
                highway,
                subclass,
                brunnel,
                network,
                route_1,
                route_2,
                route_3,
                route_4,
                route_5,
                route_6,
                z_order,
                NULL::int AS layer,
                NULL::int AS level,
                NULL::boolean AS indoor
         FROM osm_transportation_name_linestring_gen4
         WHERE zoom_level = 6
         UNION ALL

         -- etldoc: osm_transportation_name_linestring_gen3 ->  layer_transportation_name:z7
         SELECT geometry,
                tags,
                ref,
                highway,
                subclass,
                brunnel,
                network,
                route_1,
                route_2,
                route_3,
                route_4,
                route_5,
                route_6,
                z_order,
                NULL::int AS layer,
                NULL::int AS level,
                NULL::boolean AS indoor
         FROM osm_transportation_name_linestring_gen3
         WHERE ST_Length(geometry) > 20000 AND zoom_level = 7
         UNION ALL

         -- etldoc: osm_transportation_name_linestring_gen2 ->  layer_transportation_name:z8
         SELECT geometry,
                tags,
                ref,
                highway,
                subclass,
                brunnel,
                network,
                route_1,
                route_2,
                route_3,
                route_4,
                route_5,
                route_6,
                z_order,
                NULL::int AS layer,
                NULL::int AS level,
                NULL::boolean AS indoor
         FROM osm_transportation_name_linestring_gen2
         WHERE ST_Length(geometry) > 14000 AND zoom_level = 8
         UNION ALL

         -- etldoc: osm_transportation_name_linestring_gen1 ->  layer_transportation_name:z9
         -- etldoc: osm_transportation_name_linestring_gen1 ->  layer_transportation_name:z10
         -- etldoc: osm_transportation_name_linestring_gen1 ->  layer_transportation_name:z11
         SELECT geometry,
                tags,
                ref,
                highway,
                subclass,
                brunnel,
                network,
                route_1,
                route_2,
                route_3,
                route_4,
                route_5,
                route_6,
                z_order,
                NULL::int AS layer,
                NULL::int AS level,
                NULL::boolean AS indoor
         FROM osm_transportation_name_linestring_gen1
         WHERE ST_Length(geometry) > 8000 / POWER(2, zoom_level - 9) AND zoom_level BETWEEN 9 AND 11
         UNION ALL

         -- etldoc: osm_transportation_name_linestring ->  layer_transportation_name:z12
         SELECT geometry,
                "tags",
                ref,
                highway,
                subclass,
                brunnel,
                network,
                route_1, route_2, route_3, route_4, route_5, route_6,
                z_order,
                layer,
                "level",
                indoor
         FROM osm_transportation_name_linestring
         WHERE zoom_level = 12
           AND LineLabel(zoom_level, COALESCE(ref, tags->'name'), geometry)
           AND NOT highway_is_link(highway)
           AND
               CASE WHEN highway_class(highway, NULL::text, NULL::text) NOT IN ('path', 'minor') THEN TRUE
                    WHEN highway IN ('aerialway', 'unclassified', 'residential', 'shipway') THEN TRUE
                    WHEN route_rank = 1 THEN TRUE END

         UNION ALL

         -- etldoc: osm_transportation_name_linestring ->  layer_transportation_name:z13
         SELECT geometry,
                "tags",
                ref,
                highway,
                subclass,
                brunnel,
                network,
                route_1, route_2, route_3, route_4, route_5, route_6,
                z_order,
                layer,
                "level",
                indoor
         FROM osm_transportation_name_linestring
         WHERE zoom_level = 13
           AND LineLabel(zoom_level, COALESCE(ref, tags->'name'), geometry)
           AND
               CASE WHEN highway <> 'path' THEN TRUE
                    WHEN highway = 'path' AND (
                                                   tags->'name' <> ''
                                                OR network IS NOT NULL
                                                OR sac_scale <> ''
                                                OR route_rank <= 2
                                              ) THEN TRUE
               END

         UNION ALL

         -- etldoc: osm_transportation_name_linestring ->  layer_transportation_name:z14_
         SELECT geometry,
                "tags",
                ref,
                highway,
                subclass,
                brunnel,
                network,
                route_1, route_2, route_3, route_4, route_5, route_6,
                z_order,
                layer,
                "level",
                indoor
         FROM osm_transportation_name_linestring
         WHERE zoom_level >= 14
         UNION ALL

         -- etldoc: osm_highway_point ->  layer_transportation_name:z10
         SELECT
		p.geometry,
                p.tags,
                p.ref,
                (
                  SELECT highest_highway(l.tags->'highway')
                    FROM osm_highway_linestring l
                    WHERE ST_Intersects(p.geometry,l.geometry)
                ) AS class,
                'junction'::text AS subclass,
                NULL AS brunnel,
                NULL AS network,
                NULL::hstore AS route_1,
                NULL::hstore AS route_2,
                NULL::hstore AS route_3,
                NULL::hstore AS route_4,
                NULL::hstore AS route_5,
                NULL::hstore AS route_6,
                z_order,
                layer,
                NULL::int AS level,
                NULL::boolean AS indoor
         FROM osm_highway_point p
         WHERE highway = 'motorway_junction' AND zoom_level >= 10
     ) AS zoom_levels
WHERE geometry && bbox
ORDER BY z_order ASC;
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;

DO $$ BEGIN RAISE NOTICE 'Finished layer transportation_name'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer boundary'; END$$;

DO $$ BEGIN
    PERFORM 'osm_border_linestring'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "boundary"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_10m_admin_0_countries'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "boundary"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_10m_admin_0_boundary_lines_land'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "boundary"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_10m_admin_1_states_provinces_lines'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "boundary"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_50m_admin_0_boundary_lines_land'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "boundary"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_110m_admin_0_boundary_lines_land'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "boundary"';
END;
$$ LANGUAGE 'plpgsql';

-- Layer boundary - ./update_boundary_polygon.sql

ALTER TABLE osm_boundary_polygon
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_boundary_polygon_gen_z13
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_boundary_polygon_gen_z12
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_boundary_polygon_gen_z11
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_boundary_polygon_gen_z10
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_boundary_polygon_gen_z9
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_boundary_polygon_gen_z8
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_boundary_polygon_gen_z7
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_boundary_polygon_gen_z6
    ADD COLUMN IF NOT EXISTS geometry_point geometry;
ALTER TABLE osm_boundary_polygon_gen_z5
    ADD COLUMN IF NOT EXISTS geometry_point geometry;

DROP TRIGGER IF EXISTS update_row ON osm_boundary_polygon;
DROP TRIGGER IF EXISTS update_row ON osm_boundary_polygon_gen_z13;
DROP TRIGGER IF EXISTS update_row ON osm_boundary_polygon_gen_z12;
DROP TRIGGER IF EXISTS update_row ON osm_boundary_polygon_gen_z11;
DROP TRIGGER IF EXISTS update_row ON osm_boundary_polygon_gen_z10;
DROP TRIGGER IF EXISTS update_row ON osm_boundary_polygon_gen_z9;
DROP TRIGGER IF EXISTS update_row ON osm_boundary_polygon_gen_z8;
DROP TRIGGER IF EXISTS update_row ON osm_boundary_polygon_gen_z7;
DROP TRIGGER IF EXISTS update_row ON osm_boundary_polygon_gen_z6;
DROP TRIGGER IF EXISTS update_row ON osm_boundary_polygon_gen_z5;

-- etldoc:  osm_boundary_polygon ->  osm_boundary_polygon
-- etldoc:  osm_boundary_polygon_gen_z13 ->  osm_boundary_polygon_gen_z13
-- etldoc:  osm_boundary_polygon_gen_z12 ->  osm_boundary_polygon_gen_z12
-- etldoc:  osm_boundary_polygon_gen_z11 ->  osm_boundary_polygon_gen_z11
-- etldoc:  osm_boundary_polygon_gen_z10 ->  osm_boundary_polygon_gen_z10
-- etldoc:  osm_boundary_polygon_gen_z9 ->  osm_boundary_polygon_gen_z9
-- etldoc:  osm_boundary_polygon_gen_z8 ->  osm_boundary_polygon_gen_z8
-- etldoc:  osm_boundary_polygon_gen_z7 ->  osm_boundary_polygon_gen_z7
-- etldoc:  osm_boundary_polygon_gen_z6 ->  osm_boundary_polygon_gen_z6
-- etldoc:  osm_boundary_polygon_gen_z5 ->  osm_boundary_polygon_gen_z5
CREATE OR REPLACE FUNCTION update_osm_boundary_polygon() RETURNS void AS
$$
BEGIN
    UPDATE osm_boundary_polygon
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_boundary_polygon_gen_z13
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_boundary_polygon_gen_z12
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_boundary_polygon_gen_z11
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_boundary_polygon_gen_z10
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_boundary_polygon_gen_z9
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_boundary_polygon_gen_z8
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_boundary_polygon_gen_z7
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_boundary_polygon_gen_z6
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

    UPDATE osm_boundary_polygon_gen_z5
    SET tags           = update_tags(tags, geometry),
        geometry_point = ST_PointOnSurface(geometry);

END;
$$ LANGUAGE plpgsql;

SELECT update_osm_boundary_polygon();
CREATE INDEX IF NOT EXISTS osm_boundary_polygon_point_geom_idx ON osm_boundary_polygon USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_boundary_polygon_gen_z13_point_geom_idx ON osm_boundary_polygon_gen_z13 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_boundary_polygon_gen_z12_point_geom_idx ON osm_boundary_polygon_gen_z12 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_boundary_polygon_gen_z11_point_geom_idx ON osm_boundary_polygon_gen_z11 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_boundary_polygon_gen_z10_point_geom_idx ON osm_boundary_polygon_gen_z10 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_boundary_polygon_gen_z9_point_geom_idx ON osm_boundary_polygon_gen_z9 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_boundary_polygon_gen_z8_point_geom_idx ON osm_boundary_polygon_gen_z8 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_boundary_polygon_gen_z7_point_geom_idx ON osm_boundary_polygon_gen_z7 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_boundary_polygon_gen_z6_point_geom_idx ON osm_boundary_polygon_gen_z6 USING gist (geometry_point);
CREATE INDEX IF NOT EXISTS osm_boundary_polygon_gen_z5_point_geom_idx ON osm_boundary_polygon_gen_z5 USING gist (geometry_point);

CREATE OR REPLACE FUNCTION update_osm_boundary_polygon_row()
    RETURNS trigger
AS
$$
BEGIN
    NEW.tags = update_tags(NEW.tags, NEW.geometry);
    NEW.geometry_point = ST_PointOnSurface(NEW.geometry);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_boundary_polygon
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_boundary_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_boundary_polygon_gen_z13
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_boundary_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_boundary_polygon_gen_z12
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_boundary_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_boundary_polygon_gen_z11
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_boundary_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_boundary_polygon_gen_z10
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_boundary_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_boundary_polygon_gen_z9
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_boundary_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_boundary_polygon_gen_z8
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_boundary_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_boundary_polygon_gen_z7
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_boundary_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_boundary_polygon_gen_z6
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_boundary_polygon_row();

CREATE TRIGGER update_row
    BEFORE INSERT OR UPDATE
    ON osm_boundary_polygon_gen_z5
    FOR EACH ROW
EXECUTE PROCEDURE update_osm_boundary_polygon_row();

-- Layer boundary - ./boundary_name.sql

DROP TABLE IF EXISTS osm_border_linestring_adm CASCADE;

-- etldoc: osm_border_linestring -> osm_border_linestring_adm
-- etldoc: osm_border_disp_linestring -> osm_border_linestring_adm
-- etldoc: ne_10m_admin_0_countries -> osm_border_linestring_adm
CREATE TABLE IF NOT EXISTS osm_border_linestring_adm AS ( 
  WITH 
    -- Prepare lines from osm to be merged
	multiline AS (
        SELECT osm_id,
               ST_Node(ST_Collect(geometry)) AS geometry,
               BOOL_OR(maritime) AS maritime,
               FALSE AS disputed
    	FROM osm_border_linestring
    	WHERE admin_level = 2 AND ST_Dimension(geometry) = 1
		    AND osm_id NOT IN (SELECT DISTINCT osm_id FROM osm_border_disp_linestring)
              GROUP BY osm_id
		),

	mergedline AS (
		SELECT osm_id,
      		     (ST_Dump(ST_LineMerge(geometry))).geom AS geometry,
			maritime,
			disputed
  		FROM multiline
		),
    -- Create polygons from all boundaries to preserve real shape of country
	polyg AS (
    	SELECT (ST_Dump(
        		 ST_Polygonize(geometry))).geom AS geometry  
    	FROM (
			SELECT (ST_Dump(
      				ST_LineMerge(geometry))).geom AS geometry
  			FROM (SELECT ST_Node(
                          ST_Collect(geometry)) AS geometry
    			FROM osm_border_linestring
    			WHERE admin_level = 2 AND ST_Dimension(geometry) = 1
                ) nodes
			) linemerge
  		), 

    centroids AS (
		SELECT polyg.geometry,
			   ne.adm0_a3
		FROM polyg,
			 ne_10m_admin_0_countries AS ne
		WHERE ST_Within(
			   ST_PointOnSurface(polyg.geometry), ne.geometry)
    	),

	country_osm_polyg AS  (
		SELECT country.adm0_a3,
			   border.geometry
  		FROM polyg border,
			 centroids country
  		WHERE ST_Within(country.geometry, border.geometry)
	),

	rights AS (
        SELECT osm_id,
			   adm0_r,
			   geometry,
			   maritime,
			   disputed
		FROM (
			SELECT a.osm_id AS osm_id,
                   b.adm0_a3 AS adm0_r,
                   a.geometry,
                   a.maritime,
                   a.disputed
			FROM mergedline AS a
			LEFT JOIN country_osm_polyg AS b
            -- Create short line on the right of the boundary (mergedline) and find state where line lies.
			ON ST_Within(
				ST_OffsetCurve(
				(ST_LineSubString(a.geometry, 0.3,0.3004)), 70, 'quad_segs=4 join=mitre'), b.geometry)
            ) line_rights
		)

  SELECT osm_id,
		 adm0_l,
		 adm0_r,
		 geometry,
		 maritime,
		 2::integer AS admin_level,
		 disputed
  FROM (
    SELECT r.osm_id AS osm_id,
           b.adm0_a3 AS adm0_l,
           r.adm0_r AS adm0_r,
           r.geometry,
           r.maritime,
           r.disputed
    FROM rights AS r
    LEFT JOIN country_osm_polyg AS b
      -- Create short line on the left of the boundary (mergedline) and find state where line lies.
      ON ST_Within(
        ST_OffsetCurve(
          (ST_LineSubString(r.geometry, 0.4,0.4004)), -70, 'quad_segs=4 join=mitre'), b.geometry)
    ) both_lines
);

CREATE INDEX IF NOT EXISTS osm_border_linestring_adm_geom_idx
  ON osm_border_linestring_adm
  USING GIST (geometry);

-- Layer boundary - ./boundary.sql

-- etldoc: osm_border_linestring -> osm_border_linestring_gen_z13
-- etldoc: osm_border_linestring_adm -> osm_border_linestring_gen_z13
-- etldoc: osm_border_disp_linestring -> osm_border_linestring_gen_z13
DROP MATERIALIZED VIEW IF EXISTS osm_border_linestring_gen_z13 CASCADE;
CREATE MATERIALIZED VIEW osm_border_linestring_gen_z13 AS
(
SELECT ST_Simplify(ST_Collect(geometry), ZRes(14)) AS geometry,
       MAX(adm0_l) AS adm0_l,
       MAX(adm0_r) AS adm0_r,
       MIN(admin_level) AS admin_level,
       BOOL_OR(disputed) AS disputed,
       MAX(name) AS name,
       MAX(claimed_by) AS claimed_by,
       BOOL_OR(maritime) AS maritime
FROM (
      -- All admin 3-10 boundaries
      SELECT osm_id,
             geometry,
             NULL::text AS adm0_l,
             NULL::text AS adm0_r,
             MIN(admin_level) AS admin_level,
             BOOL_OR(disputed)
                 OR BOOL_OR(dispute)
                 OR BOOL_OR(border_status = 'disputed')
                 OR BOOL_OR(disputed_by <> '') AS disputed,
             NULLIF(name, '') AS name,
             NULLIF(claimed_by, '') AS claimed_by,
             BOOL_OR(maritime) AS maritime
      FROM osm_border_linestring
      WHERE admin_level BETWEEN 3 AND 10
            AND type = 1 -- ways only
      GROUP BY osm_id, geometry, name, claimed_by

      UNION ALL

      -- All non-disputed admin 2 boundaries
      SELECT osm_id,
             geometry,
             adm0_l,
             adm0_r,
             admin_level,
             FALSE AS disputed,
             NULL::text AS name,
             NULL::text AS claimed_by,
             maritime
      FROM osm_border_linestring_adm

      UNION ALL

      -- All disputed admin 2 boundaries
      SELECT osm_id,
             geometry,
             NULL::text AS adm0_l,
             NULL::text AS adm0_r,
             2::int AS admin_level,
             TRUE AS disputed,
             NULLIF(name, '') AS name,
             NULLIF(claimed_by, '') AS claimed_by,
             maritime
      FROM osm_border_disp_linestring
      GROUP BY osm_id, geometry, name, claimed_by, maritime
     ) AS merged_boundary
GROUP by osm_id
)/* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_border_linestring_gen_z13_idx ON osm_border_linestring_gen_z13 USING gist (geometry);

-- etldoc: osm_border_linestring_gen_z13 -> osm_border_linestring_gen_z12
DROP MATERIALIZED VIEW IF EXISTS osm_border_linestring_gen_z12 CASCADE;
CREATE MATERIALIZED VIEW osm_border_linestring_gen_z12 AS
(
SELECT ST_Simplify(geometry, ZRes(13)) AS geometry, adm0_l, adm0_r, admin_level, disputed, name, claimed_by, maritime
FROM osm_border_linestring_gen_z13
WHERE admin_level BETWEEN 2 AND 10
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_border_linestring_gen_z12_idx ON osm_border_linestring_gen_z12 USING gist (geometry);

-- etldoc: osm_border_linestring_gen_z12 -> osm_border_linestring_gen_z11
DROP MATERIALIZED VIEW IF EXISTS osm_border_linestring_gen_z11 CASCADE;
CREATE MATERIALIZED VIEW osm_border_linestring_gen_z11 AS
(
SELECT ST_Simplify(geometry, ZRes(12)) AS geometry, adm0_l, adm0_r, admin_level, disputed, name, claimed_by, maritime
FROM osm_border_linestring_gen_z12
WHERE admin_level BETWEEN 2 AND 8
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_border_linestring_gen_z11_idx ON osm_border_linestring_gen_z11 USING gist (geometry);

-- etldoc: osm_border_linestring_gen_z11 -> osm_border_linestring_gen_z10
DROP MATERIALIZED VIEW IF EXISTS osm_border_linestring_gen_z10 CASCADE;
CREATE MATERIALIZED VIEW osm_border_linestring_gen_z10 AS
(
SELECT ST_Simplify(geometry, ZRes(11)) AS geometry, adm0_l, adm0_r, admin_level, disputed, name, claimed_by, maritime
FROM osm_border_linestring_gen_z11
WHERE admin_level BETWEEN 2 AND 6
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_border_linestring_gen_z10_idx ON osm_border_linestring_gen_z10 USING gist (geometry);

-- etldoc: osm_border_linestring_gen_z10 -> osm_border_linestring_gen_z9
DROP MATERIALIZED VIEW IF EXISTS osm_border_linestring_gen_z9 CASCADE;
CREATE MATERIALIZED VIEW osm_border_linestring_gen_z9 AS
(
SELECT ST_Simplify(geometry, ZRes(10)) AS geometry, adm0_l, adm0_r, admin_level, disputed, name, claimed_by, maritime
FROM osm_border_linestring_gen_z10
-- WHERE admin_level BETWEEN 2 AND 6
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_border_linestring_gen_z9_idx ON osm_border_linestring_gen_z9 USING gist (geometry);

-- etldoc: osm_border_linestring_gen_z9 -> osm_border_linestring_gen_z8
DROP MATERIALIZED VIEW IF EXISTS osm_border_linestring_gen_z8 CASCADE;
CREATE MATERIALIZED VIEW osm_border_linestring_gen_z8 AS
(
SELECT ST_Simplify(geometry, ZRes(9)) AS geometry, adm0_l, adm0_r, admin_level, disputed, name, claimed_by, maritime
FROM osm_border_linestring_gen_z9
WHERE admin_level BETWEEN 2 AND 4
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_border_linestring_gen_z8_idx ON osm_border_linestring_gen_z8 USING gist (geometry);

-- etldoc: osm_border_linestring_gen_z8 -> osm_border_linestring_gen_z7
DROP MATERIALIZED VIEW IF EXISTS osm_border_linestring_gen_z7 CASCADE;
CREATE MATERIALIZED VIEW osm_border_linestring_gen_z7 AS
(
SELECT ST_Simplify(geometry, ZRes(8)) AS geometry, adm0_l, adm0_r, admin_level, disputed, name, claimed_by, maritime
FROM osm_border_linestring_gen_z8
-- WHERE admin_level BETWEEN 2 AND 4
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_border_linestring_gen_z7_idx ON osm_border_linestring_gen_z7 USING gist (geometry);

-- etldoc: osm_border_linestring_gen_z7 -> osm_border_linestring_gen_z6
DROP MATERIALIZED VIEW IF EXISTS osm_border_linestring_gen_z6 CASCADE;
CREATE MATERIALIZED VIEW osm_border_linestring_gen_z6 AS
(
SELECT ST_Simplify(geometry, ZRes(7)) AS geometry, adm0_l, adm0_r, admin_level, disputed, name, claimed_by, maritime
FROM osm_border_linestring_gen_z7
-- WHERE admin_level BETWEEN 2 AND 4
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_border_linestring_gen_z6_idx ON osm_border_linestring_gen_z6 USING gist (geometry);

-- etldoc: osm_border_linestring_gen_z6 -> osm_border_linestring_gen_z5
DROP MATERIALIZED VIEW IF EXISTS osm_border_linestring_gen_z5 CASCADE;
CREATE MATERIALIZED VIEW osm_border_linestring_gen_z5 AS
(
SELECT ST_Simplify(geometry, ZRes(6)) AS geometry, adm0_l, adm0_r, admin_level, disputed, name, claimed_by, maritime
FROM osm_border_linestring_gen_z6
-- WHERE admin_level BETWEEN 2 AND 4
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_border_linestring_gen_z5_idx ON osm_border_linestring_gen_z5 USING gist (geometry);

-- etldoc: osm_border_linestring_gen_z5 -> osm_border_linestring_gen_z4
DROP MATERIALIZED VIEW IF EXISTS osm_border_linestring_gen_z4 CASCADE;
CREATE MATERIALIZED VIEW osm_border_linestring_gen_z4 AS
(
SELECT ST_Simplify(geometry, ZRes(5)) AS geometry, adm0_l, adm0_r, admin_level, disputed, name, claimed_by, maritime
FROM osm_border_linestring_gen_z5
WHERE admin_level = 2 AND maritime
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS osm_border_linestring_gen_z4_idx ON osm_border_linestring_gen_z4 USING gist (geometry);

-- ne_10m_admin_0_boundary_lines_land
-- etldoc: ne_10m_admin_0_boundary_lines_land -> ne_10m_admin_0_boundary_lines_land_gen_z4
DROP MATERIALIZED VIEW IF EXISTS ne_10m_admin_0_boundary_lines_land_gen_z4 CASCADE;
CREATE MATERIALIZED VIEW ne_10m_admin_0_boundary_lines_land_gen_z4 AS
(
SELECT ST_Simplify(geometry, ZRes(6)) as geometry,
       2 AS admin_level,
       (CASE WHEN featurecla LIKE 'Disputed%' THEN TRUE ELSE FALSE END) AS disputed,
       NULL::text AS disputed_name,
       NULL::text AS claimed_by,
       FALSE AS maritime
FROM ne_10m_admin_0_boundary_lines_land
WHERE featurecla <> 'Lease limit'
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_10m_admin_0_boundary_lines_land_gen_z4_idx ON ne_10m_admin_0_boundary_lines_land_gen_z4 USING gist (geometry);

-- etldoc: ne_10m_admin_0_boundary_lines_land -> ne_10m_admin_0_boundary_lines_land_disputed
DROP MATERIALIZED VIEW IF EXISTS ne_10m_admin_0_boundary_lines_land_disputed CASCADE;
CREATE MATERIALIZED VIEW ne_10m_admin_0_boundary_lines_land_disputed AS
(
SELECT geometry,
       2 AS admin_level,
       (CASE WHEN featurecla LIKE 'Disputed%' THEN TRUE ELSE FALSE END) AS disputed,
       NULL::text AS disputed_name,
       NULL::text AS claimed_by,
       FALSE AS maritime
FROM ne_10m_admin_0_boundary_lines_land
WHERE featurecla LIKE 'Disputed%' AND adm0_left = 'South Sudan' AND adm0_right = 'Kenya'
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_10m_admin_0_boundary_lines_land_disputed_idx ON ne_10m_admin_0_boundary_lines_land_disputed USING gist (geometry);

-- ne_10m_admin_1_states_provinces_lines
-- etldoc: ne_10m_admin_1_states_provinces_lines -> ne_10m_admin_1_states_provinces_lines_gen_z4
DROP MATERIALIZED VIEW IF EXISTS ne_10m_admin_1_states_provinces_lines_gen_z4 CASCADE;
CREATE MATERIALIZED VIEW ne_10m_admin_1_states_provinces_lines_gen_z4 AS
(
SELECT ST_Simplify(geometry, ZRes(6)) as geometry,
       4 AS admin_level,
       FALSE AS disputed,
       NULL::text AS disputed_name,
       NULL::text AS claimed_by,
       FALSE AS maritime,
       min_zoom
FROM ne_10m_admin_1_states_provinces_lines
WHERE min_zoom <= 7.7
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_10m_admin_1_states_provinces_lines_gen_z4_idx ON ne_10m_admin_1_states_provinces_lines_gen_z4 USING gist (geometry);


-- etldoc: ne_10m_admin_1_states_provinces_lines_gen_z4 -> ne_10m_admin_1_states_provinces_lines_gen_z3
DROP MATERIALIZED VIEW IF EXISTS ne_10m_admin_1_states_provinces_lines_gen_z3 CASCADE;
CREATE MATERIALIZED VIEW ne_10m_admin_1_states_provinces_lines_gen_z3 AS
(
SELECT ST_Simplify(geometry, ZRes(5)) as geometry,
       admin_level,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_10m_admin_1_states_provinces_lines_gen_z4
WHERE min_zoom <= 7
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_10m_admin_1_states_provinces_lines_gen_z3_idx ON ne_10m_admin_1_states_provinces_lines_gen_z3 USING gist (geometry);

-- etldoc: ne_10m_admin_1_states_provinces_lines_gen_z3 -> ne_10m_admin_1_states_provinces_lines_gen_z2
DROP MATERIALIZED VIEW IF EXISTS ne_10m_admin_1_states_provinces_lines_gen_z2 CASCADE;
CREATE MATERIALIZED VIEW ne_10m_admin_1_states_provinces_lines_gen_z2 AS
(
SELECT ST_Simplify(geometry, ZRes(4)) as geometry,
       admin_level,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_10m_admin_1_states_provinces_lines_gen_z3
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_10m_admin_1_states_provinces_lines_gen_z2_idx ON ne_10m_admin_1_states_provinces_lines_gen_z2 USING gist (geometry);

-- etldoc: ne_10m_admin_1_states_provinces_lines_gen_z2 -> ne_10m_admin_1_states_provinces_lines_gen_z1
DROP MATERIALIZED VIEW IF EXISTS ne_10m_admin_1_states_provinces_lines_gen_z1 CASCADE;
CREATE MATERIALIZED VIEW ne_10m_admin_1_states_provinces_lines_gen_z1 AS
(
SELECT ST_Simplify(geometry, ZRes(3)) as geometry,
       admin_level,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_10m_admin_1_states_provinces_lines_gen_z2
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_10m_admin_1_states_provinces_lines_gen_z1_idx ON ne_10m_admin_1_states_provinces_lines_gen_z1 USING gist (geometry);

-- ne_50m_admin_0_boundary_lines_land
-- etldoc: ne_50m_admin_0_boundary_lines_land -> ne_50m_admin_0_boundary_lines_land_gen_z3
DROP MATERIALIZED VIEW IF EXISTS ne_50m_admin_0_boundary_lines_land_gen_z3 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_admin_0_boundary_lines_land_gen_z3 AS
(
SELECT ST_Simplify(geometry, ZRes(5)) as geometry,
       2 AS admin_level,
       (CASE WHEN featurecla LIKE 'Disputed%' THEN TRUE ELSE FALSE END) AS disputed,
       NULL::text AS disputed_name,
       NULL::text AS claimed_by,
       FALSE AS maritime
FROM ne_50m_admin_0_boundary_lines_land
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_admin_0_boundary_lines_land_gen_z3_idx ON ne_50m_admin_0_boundary_lines_land_gen_z3 USING gist (geometry);

-- etldoc: ne_50m_admin_0_boundary_lines_land_gen_z3 -> ne_50m_admin_0_boundary_lines_land_gen_z2
DROP MATERIALIZED VIEW IF EXISTS ne_50m_admin_0_boundary_lines_land_gen_z2 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_admin_0_boundary_lines_land_gen_z2 AS
(
SELECT ST_Simplify(geometry, ZRes(4)) as geometry,
       admin_level,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_50m_admin_0_boundary_lines_land_gen_z3
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_admin_0_boundary_lines_land_gen_z2_idx ON ne_50m_admin_0_boundary_lines_land_gen_z2 USING gist (geometry);

-- etldoc: ne_50m_admin_0_boundary_lines_land_gen_z2 -> ne_50m_admin_0_boundary_lines_land_gen_z1
DROP MATERIALIZED VIEW IF EXISTS ne_50m_admin_0_boundary_lines_land_gen_z1 CASCADE;
CREATE MATERIALIZED VIEW ne_50m_admin_0_boundary_lines_land_gen_z1 AS
(
SELECT ST_Simplify(geometry, ZRes(3)) as geometry,
       admin_level,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_50m_admin_0_boundary_lines_land_gen_z2
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_50m_admin_0_boundary_lines_land_gen_z1_idx ON ne_50m_admin_0_boundary_lines_land_gen_z1 USING gist (geometry);

-- ne_110m_admin_0_boundary_lines_land
-- etldoc: ne_110m_admin_0_boundary_lines_land -> ne_110m_admin_0_boundary_lines_land_gen_z0
DROP MATERIALIZED VIEW IF EXISTS ne_110m_admin_0_boundary_lines_land_gen_z0 CASCADE;
CREATE MATERIALIZED VIEW ne_110m_admin_0_boundary_lines_land_gen_z0 AS
(
SELECT ST_Simplify(geometry, ZRes(2)) as geometry,
       2 AS admin_level,
       (CASE WHEN featurecla LIKE 'Disputed%' THEN TRUE ELSE FALSE END) AS disputed,
       NULL::text AS disputed_name,
       NULL::text AS claimed_by,
       FALSE AS maritime
FROM ne_110m_admin_0_boundary_lines_land
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */ ;
CREATE INDEX IF NOT EXISTS ne_110m_admin_0_boundary_lines_land_gen_z0_idx ON ne_110m_admin_0_boundary_lines_land_gen_z0 USING gist (geometry);


CREATE OR REPLACE FUNCTION edit_name(name varchar) RETURNS text AS
$$
SELECT CASE
           WHEN POSITION(' at ' IN name) > 0
               THEN replace(SUBSTRING(name, POSITION(' at ' IN name) + 4), ' ', '')
           ELSE replace(replace(name, ' ', ''), 'Extentof', '')
           END;
$$ LANGUAGE SQL IMMUTABLE
                -- STRICT
                PARALLEL SAFE
                ;


-- etldoc: ne_110m_admin_0_boundary_lines_land_gen_z0  -> boundary_z0
CREATE OR REPLACE VIEW boundary_z0 AS
(
SELECT geometry,
       admin_level,
       NULL::text AS adm0_l,
       NULL::text AS adm0_r,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_110m_admin_0_boundary_lines_land_gen_z0
    );

-- etldoc: ne_50m_admin_0_boundary_lines_land_gen_z1  -> boundary_z1
-- etldoc: ne_10m_admin_1_states_provinces_lines_gen_z1 -> boundary_z1
-- etldoc: ne_10m_admin_0_boundary_lines_land_disputed -> boundary_z1
-- etldoc: osm_border_disp_linestring_gen_z1 -> boundary_z1
DROP MATERIALIZED VIEW IF EXISTS boundary_z1 CASCADE;
CREATE MATERIALIZED VIEW boundary_z1 AS
(
SELECT geometry,
       admin_level,
       NULL::text AS adm0_l,
       NULL::text AS adm0_r,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_50m_admin_0_boundary_lines_land_gen_z1
UNION ALL
SELECT geometry,
       admin_level,
       NULL::text AS adm0_l,
       NULL::text AS adm0_r,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_10m_admin_1_states_provinces_lines_gen_z1
UNION ALL
SELECT geometry,
       admin_level,
       NULL::text AS adm0_l,
       NULL::text AS adm0_r,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_10m_admin_0_boundary_lines_land_disputed
    );
CREATE INDEX IF NOT EXISTS boundary_z1_idx ON boundary_z1 USING gist (geometry);


-- etldoc: ne_50m_admin_0_boundary_lines_land_gen_z2 -> boundary_z2
-- etldoc: ne_10m_admin_1_states_provinces_lines_gen_z2 -> boundary_z2
-- etldoc: ne_10m_admin_0_boundary_lines_land_disputed -> boundary_z2
-- etldoc: osm_border_disp_linestring_gen_z2 -> boundary_z2
DROP MATERIALIZED VIEW IF EXISTS boundary_z2 CASCADE;
CREATE MATERIALIZED VIEW boundary_z2 AS
(
SELECT geometry,
       admin_level,
       NULL::text AS adm0_l,
       NULL::text AS adm0_r,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_50m_admin_0_boundary_lines_land_gen_z2
UNION ALL
SELECT geometry,
       admin_level,
       NULL::text AS adm0_l,
       NULL::text AS adm0_r,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_10m_admin_1_states_provinces_lines_gen_z2
UNION ALL
SELECT geometry,
       admin_level,
       NULL::text AS adm0_l,
       NULL::text AS adm0_r,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_10m_admin_0_boundary_lines_land_disputed
    );
CREATE INDEX IF NOT EXISTS boundary_z2_idx ON boundary_z2 USING gist (geometry);

-- etldoc: ne_50m_admin_0_boundary_lines_land_gen_z3 -> boundary_z3
-- etldoc: ne_10m_admin_1_states_provinces_lines_gen_z3 -> boundary_z3
-- etldoc: ne_10m_admin_0_boundary_lines_land_disputed -> boundary_z3
-- etldoc: osm_border_disp_linestring_gen_z3 -> boundary_z3
DROP MATERIALIZED VIEW IF EXISTS boundary_z3 CASCADE;
CREATE MATERIALIZED VIEW boundary_z3 AS
(
SELECT geometry,
       admin_level,
       NULL::text AS adm0_l,
       NULL::text AS adm0_r,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_50m_admin_0_boundary_lines_land_gen_z3
UNION ALL
SELECT geometry,
       admin_level,
       NULL::text AS adm0_l,
       NULL::text AS adm0_r,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_10m_admin_1_states_provinces_lines_gen_z3
UNION ALL
SELECT geometry,
       admin_level,
       NULL::text AS adm0_l,
       NULL::text AS adm0_r,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_10m_admin_0_boundary_lines_land_disputed
    );
CREATE INDEX IF NOT EXISTS boundary_z3_idx ON boundary_z3 USING gist (geometry);

-- etldoc: ne_10m_admin_0_boundary_lines_land_gen_z4 -> boundary_z4
-- etldoc: ne_10m_admin_1_states_provinces_lines_gen_z4 -> boundary_z4
-- etldoc: osm_border_linestring_gen_z4 -> boundary_z4
DROP MATERIALIZED VIEW IF EXISTS boundary_z4 CASCADE;
CREATE MATERIALIZED VIEW boundary_z4 AS
(
SELECT geometry,
       admin_level,
       NULL::text AS adm0_l,
       NULL::text AS adm0_r,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_10m_admin_0_boundary_lines_land_gen_z4
UNION ALL
SELECT geometry,
       admin_level,
       NULL::text AS adm0_l,
       NULL::text AS adm0_r,
       disputed,
       disputed_name,
       claimed_by,
       maritime
FROM ne_10m_admin_1_states_provinces_lines_gen_z4
UNION ALL
SELECT geometry,
       admin_level,
       adm0_l,
       adm0_r,
       disputed,
       CASE WHEN disputed THEN edit_name(name) END AS disputed_name,
       claimed_by,
       maritime
FROM osm_border_linestring_gen_z4
    );
CREATE INDEX IF NOT EXISTS boundary_z4_idx ON boundary_z4 USING gist (geometry);

-- etldoc: osm_border_linestring_gen_z5 -> boundary_z5
CREATE OR REPLACE VIEW boundary_z5 AS
(
SELECT geometry,
       admin_level,
       adm0_l,
       adm0_r,
       disputed,
       CASE WHEN disputed THEN edit_name(name) END AS disputed_name,
       claimed_by,
       maritime
FROM osm_border_linestring_gen_z5
WHERE admin_level <= 4
    );

-- etldoc: osm_border_linestring_gen_z6 -> boundary_z6
CREATE OR REPLACE VIEW boundary_z6 AS
(
SELECT geometry,
       admin_level,
       adm0_l,
       adm0_r,
       disputed,
       CASE WHEN disputed THEN edit_name(name) END AS disputed_name,
       claimed_by,
       maritime
FROM osm_border_linestring_gen_z6
WHERE admin_level <= 4
    );

-- etldoc: osm_border_linestring_gen_z7 -> boundary_z7
CREATE OR REPLACE VIEW boundary_z7 AS
(
SELECT geometry,
       admin_level,
       adm0_l,
       adm0_r,
       disputed,
       CASE WHEN disputed THEN edit_name(name) END AS disputed_name,
       claimed_by,
       maritime
FROM osm_border_linestring_gen_z7
WHERE admin_level <= 6
    );

-- etldoc: osm_border_linestring_gen_z8 -> boundary_z8
CREATE OR REPLACE VIEW boundary_z8 AS
(
SELECT geometry,
       admin_level,
       adm0_l,
       adm0_r,
       disputed,
       CASE WHEN disputed THEN edit_name(name) END AS disputed_name,
       claimed_by,
       maritime
FROM osm_border_linestring_gen_z8
WHERE admin_level <= 6
    );

-- etldoc: osm_border_linestring_gen_z9 -> boundary_z9
CREATE OR REPLACE VIEW boundary_z9 AS
(
SELECT geometry,
       admin_level,
       adm0_l,
       adm0_r,
       disputed,
       CASE WHEN disputed THEN edit_name(name) END AS disputed_name,
       claimed_by,
       maritime
FROM osm_border_linestring_gen_z9
WHERE admin_level <= 6
    );

-- etldoc: osm_border_linestring_gen_z10 -> boundary_z10
CREATE OR REPLACE VIEW boundary_z10 AS
(
SELECT geometry,
       admin_level,
       adm0_l,
       adm0_r,
       disputed,
       CASE WHEN disputed THEN edit_name(name) END AS disputed_name,
       claimed_by,
       maritime
FROM osm_border_linestring_gen_z10
WHERE admin_level <= 6
    );

-- etldoc: osm_border_linestring_gen_z11 -> boundary_z11
CREATE OR REPLACE VIEW boundary_z11 AS
(
SELECT geometry,
       admin_level,
       adm0_l,
       adm0_r,
       disputed,
       CASE WHEN disputed THEN edit_name(name) END AS disputed_name,
       claimed_by,
       maritime
FROM osm_border_linestring_gen_z11
WHERE admin_level <= 8
    );

-- etldoc: osm_border_linestring_gen_z12 -> boundary_z12
CREATE OR REPLACE VIEW boundary_z12 AS
(
SELECT geometry,
       admin_level,
       adm0_l,
       adm0_r,
       disputed,
       CASE WHEN disputed THEN edit_name(name) END AS disputed_name,
       claimed_by,
       maritime
FROM osm_border_linestring_gen_z12
    );

-- etldoc: osm_border_linestring_gen_z13 -> boundary_z13
CREATE OR REPLACE VIEW boundary_z13 AS
(
SELECT geometry,
       admin_level,
       adm0_l,
       adm0_r,
       disputed,
       CASE WHEN disputed THEN edit_name(name) END AS disputed_name,
       claimed_by,
       maritime
FROM osm_border_linestring_gen_z13
    );

-- etldoc: layer_boundary[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="<sql> layer_boundary |<z0> z0 |<z1> z1 |<z2> z2 | <z3> z3 | <z4> z4 | <z5> z5 | <z6> z6 | <z7> z7 | <z8> z8 | <z9> z9 |<z10> z10 |<z11> z11 |<z12> z12|<z13> z13|<z14> z14+"]
CREATE OR REPLACE FUNCTION layer_boundary(bbox geometry, zoom_level int)
    RETURNS TABLE
            (
                geometry      geometry,
                admin_level   int,
                adm0_l        text,
                adm0_r        text,
                disputed      int,
                disputed_name text,
                claimed_by    text,
                maritime      int,
                class         text,
                name          text,
                tags          hstore
            )
AS
$$
SELECT geometry, admin_level, adm0_l, adm0_r, disputed::int, disputed_name, claimed_by, maritime::int, NULL::text, NULL::text, NULL::hstore
FROM (
         -- etldoc: boundary_z0 ->  layer_boundary:z0
         SELECT *
         FROM boundary_z0
         WHERE geometry && bbox
           AND zoom_level = 0
         UNION ALL
         -- etldoc: boundary_z1 ->  layer_boundary:z1
         SELECT *
         FROM boundary_z1
         WHERE geometry && bbox
           AND zoom_level = 1
         UNION ALL
         -- etldoc: boundary_z2 ->  layer_boundary:z2
         SELECT *
         FROM boundary_z2
         WHERE geometry && bbox
           AND zoom_level = 2
         UNION ALL
         -- etldoc: boundary_z3 ->  layer_boundary:z3
         SELECT *
         FROM boundary_z3
         WHERE geometry && bbox
           AND zoom_level = 3
         UNION ALL
         -- etldoc: boundary_z4 ->  layer_boundary:z4
         SELECT *
         FROM boundary_z4
         WHERE geometry && bbox
           AND zoom_level = 4
         UNION ALL
         -- etldoc: boundary_z5 ->  layer_boundary:z5
         SELECT *
         FROM boundary_z5
         WHERE geometry && bbox
           AND zoom_level = 5
         UNION ALL
         -- etldoc: boundary_z6 ->  layer_boundary:z6
         SELECT *
         FROM boundary_z6
         WHERE geometry && bbox
           AND zoom_level = 6
         UNION ALL
         -- etldoc: boundary_z7 ->  layer_boundary:z7
         SELECT *
         FROM boundary_z7
         WHERE geometry && bbox
           AND zoom_level = 7
         UNION ALL
         -- etldoc: boundary_z8 ->  layer_boundary:z8
         SELECT *
         FROM boundary_z8
         WHERE geometry && bbox
           AND zoom_level = 8
         UNION ALL
         -- etldoc: boundary_z9 ->  layer_boundary:z9
         SELECT *
         FROM boundary_z9
         WHERE geometry && bbox
           AND zoom_level = 9
         UNION ALL
         -- etldoc: boundary_z10 ->  layer_boundary:z10
         SELECT *
         FROM boundary_z10
         WHERE geometry && bbox
           AND zoom_level = 10
         UNION ALL
         -- etldoc: boundary_z11 ->  layer_boundary:z11
         SELECT *
         FROM boundary_z11
         WHERE geometry && bbox
           AND zoom_level = 11
         UNION ALL
         -- etldoc: boundary_z12 ->  layer_boundary:z12
         SELECT *
         FROM boundary_z12
         WHERE geometry && bbox
           AND zoom_level = 12
         UNION ALL
         -- etldoc: boundary_z13 -> layer_boundary:z13
         SELECT *
         FROM boundary_z13
         WHERE geometry && bbox
           AND zoom_level >= 13
     ) AS segment_zoom_levels

UNION ALL

SELECT geometry, NULL::int, NULL::text, NULL::text, NULL::int, NULL::text, NULL::text, NULL::int, class, name, tags
FROM (

         -- etldoc: osm_boundary_polygon_gen_z4 -> layer_boundary:z4
         SELECT geometry,
                boundary AS class,
                name,
                tags
         FROM osm_boundary_polygon_gen_z4
         WHERE zoom_level = 4
         AND geometry && bbox

         UNION ALL

         -- etldoc: osm_boundary_polygon_gen_z5 -> layer_boundary:z5
         SELECT geometry,
                boundary AS class,
                name,
                tags
         FROM osm_boundary_polygon_gen_z5
         WHERE zoom_level = 5
         AND geometry && bbox

         UNION ALL

         -- etldoc: osm_boundary_polygon_gen_z6 -> layer_boundary:z6
         SELECT geometry,
                boundary AS class,
                name,
                tags
         FROM osm_boundary_polygon_gen_z6
         WHERE zoom_level = 6
         AND geometry && bbox

         UNION ALL

         -- etldoc: osm_boundary_polygon_gen_z7 -> layer_boundary:z7
         SELECT geometry,
                boundary AS class,
                name,
                tags
         FROM osm_boundary_polygon_gen_z7
         WHERE zoom_level = 7
         AND geometry && bbox

         UNION ALL

         -- etldoc: osm_boundary_polygon_gen_z8 -> layer_boundary:z8
         SELECT geometry,
                boundary AS class,
                name,
                tags
         FROM osm_boundary_polygon_gen_z8
         WHERE zoom_level = 8
         AND geometry && bbox

         UNION ALL

         -- etldoc: osm_boundary_polygon_gen_z9 -> layer_boundary:z9
         SELECT geometry,
                boundary AS class,
                name,
                tags
         FROM osm_boundary_polygon_gen_z9
         WHERE zoom_level = 9
         AND geometry && bbox

         UNION ALL

         -- etldoc: osm_boundary_polygon_gen_z10 -> layer_boundary:z10
         SELECT geometry,
                boundary AS class,
                name,
                tags
         FROM osm_boundary_polygon_gen_z10
         WHERE zoom_level = 10
         AND geometry && bbox

         UNION ALL

         -- etldoc: osm_boundary_polygon_gen_z11 -> layer_boundary:z11
         SELECT geometry,
                boundary AS class,
                name,
                tags
         FROM osm_boundary_polygon_gen_z11
         WHERE zoom_level = 11
         AND geometry && bbox

         UNION ALL

         -- etldoc: osm_boundary_polygon_gen_z12 -> layer_boundary:z12
         SELECT geometry,
                boundary AS class,
                name,
                tags
         FROM osm_boundary_polygon_gen_z12
         WHERE zoom_level = 12
         AND geometry && bbox

         UNION ALL

         -- etldoc: osm_boundary_polygon_gen_z13 -> layer_boundary:z13
         SELECT geometry,
                boundary AS class,
                name,
                tags
         FROM osm_boundary_polygon_gen_z13
         WHERE zoom_level = 13
         AND geometry && bbox

         UNION ALL

         -- etldoc: osm_boundary_polygon -> layer_boundary:z14
         SELECT geometry,
                boundary AS class,
                name,
                tags
         FROM osm_boundary_polygon
         WHERE zoom_level = 14
         AND geometry && bbox

     ) AS area_zoom_levels

$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;

DO $$ BEGIN RAISE NOTICE 'Finished layer boundary'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer place'; END$$;

DO $$ BEGIN
    PERFORM 'ne_10m_admin_1_states_provinces'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "place"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_10m_admin_0_countries'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "place"';
END;
$$ LANGUAGE 'plpgsql';

DO $$ BEGIN
    PERFORM 'ne_10m_populated_places'::regclass;
EXCEPTION
    WHEN undefined_table THEN
        RAISE EXCEPTION '%', SQLERRM
            USING DETAIL = 'this table or view is required for layer "place"';
END;
$$ LANGUAGE 'plpgsql';

-- Layer place - ./types.sql

DO
$$
    BEGIN
        PERFORM 'city_place'::regtype;
    EXCEPTION
        WHEN undefined_object THEN
            CREATE TYPE city_place AS enum ('city', 'town', 'village', 'hamlet', 'borough', 'suburb', 'quarter', 'neighbourhood', 'isolated_dwelling');
    END
$$;

ALTER TABLE osm_city_point
    ALTER COLUMN place TYPE city_place USING place::city_place;

-- Layer place - ./capital.sql

CREATE OR REPLACE FUNCTION normalize_capital_level(capital text)
    RETURNS int AS
$$
SELECT CASE
           WHEN capital = 'yes' THEN 2
           WHEN capital IN ('2', '3', '4', '5', '6') THEN capital::int
           END;
$$ LANGUAGE SQL IMMUTABLE
                STRICT
                PARALLEL SAFE;

-- Layer place - ./city.sql

-- etldoc: layer_city[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="layer_city | <z2_14> z2-z14+" ] ;

-- etldoc: osm_city_point -> layer_city:z2_14
CREATE OR REPLACE FUNCTION layer_city(bbox geometry, zoom_level int, pixel_width numeric)
    RETURNS TABLE
            (
                osm_id   bigint,
                geometry geometry,
                name     text,
                name_en  text,
                name_de  text,
                tags     hstore,
                place    city_place,
                "rank"   int,
                capital  int
            )
AS
$$
SELECT *
FROM (
         SELECT osm_id,
                geometry,
                name,
                COALESCE(NULLIF(name_en, ''), name) AS name_en,
                COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
                tags,
                place,
                "rank",
                normalize_capital_level(capital) AS capital
         FROM osm_city_point
         WHERE geometry && bbox
           AND ((zoom_level = 2 AND "rank" = 1)
             OR (zoom_level BETWEEN 3 AND 7 AND "rank" <= zoom_level + 1)
             )
         UNION ALL
         SELECT osm_id,
                geometry,
                name,
                COALESCE(NULLIF(name_en, ''), name) AS name_en,
                COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
                tags,
                place,
                COALESCE("rank", gridrank + 10),
                normalize_capital_level(capital) AS capital
         FROM (
                  SELECT osm_id,
                         geometry,
                         name,
                         COALESCE(NULLIF(name_en, ''), name) AS name_en,
                         COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
                         tags,
                         place,
                         "rank",
                         capital,
                         row_number() OVER (
                             PARTITION BY LabelGrid(geometry, 128 * pixel_width)
                             ORDER BY "rank" ASC NULLS LAST,
                                 place ASC NULLS LAST,
                                 population DESC NULLS LAST,
                                 length(name) ASC
                             )::int AS gridrank
                  FROM osm_city_point
                  WHERE geometry && bbox
                    AND ((zoom_level = 7 AND place <= 'town'::city_place
                      OR (zoom_level BETWEEN 8 AND 10 AND place <= 'village'::city_place)
                      OR (zoom_level BETWEEN 11 AND 13 AND place <= 'suburb'::city_place)
                      OR (zoom_level >= 14)
                      ))
              ) AS ranked_places
         WHERE (zoom_level BETWEEN 7 AND 8 AND (gridrank <= 4 OR "rank" IS NOT NULL))
            OR (zoom_level = 9 AND (gridrank <= 8 OR "rank" IS NOT NULL))
            OR (zoom_level = 10 AND (gridrank <= 12 OR "rank" IS NOT NULL))
            OR (zoom_level BETWEEN 11 AND 12 AND (gridrank <= 14 OR "rank" IS NOT NULL))
            OR (zoom_level >= 13)
     ) AS city_all;
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;

-- Layer place - ./area_rank.sql

CREATE OR REPLACE FUNCTION area_rank(area real) RETURNS int AS
$$
SELECT CASE
           WHEN area > 640000000 THEN 1
           WHEN area > 160000000 THEN 2
           WHEN area > 40000000 THEN 3
           WHEN area > 15000000 THEN 4
           WHEN area > 10000000 THEN 5
           WHEN area > 0 THEN 6
           ELSE 7
           END;
$$ LANGUAGE SQL IMMUTABLE
                STRICT
                PARALLEL SAFE;

-- Layer place - ./update_continent_point.sql

DROP TRIGGER IF EXISTS trigger_flag ON osm_continent_point;
DROP TRIGGER IF EXISTS trigger_store ON osm_continent_point;
DROP TRIGGER IF EXISTS trigger_refresh ON place_continent_point.updates;

CREATE SCHEMA IF NOT EXISTS place_continent_point;

CREATE TABLE IF NOT EXISTS place_continent_point.osm_ids
(
    osm_id bigint PRIMARY KEY
);

-- etldoc:  osm_continent_point ->  osm_continent_point
CREATE OR REPLACE FUNCTION update_osm_continent_point(full_update boolean) RETURNS void AS
$$
    UPDATE osm_continent_point
    SET tags = update_tags(tags, geometry)
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM place_continent_point.osm_ids))
      AND COALESCE(tags->'name:latin', tags->'name:nonlatin', tags->'name_int') IS NULL
      AND tags != update_tags(tags, geometry);
$$ LANGUAGE SQL;

SELECT update_osm_continent_point(true);

-- Handle updates

CREATE OR REPLACE FUNCTION place_continent_point.store() RETURNS trigger AS
$$
BEGIN
    INSERT INTO place_continent_point.osm_ids VALUES (NEW.osm_id) ON CONFLICT (osm_id) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS place_continent_point.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION place_continent_point.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO place_continent_point.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION place_continent_point.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh place_continent_point';

    -- Analyze tracking and source tables before performing update
    ANALYZE place_continent_point.osm_ids;
    ANALYZE osm_continent_point;

    PERFORM update_osm_continent_point(false);
    -- noinspection SqlWithoutWhere
    DELETE FROM place_continent_point.osm_ids;
    -- noinspection SqlWithoutWhere
    DELETE FROM place_continent_point.updates;

    RAISE LOG 'Refresh place_continent_point done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE
    ON osm_continent_point
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE place_continent_point.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE
    ON osm_continent_point
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE place_continent_point.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON place_continent_point.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE place_continent_point.refresh();

-- Layer place - ./update_country_point.sql

DROP TRIGGER IF EXISTS trigger_flag ON osm_country_point;
DROP TRIGGER IF EXISTS trigger_store ON osm_country_point;
DROP TRIGGER IF EXISTS trigger_refresh ON place_country.updates;

CREATE SCHEMA IF NOT EXISTS place_country;

CREATE TABLE IF NOT EXISTS place_country.osm_ids
(
    osm_id bigint PRIMARY KEY
);

-- etldoc: ne_10m_admin_0_countries   -> osm_country_point
-- etldoc: osm_country_point          -> osm_country_point

CREATE OR REPLACE FUNCTION update_osm_country_point(full_update boolean) RETURNS void AS
$$
    UPDATE osm_country_point AS osm
    SET "rank"            = 7,
        iso3166_1_alpha_2 = COALESCE(
                NULLIF(osm.country_code_iso3166_1_alpha_2, ''),
                NULLIF(osm.iso3166_1_alpha_2, ''),
                NULLIF(osm.iso3166_1, '')
            )
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM place_country.osm_ids))
      AND rank IS NULL;

    WITH important_country_point AS (
        SELECT osm.geometry,
               osm.osm_id,
               osm.name,
               COALESCE(NULLIF(osm.name_en, ''), ne.name) AS name_en,
               ne.scalerank,
               ne.labelrank
        FROM ne_10m_admin_0_countries AS ne,
             osm_country_point AS osm
        WHERE
          -- We match only countries with ISO codes to eliminate disputed countries
            iso3166_1_alpha_2 IS NOT NULL
          -- that lies inside polygon of sovereign country
          AND ST_Within(osm.geometry, ne.geometry)
    )
    UPDATE osm_country_point AS osm
        -- Normalize both scalerank and labelrank into a ranking system from 1 to 6
        -- where the ranks are still distributed uniform enough across all countries
    SET "rank" = LEAST(6, CEILING((scalerank + labelrank) / 2.0))
    FROM important_country_point AS ne
    WHERE (full_update OR osm.osm_id IN (SELECT osm_id FROM place_country.osm_ids))
      AND rank = 7
      AND osm.osm_id = ne.osm_id;

    -- Repeat the step for archipelago countries like Philippines or Indonesia
    -- whose label point is not within country's polygon
    WITH important_country_point AS (
        SELECT osm.osm_id,
--       osm.name,
               ne.scalerank,
               ne.labelrank,
--       ST_Distance(osm.geometry, ne.geometry) AS distance,
               ROW_NUMBER()
               OVER (
                   PARTITION BY osm.osm_id
                   ORDER BY
                       ST_Distance(osm.geometry, ne.geometry)
                   ) AS rk
        FROM osm_country_point osm,
             ne_10m_admin_0_countries AS ne
        WHERE iso3166_1_alpha_2 IS NOT NULL
          AND NOT (osm."rank" BETWEEN 1 AND 6)
    )
    UPDATE osm_country_point AS osm
        -- Normalize both scalerank and labelrank into a ranking system from 1 to 6
        -- where the ranks are still distributed uniform enough across all countries
    SET "rank" = LEAST(6, CEILING((ne.scalerank + ne.labelrank) / 2.0))
    FROM important_country_point AS ne
    WHERE (full_update OR osm.osm_id IN (SELECT osm_id FROM place_country.osm_ids))
      AND rank = 7
      AND osm.osm_id = ne.osm_id
      AND ne.rk = 1;

    UPDATE osm_country_point AS osm
    SET "rank" = 6
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM place_country.osm_ids))
      AND "rank" = 7;

    -- TODO: This shouldn't be necessary? The rank function makes something wrong...
    UPDATE osm_country_point AS osm
    SET "rank" = 1
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM place_country.osm_ids))
      AND "rank" = 0;

    UPDATE osm_country_point
    SET tags = update_tags(tags, geometry)
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM place_country.osm_ids))
      AND COALESCE(tags->'name:latin', tags->'name:nonlatin', tags->'name_int') IS NULL
      AND tags != update_tags(tags, geometry);

$$ LANGUAGE SQL;

SELECT update_osm_country_point(true);

-- Handle updates

CREATE OR REPLACE FUNCTION place_country.store() RETURNS trigger AS
$$
BEGIN
    INSERT INTO place_country.osm_ids VALUES (NEW.osm_id) ON CONFLICT (osm_id) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS place_country.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION place_country.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO place_country.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION place_country.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh place_country rank';

    -- Analyze tracking and source tables before performing update
    ANALYZE place_country.osm_ids;
    ANALYZE osm_country_point;

    PERFORM update_osm_country_point(false);
    -- noinspection SqlWithoutWhere
    DELETE FROM place_country.osm_ids;
    -- noinspection SqlWithoutWhere
    DELETE FROM place_country.updates;

    RAISE LOG 'Refresh place_country done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE
    ON osm_country_point
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE place_country.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE
    ON osm_country_point
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE place_country.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON place_country.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE place_country.refresh();

-- Layer place - ./update_island_polygon.sql

DROP TRIGGER IF EXISTS trigger_flag ON osm_island_polygon;
DROP TRIGGER IF EXISTS trigger_store ON osm_island_polygon;
DROP TRIGGER IF EXISTS trigger_refresh ON place_island_polygon.updates;

CREATE SCHEMA IF NOT EXISTS place_island_polygon;

CREATE TABLE IF NOT EXISTS place_island_polygon.osm_ids
(
    osm_id bigint PRIMARY KEY
);

-- etldoc:  osm_island_polygon ->  osm_island_polygon
CREATE OR REPLACE FUNCTION update_osm_island_polygon(full_update boolean) RETURNS void AS
$$
    UPDATE osm_island_polygon
    SET geometry = ST_PointOnSurface(geometry)
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM place_island_polygon.osm_ids))
      AND ST_GeometryType(geometry) <> 'ST_Point'
      AND ST_IsValid(geometry);

    UPDATE osm_island_polygon
    SET tags = update_tags(tags, geometry)
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM place_island_polygon.osm_ids))
      AND COALESCE(tags->'name:latin', tags->'name:nonlatin', tags->'name_int') IS NULL
      AND tags != update_tags(tags, geometry);

$$ LANGUAGE SQL;

SELECT update_osm_island_polygon(true);

-- Handle updates

CREATE OR REPLACE FUNCTION place_island_polygon.store() RETURNS trigger AS
$$
BEGIN
    INSERT INTO place_island_polygon.osm_ids VALUES (NEW.osm_id) ON CONFLICT (osm_id) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS place_island_polygon.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION place_island_polygon.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO place_island_polygon.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION place_island_polygon.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh place_island_polygon';

    -- Analyze tracking and source tables before performing update
    ANALYZE place_island_polygon.osm_ids;
    ANALYZE osm_island_polygon;

    PERFORM update_osm_island_polygon(false);
    -- noinspection SqlWithoutWhere
    DELETE FROM place_island_polygon.osm_ids;
    -- noinspection SqlWithoutWhere
    DELETE FROM place_island_polygon.updates;

    RAISE LOG 'Refresh place_island_polygon done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE
    ON osm_island_polygon
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE place_island_polygon.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE
    ON osm_island_polygon
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE place_island_polygon.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON place_island_polygon.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE place_island_polygon.refresh();

-- Layer place - ./update_island_point.sql

DROP TRIGGER IF EXISTS trigger_flag ON osm_island_point;
DROP TRIGGER IF EXISTS trigger_store ON osm_island_point;
DROP TRIGGER IF EXISTS trigger_refresh ON place_island_point.updates;

CREATE SCHEMA IF NOT EXISTS place_island_point;

CREATE TABLE IF NOT EXISTS place_island_point.osm_ids
(
    osm_id bigint PRIMARY KEY
);

-- etldoc:  osm_island_point ->  osm_island_point
CREATE OR REPLACE FUNCTION update_osm_island_point(full_update boolean) RETURNS void AS
$$
    UPDATE osm_island_point
    SET tags = update_tags(tags, geometry)
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM place_island_point.osm_ids))
      AND COALESCE(tags->'name:latin', tags->'name:nonlatin', tags->'name_int') IS NULL
      AND tags != update_tags(tags, geometry);
$$ LANGUAGE SQL;

SELECT update_osm_island_point(true);

-- Handle updates

CREATE OR REPLACE FUNCTION place_island_point.store() RETURNS trigger AS
$$
BEGIN
    INSERT INTO place_island_point.osm_ids VALUES (NEW.osm_id) ON CONFLICT (osm_id) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS place_island_point.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION place_island_point.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO place_island_point.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION place_island_point.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh place_island_point';

    -- Analyze tracking and source tables before performing update
    ANALYZE place_island_point.osm_ids;
    ANALYZE osm_island_point;

    PERFORM update_osm_island_point(false);
    -- noinspection SqlWithoutWhere
    DELETE FROM place_island_point.osm_ids;
    -- noinspection SqlWithoutWhere
    DELETE FROM place_island_point.updates;

    RAISE LOG 'Refresh place_island_point done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE
    ON osm_island_point
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE place_island_point.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE
    ON osm_island_point
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE place_island_point.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON place_island_point.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE place_island_point.refresh();

-- Layer place - ./update_state_point.sql

DROP TRIGGER IF EXISTS trigger_flag ON osm_state_point;
DROP TRIGGER IF EXISTS trigger_store ON osm_state_point;
DROP TRIGGER IF EXISTS trigger_refresh ON place_state.updates;

CREATE SCHEMA IF NOT EXISTS place_state;

CREATE TABLE IF NOT EXISTS place_state.osm_ids
(
    osm_id bigint PRIMARY KEY
);

-- etldoc: ne_10m_admin_1_states_provinces   -> osm_state_point
-- etldoc: osm_state_point                       -> osm_state_point

CREATE OR REPLACE FUNCTION update_osm_state_point(full_update boolean) RETURNS void AS
$$
    WITH important_state_point AS (
        SELECT osm.geometry,
               osm.osm_id,
               osm.name,
               COALESCE(NULLIF(osm.name_en, ''), ne.name) AS name_en,
               ne.scalerank,
               ne.labelrank,
               ne.datarank
        FROM ne_10m_admin_1_states_provinces AS ne,
             osm_state_point AS osm
        WHERE
          -- We only match whether the point is within the Natural Earth polygon
          -- because name matching is difficult
            ST_Within(osm.geometry, ne.geometry)
          -- We leave out leess important states
          AND ne.scalerank <= 6
          AND ne.labelrank <= 7
    )
    UPDATE osm_state_point AS osm
        -- Normalize both scalerank and labelrank into a ranking system from 1 to 6.
    SET "rank" = LEAST(6, CEILING((scalerank + labelrank + datarank) / 3.0))
    FROM important_state_point AS ne
    WHERE (full_update OR osm.osm_id IN (SELECT osm_id FROM place_state.osm_ids))
      AND rank IS NULL
      AND osm.osm_id = ne.osm_id;

    -- TODO: This shouldn't be necessary? The rank function makes something wrong...
    UPDATE osm_state_point AS osm
    SET "rank" = 1
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM place_state.osm_ids))
      AND "rank" = 0;

    DELETE FROM osm_state_point
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM place_state.osm_ids))
      AND "rank" IS NULL;

    UPDATE osm_state_point
    SET tags = update_tags(tags, geometry)
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM place_state.osm_ids))
      AND COALESCE(tags->'name:latin', tags->'name:nonlatin', tags->'name_int') IS NULL
      AND tags != update_tags(tags, geometry);

$$ LANGUAGE SQL;

SELECT update_osm_state_point(true);

-- Handle updates

CREATE OR REPLACE FUNCTION place_state.store() RETURNS trigger AS
$$
BEGIN
    INSERT INTO place_state.osm_ids VALUES (NEW.osm_id) ON CONFLICT (osm_id) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS place_state.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION place_state.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO place_state.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION place_state.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh place_state rank';

    -- Analyze tracking and source tables before performing update
    ANALYZE place_state.osm_ids;
    ANALYZE osm_state_point;

    PERFORM update_osm_state_point(false);
    -- noinspection SqlWithoutWhere
    DELETE FROM place_state.osm_ids;
    -- noinspection SqlWithoutWhere
    DELETE FROM place_state.updates;

    RAISE LOG 'Refresh place_state done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE
    ON osm_state_point
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE place_state.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE
    ON osm_state_point
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE place_state.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON place_state.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE place_state.refresh();

-- Layer place - ./update_city_point.sql

DROP TRIGGER IF EXISTS trigger_flag ON osm_city_point;
DROP TRIGGER IF EXISTS trigger_store ON osm_city_point;
DROP TRIGGER IF EXISTS trigger_refresh ON place_city.updates;

CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE SCHEMA IF NOT EXISTS place_city;

CREATE TABLE IF NOT EXISTS place_city.osm_ids
(
    osm_id bigint PRIMARY KEY
);

CREATE OR REPLACE FUNCTION update_osm_city_point(full_update boolean) RETURNS void AS
$$
    -- etldoc: ne_10m_populated_places -> osm_city_point
    -- etldoc: osm_city_point          -> osm_city_point

    WITH important_city_point AS (
        SELECT osm.osm_id, ne.scalerank
        FROM osm_city_point AS osm
             -- Clear OSM key:rank ( https://github.com/openmaptiles/openmaptiles/issues/108 )
             LEFT JOIN ne_10m_populated_places AS ne ON
            (
                (osm.tags ? 'wikidata' AND osm.tags->'wikidata' = ne.wikidataid) OR
                lower(osm.name) IN (lower(ne.name), lower(ne.namealt), lower(ne.meganame), lower(ne.name_en), lower(ne.nameascii)) OR
                lower(osm.name_en) IN (lower(ne.name), lower(ne.namealt), lower(ne.meganame), lower(ne.name_en), lower(ne.nameascii)) OR
                ne.name = unaccent(osm.name)
            )
          AND osm.place IN ('city', 'town', 'village')
          AND ST_DWithin(ne.geometry, osm.geometry, 50000)
    )
    UPDATE osm_city_point AS osm
        -- Move scalerank to range 1 to 10 and merge scalerank 5 with 6 since not enough cities
        -- are in the scalerank 5 bucket
    SET "rank" = CASE WHEN scalerank <= 5 THEN scalerank + 1 ELSE scalerank END
    FROM important_city_point AS ne
    WHERE (full_update OR osm.osm_id IN (SELECT osm_id FROM place_city.osm_ids))
      AND rank IS DISTINCT FROM CASE WHEN scalerank <= 5 THEN scalerank + 1 ELSE scalerank END
      AND osm.osm_id = ne.osm_id;

    UPDATE osm_city_point
    SET tags = update_tags(tags, geometry)
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM place_city.osm_ids))
      AND COALESCE(tags->'name:latin', tags->'name:nonlatin', tags->'name_int') IS NULL
      AND tags != update_tags(tags, geometry);

$$ LANGUAGE SQL;

SELECT update_osm_city_point(true);

-- Handle updates

CREATE OR REPLACE FUNCTION place_city.store() RETURNS trigger AS
$$
BEGIN
    INSERT INTO place_city.osm_ids VALUES (NEW.osm_id) ON CONFLICT (osm_id) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS place_city.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION place_city.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO place_city.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION place_city.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh place_city rank';

    -- Analyze tracking and source tables before performing update
    ANALYZE place_city.osm_ids;
    ANALYZE osm_city_point;

    PERFORM update_osm_city_point(false);
    -- noinspection SqlWithoutWhere
    DELETE FROM place_city.osm_ids;
    -- noinspection SqlWithoutWhere
    DELETE FROM place_city.updates;

    RAISE LOG 'Refresh place_city done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE
    ON osm_city_point
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE place_city.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE
    ON osm_city_point
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE place_city.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON place_city.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE place_city.refresh();

-- Layer place - ./place.sql

-- etldoc: layer_place[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="layer_place | <z0_3> z0-3|<z4_7> z4-7|<z8_11> z8-11| <z12_14> z12-z14+" ] ;

CREATE OR REPLACE FUNCTION layer_place(bbox geometry, zoom_level int, pixel_width numeric)
    RETURNS TABLE
            (
                osm_id   bigint,
                geometry geometry,
                name     text,
                name_en  text,
                name_de  text,
                tags     hstore,
                class    text,
                "rank"   int,
                capital  int,
                iso_a2   text
            )
AS
$$
SELECT *
FROM (
         SELECT
             -- etldoc: osm_continent_point -> layer_place:z0_3
             osm_id * 10 AS osm_id,
             geometry,
             name,
             COALESCE(NULLIF(name_en, ''), name) AS name_en,
             COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
             tags,
             'continent' AS class,
             1 AS "rank",
             NULL::int AS capital,
             NULL::text AS iso_a2
         FROM osm_continent_point
         WHERE geometry && bbox
           AND zoom_level < 4

         UNION ALL

         SELECT
             -- etldoc: osm_country_point -> layer_place:z0_3
             -- etldoc: osm_country_point -> layer_place:z4_7
             -- etldoc: osm_country_point -> layer_place:z8_11
             -- etldoc: osm_country_point -> layer_place:z12_14
             osm_id * 10 AS osm_id,
             geometry,
             name,
             COALESCE(NULLIF(name_en, ''), name) AS name_en,
             COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
             tags,
             'country' AS class,
             "rank",
             NULL::int AS capital,
             iso3166_1_alpha_2 AS iso_a2
         FROM osm_country_point
         WHERE geometry && bbox
           AND "rank" <= zoom_level + 1
           AND name <> ''

         UNION ALL

         SELECT
             -- etldoc: osm_state_point  -> layer_place:z0_3
             -- etldoc: osm_state_point  -> layer_place:z4_7
             -- etldoc: osm_state_point  -> layer_place:z8_11
             -- etldoc: osm_state_point  -> layer_place:z12_14
             osm_id * 10 AS osm_id,
             geometry,
             name,
             COALESCE(NULLIF(name_en, ''), name) AS name_en,
             COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
             tags,
             place::text AS class,
             "rank",
             NULL::int AS capital,
             NULL::text AS iso_a2
         FROM osm_state_point
         WHERE geometry && bbox
           AND name <> ''
           AND zoom_level > 1

         UNION ALL

         SELECT
             -- etldoc: osm_island_point    -> layer_place:z12_14
             osm_id * 10 AS osm_id,
             geometry,
             name,
             COALESCE(NULLIF(name_en, ''), name) AS name_en,
             COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
             tags,
             'island' AS class,
             7 AS "rank",
             NULL::int AS capital,
             NULL::text AS iso_a2
         FROM osm_island_point
         WHERE zoom_level >= 12
           AND geometry && bbox

         UNION ALL

         SELECT
             -- etldoc: osm_island_polygon  -> layer_place:z8_11
             -- etldoc: osm_island_polygon  -> layer_place:z12_14
             osm_id * 10 AS osm_id,
             geometry,
             name,
             COALESCE(NULLIF(name_en, ''), name) AS name_en,
             COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
             tags,
             'island' AS class,
             area_rank(area) AS "rank",
             NULL::int AS capital,
             NULL::text AS iso_a2
         FROM osm_island_polygon
         WHERE geometry && bbox
           AND ((zoom_level = 8 AND area_rank(area) <= 3)
             OR (zoom_level = 9 AND area_rank(area) <= 4)
             OR (zoom_level >= 10))

         UNION ALL

         SELECT
             -- etldoc: osm_boundary_polygon  -> layer_place:z6_11
             -- etldoc: osm_boundary_polygon  -> layer_place:z12_14
             osm_id * 10 AS osm_id,
             geometry_point,
             name,
             NULL::text AS name_en, -- deprecated
             NULL::text AS name_de, -- deprecated
             tags,
             'aboriginal_lands' AS class,
             area_rank(area) AS "rank",
             NULL::int AS capital,
             NULL::text AS iso_a2
         FROM osm_boundary_polygon
         WHERE geometry_point && bbox
           AND ((zoom_level = 6 AND area_rank(area) <= 1)
             OR (zoom_level = 7 AND area_rank(area) <= 2)
             OR (zoom_level = 8 AND area_rank(area) <= 3)
             OR (zoom_level = 9 AND area_rank(area) <= 4)
             OR (zoom_level >= 10))
         UNION ALL

         SELECT
             -- etldoc: layer_city          -> layer_place:z0_3
             -- etldoc: layer_city          -> layer_place:z4_7
             -- etldoc: layer_city          -> layer_place:z8_11
             -- etldoc: layer_city          -> layer_place:z12_14
             osm_id * 10 AS osm_id,
             geometry,
             name,
             name_en,
             name_de,
             tags,
             place::text AS class,
             "rank",
             capital,
             NULL::text AS iso_a2
         FROM layer_city(bbox, zoom_level, pixel_width)
         ORDER BY "rank" ASC
     ) AS place_all
$$ LANGUAGE SQL STABLE
                PARALLEL SAFE;
-- TODO: Check if the above can be made STRICT -- i.e. if pixel_width could be NULL

DO $$ BEGIN RAISE NOTICE 'Finished layer place'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer housenumber'; END$$;

-- Layer housenumber - ./housenumber_display.sql

CREATE OR REPLACE FUNCTION display_housenumber_nonnumeric(raw_housenumber text)
RETURNS text AS $$
  -- Find the position of the semicolon in the input string
  -- and extract the first and last value
  SELECT substring(raw_housenumber from 1 for position(';' in raw_housenumber) - 1)
         || '–'
         || substring(raw_housenumber from position(';' in raw_housenumber) + 1);
$$ LANGUAGE SQL IMMUTABLE;


CREATE OR REPLACE FUNCTION display_housenumber(raw_housenumber text)
RETURNS text AS $$
  SELECT CASE
    WHEN raw_housenumber !~ ';' THEN raw_housenumber
    WHEN raw_housenumber ~ '[^0-9;]' THEN display_housenumber_nonnumeric(raw_housenumber)
    ELSE
      (SELECT min(value)::text || '–' || max(value)::text
        FROM unnest(array_remove(string_to_array(raw_housenumber, ';'), '')::bigint[]) AS value)
  END
$$ LANGUAGE SQL IMMUTABLE;

-- Layer housenumber - ./housenumber_centroid.sql

DROP TRIGGER IF EXISTS trigger_flag ON osm_housenumber_point;
DROP TRIGGER IF EXISTS trigger_store ON osm_housenumber_point;
DROP TRIGGER IF EXISTS trigger_refresh ON housenumber.updates;

CREATE SCHEMA IF NOT EXISTS housenumber;

CREATE TABLE IF NOT EXISTS housenumber.osm_ids
(
    osm_id bigint PRIMARY KEY
);

-- etldoc: osm_housenumber_point -> osm_housenumber_point
CREATE OR REPLACE FUNCTION convert_housenumber_point(full_update boolean) RETURNS void AS
$$
    UPDATE osm_housenumber_point
    SET geometry =
            CASE
                WHEN ST_NPoints(ST_ConvexHull(geometry)) = ST_NPoints(geometry)
                    THEN ST_Centroid(geometry)
                ELSE ST_PointOnSurface(geometry)
                END
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM housenumber.osm_ids))
        AND ST_GeometryType(geometry) <> 'ST_Point'
        AND ST_IsValid(geometry);

    -- we don't need exact name just to know if it's present
    UPDATE osm_housenumber_point
    SET has_name = 
            CASE
                WHEN has_name = '' THEN '0'
                ELSE '1'
            END
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM housenumber.osm_ids));

$$ LANGUAGE SQL;

SELECT convert_housenumber_point(true);

-- Handle updates

CREATE OR REPLACE FUNCTION housenumber.store() RETURNS trigger AS
$$
BEGIN
    INSERT INTO housenumber.osm_ids VALUES (NEW.osm_id) ON CONFLICT (osm_id) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS housenumber.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION housenumber.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO housenumber.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION housenumber.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh housenumber';

    -- Analyze tracking and source tables before performing update
    ANALYZE housenumber.osm_ids;
    ANALYZE osm_housenumber_point;

    PERFORM convert_housenumber_point(false);
    -- noinspection SqlWithoutWhere
    DELETE FROM housenumber.osm_ids;
    -- noinspection SqlWithoutWhere
    DELETE FROM housenumber.updates;

    RAISE LOG 'Refresh housenumber done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE
    ON osm_housenumber_point
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE housenumber.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE
    ON osm_housenumber_point
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE housenumber.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON housenumber.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE housenumber.refresh();

-- Layer housenumber - ./housenumber.sql

-- etldoc: layer_housenumber[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="layer_housenumber | <z14_> z14+" ] ;

CREATE OR REPLACE FUNCTION layer_housenumber(bbox geometry, zoom_level integer)
    RETURNS TABLE
            (
                osm_id      bigint,
                geometry    geometry,
                housenumber text
            )
AS
$$
SELECT
    -- etldoc: osm_housenumber_point -> layer_housenumber:z14_
    osm_id,
    geometry,
    display_housenumber(housenumber)
FROM (
    SELECT
        osm_id,
        geometry,
        housenumber,
        row_number() OVER(PARTITION BY concat(street, block_number, housenumber) ORDER BY has_name ASC) as rn
    FROM osm_housenumber_point
    WHERE 1=1
        AND zoom_level >= 14
        AND geometry && bbox
) t
WHERE rn = 1;

$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;

DO $$ BEGIN RAISE NOTICE 'Finished layer housenumber'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer poi'; END$$;

-- Layer poi - ./public_transport_stop_type.sql

DO
$$
    BEGIN
        PERFORM 'public_transport_stop_type'::regtype;
    EXCEPTION
        WHEN undefined_object THEN
            CREATE TYPE public_transport_stop_type AS enum (
                'subway', 'tram_stop', 'bus_station', 'bus_stop'
                );
    END
$$;

-- Layer poi - ./class.sql

CREATE OR REPLACE FUNCTION poi_class_rank(class text)
    RETURNS int AS
$$
SELECT CASE class
           WHEN 'hospital' THEN 20
           WHEN 'railway' THEN 40
           WHEN 'bus' THEN 50
           WHEN 'attraction' THEN 70
           WHEN 'harbor' THEN 75
           WHEN 'college' THEN 80
           WHEN 'school' THEN 85
           WHEN 'stadium' THEN 90
           WHEN 'zoo' THEN 95
           WHEN 'town_hall' THEN 100
           WHEN 'campsite' THEN 110
           WHEN 'cemetery' THEN 115
           WHEN 'park' THEN 120
           WHEN 'library' THEN 130
           WHEN 'police' THEN 135
           WHEN 'post' THEN 140
           WHEN 'golf' THEN 150
           WHEN 'shop' THEN 400
           WHEN 'grocery' THEN 500
           WHEN 'fast_food' THEN 600
           WHEN 'clothing_store' THEN 700
           WHEN 'bar' THEN 800
           ELSE 1000
           END;
$$ LANGUAGE SQL IMMUTABLE
                PARALLEL SAFE;

CREATE OR REPLACE FUNCTION poi_class(subclass text, mapping_key text)
    RETURNS text AS
$$
SELECT CASE
           -- Special case subclass collision between office=university and amenity=university
           WHEN mapping_key = 'amenity' AND subclass = 'university' THEN 'college'
           WHEN "subclass" IN ('accessories', 'antiques', 'beauty', 'bed', 'boutique', 'camera', 'carpet', 'charity', 'chemist', 'chocolate', 'coffee', 'computer', 'convenience', 'confectionery', 'copyshop', 'cosmetics', 'garden_centre', 'doityourself', 'erotic', 'electronics', 'fabric', 'farm', 'florist', 'frozen_food', 'furniture', 'video_games', 'video', 'general', 'gift', 'hardware', 'hearing_aids', 'hifi', 'interior_decoration', 'jewelry', 'kiosk', 'locksmith', 'lamps', 'mall', 'massage', 'motorcycle', 'mobile_phone', 'newsagent', 'optician', 'outdoor', 'paint', 'perfumery', 'perfume', 'pet', 'photo', 'second_hand', 'shoes', 'sports', 'stationery', 'tailor', 'tattoo', 'ticket', 'tobacco', 'toys', 'travel_agency', 'watches', 'weapons', 'wholesale') THEN 'shop'
           WHEN "subclass" IN ('accountant', 'advertising_agency', 'architect', 'association', 'bail_bond_agent', 'charity', 'company', 'construction_company', 'consulting', 'cooperative', 'courier', 'coworking', 'diplomatic', 'educational_institution', 'employment_agency', 'energy_supplier', 'engineer', 'estate_agent', 'financial', 'financial_advisor', 'forestry', 'foundation', 'geodesist', 'government', 'graphic_design', 'guide', 'harbour_master', 'health_insurance', 'insurance', 'interior_design', 'it', 'lawyer', 'logistics', 'marketing', 'moving_company', 'newspaper', 'ngo', 'notary', 'physician', 'political_party', 'private_investigator', 'property_management', 'publisher', 'quango', 'religion', 'research', 'security', 'surveyor', 'tax_advisor', 'taxi', 'telecommunication', 'therapist', 'translator', 'travel_agent', 'tutoring', 'union', 'university', 'water_utility', 'web_design', 'wedding_planner') THEN 'office'
           WHEN "subclass" IN ('townhall', 'public_building', 'courthouse', 'community_centre') THEN 'town_hall'
           WHEN "subclass" IN ('golf', 'golf_course', 'miniature_golf') THEN 'golf'
           WHEN "subclass" IN ('fast_food', 'food_court') THEN 'fast_food'
           WHEN "subclass" IN ('park', 'bbq') THEN 'park'
           WHEN "subclass" IN ('bus_stop', 'bus_station') THEN 'bus'
           WHEN ("subclass" = 'station' AND "mapping_key" = 'railway')
               OR "subclass" IN ('halt', 'tram_stop', 'subway')
               THEN 'railway'
           WHEN "subclass" = 'station'
               AND "mapping_key" = 'aerialway'
               THEN 'aerialway'
           WHEN "subclass" IN ('subway_entrance', 'train_station_entrance') THEN 'entrance'
           WHEN "subclass" IN ('camp_site', 'caravan_site') THEN 'campsite'
           WHEN "subclass" IN ('laundry', 'dry_cleaning') THEN 'laundry'
           WHEN "subclass" IN ('supermarket', 'deli', 'delicatessen', 'department_store', 'greengrocer', 'marketplace') THEN 'grocery'
           WHEN "subclass" IN ('books', 'library') THEN 'library'
           WHEN "subclass" IN ('university', 'college') THEN 'college'
           WHEN "subclass" IN ('hotel', 'motel', 'bed_and_breakfast', 'guest_house', 'hostel', 'chalet', 'alpine_hut', 'dormitory') THEN 'lodging'
           WHEN "subclass" = 'ice_cream' THEN 'ice_cream'
           WHEN "subclass" IN ('post_box', 'post_office', 'parcel_locker') THEN 'post'
           WHEN "subclass" = 'cafe' THEN 'cafe'
           WHEN "subclass" IN ('school', 'kindergarten') THEN 'school'
           WHEN "subclass" IN ('alcohol', 'beverages', 'wine') THEN 'alcohol_shop'
           WHEN "subclass" IN ('bar', 'nightclub') THEN 'bar'
           WHEN "subclass" IN ('marina', 'dock') THEN 'harbor'
           WHEN "subclass" IN ('car', 'car_repair', 'car_parts', 'taxi') THEN 'car'
           WHEN "subclass" IN ('hospital', 'nursing_home', 'clinic') THEN 'hospital'
           WHEN "subclass" IN ('grave_yard', 'cemetery') THEN 'cemetery'
           WHEN "subclass" IN ('attraction', 'viewpoint') THEN 'attraction'
           WHEN "subclass" IN ('biergarten', 'pub') THEN 'beer'
           WHEN "subclass" IN ('music', 'musical_instrument') THEN 'music'
           WHEN "subclass" IN ('american_football', 'stadium', 'soccer') THEN 'stadium'
           WHEN "subclass" IN ('art', 'artwork', 'gallery', 'arts_centre') THEN 'art_gallery'
           WHEN "subclass" IN ('bag', 'clothes') THEN 'clothing_store'
           WHEN "subclass" IN ('swimming_area', 'swimming') THEN 'swimming'
           WHEN "subclass" IN ('castle', 'ruins') THEN 'castle'
           WHEN "subclass" = 'atm' THEN 'atm'
           WHEN "subclass" IN ('fuel', 'charging_station') THEN 'fuel'
           WHEN "subclass" IN ('zoo', E'enclosure\'', 'petting_zoo', 'aviary', 'wildlife_park', 'birds', 'safari_park', 'butterfly', 'falconry', 'reptile', 'terrarium') THEN 'zoo'
           ELSE subclass
           END;
$$ LANGUAGE SQL IMMUTABLE
                PARALLEL SAFE;

-- Layer poi - ./poi_stop_agg.sql

-- etldoc:  osm_poi_point ->  osm_poi_stop_centroid
DROP MATERIALIZED VIEW IF EXISTS osm_poi_stop_centroid CASCADE;
CREATE MATERIALIZED VIEW osm_poi_stop_centroid AS
(
SELECT uic_ref,
       count(*) AS count,
       CASE WHEN count(*) > 2 THEN ST_Centroid(ST_UNION(geometry)) END AS centroid
FROM osm_poi_point
WHERE uic_ref <> ''
  AND subclass IN ('bus_stop', 'bus_station', 'tram_stop', 'subway')
GROUP BY uic_ref
HAVING count(*) > 1
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */;

-- etldoc:  osm_poi_stop_centroid ->  osm_poi_stop_rank
-- etldoc:  osm_poi_point ->  osm_poi_stop_rank
DROP MATERIALIZED VIEW IF EXISTS osm_poi_stop_rank CASCADE;
CREATE MATERIALIZED VIEW osm_poi_stop_rank AS
(
SELECT p.osm_id,
-- 		p.uic_ref,
-- 		p.subclass,
       ROW_NUMBER()
       OVER (
           PARTITION BY p.uic_ref
           ORDER BY
               p.subclass :: public_transport_stop_type NULLS LAST,
               ST_Distance(c.centroid, p.geometry)
           ) AS rk
FROM osm_poi_point p
         INNER JOIN osm_poi_stop_centroid c ON (p.uic_ref = c.uic_ref)
WHERE subclass IN ('bus_stop', 'bus_station', 'tram_stop', 'subway')
ORDER BY p.uic_ref, rk
    ) /* DELAY_MATERIALIZED_VIEW_CREATION */;

-- Layer poi - ./update_poi_polygon.sql

DROP TRIGGER IF EXISTS trigger_flag ON osm_poi_polygon;
DROP TRIGGER IF EXISTS trigger_store ON osm_poi_polygon;
DROP TRIGGER IF EXISTS trigger_refresh ON poi_polygon.updates;

CREATE SCHEMA IF NOT EXISTS poi_polygon;

CREATE TABLE IF NOT EXISTS poi_polygon.osm_ids
(
    osm_id bigint PRIMARY KEY
);

-- etldoc:  osm_poi_polygon ->  osm_poi_polygon

CREATE OR REPLACE FUNCTION update_poi_polygon(full_update boolean) RETURNS void AS
$$
    UPDATE osm_poi_polygon
    SET geometry =
            CASE
                WHEN ST_NPoints(ST_ConvexHull(geometry)) = ST_NPoints(geometry)
                    THEN ST_Centroid(geometry)
                ELSE ST_PointOnSurface(geometry)
                END
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM poi_polygon.osm_ids))
      AND ST_GeometryType(geometry) <> 'ST_Point'
      AND ST_IsValid(geometry);

    UPDATE osm_poi_polygon
    SET subclass = 'subway'
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM poi_polygon.osm_ids))
      AND station = 'subway'
      AND subclass = 'station';

    UPDATE osm_poi_polygon
    SET subclass = 'halt'
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM poi_polygon.osm_ids))
      AND funicular = 'yes'
      AND subclass = 'station';

    -- Parcel locker and charging_station without name 
    -- use either brand or operator and add ref if present
    -- (using name for parcel lockers is discouraged, see osm wiki)
    UPDATE osm_poi_polygon
    SET (name, tags) = (
        TRIM(CONCAT(COALESCE(tags -> 'brand', tags -> 'operator'), concat(' ', tags -> 'ref'))),
        tags || hstore('name', TRIM(CONCAT(COALESCE(tags -> 'brand', tags -> 'operator'), concat(' ', tags -> 'ref'))))
    )
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM poi_polygon.osm_ids))
      AND subclass IN ('parcel_locker', 'charging_station')
      AND name = ''
      AND COALESCE(tags -> 'brand', tags -> 'operator') IS NOT NULL;

    UPDATE osm_poi_polygon
    SET tags = update_tags(tags, geometry)
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM poi_polygon.osm_ids))
      AND COALESCE(tags->'name:latin', tags->'name:nonlatin', tags->'name_int') IS NULL
      AND tags != update_tags(tags, geometry);

$$ LANGUAGE SQL;

SELECT update_poi_polygon(true);

-- Handle updates

CREATE OR REPLACE FUNCTION poi_polygon.store() RETURNS trigger AS
$$
BEGIN
    INSERT INTO poi_polygon.osm_ids VALUES (NEW.osm_id) ON CONFLICT (osm_id) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS poi_polygon.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION poi_polygon.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO poi_polygon.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION poi_polygon.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh poi_polygon';

    -- Analyze tracking and source tables before performing update
    ANALYZE poi_polygon.osm_ids;
    ANALYZE osm_poi_polygon;

    PERFORM update_poi_polygon(false);
    -- noinspection SqlWithoutWhere
    DELETE FROM poi_polygon.osm_ids;
    -- noinspection SqlWithoutWhere
    DELETE FROM poi_polygon.updates;

    RAISE LOG 'Refresh poi_polygon done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE
    ON osm_poi_polygon
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE poi_polygon.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE
    ON osm_poi_polygon
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE poi_polygon.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON poi_polygon.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE poi_polygon.refresh();

-- Layer poi - ./update_poi_point.sql

DROP TRIGGER IF EXISTS trigger_flag ON osm_poi_point;
DROP TRIGGER IF EXISTS trigger_refresh ON poi_point.updates;
DROP TRIGGER IF EXISTS trigger_store ON osm_poi_point;

CREATE SCHEMA IF NOT EXISTS poi_point;

CREATE TABLE IF NOT EXISTS poi_point.osm_ids
(
    osm_id bigint PRIMARY KEY
);

-- etldoc:  osm_poi_point ->  osm_poi_point
CREATE OR REPLACE FUNCTION update_osm_poi_point(full_update bool) RETURNS void AS
$$
BEGIN
    UPDATE osm_poi_point
    SET subclass = 'subway'
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM poi_point.osm_ids))
      AND station = 'subway'
      AND subclass = 'station';

    UPDATE osm_poi_point
    SET subclass = 'halt'
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM poi_point.osm_ids))
      AND funicular = 'yes'
      AND subclass = 'station';

    -- ATM without name 
    -- use either operator or network
    -- (using name for ATM is discouraged, see osm wiki)
    UPDATE osm_poi_point
    SET (name, tags) = (
        COALESCE(tags -> 'operator', tags -> 'network'),
        tags || hstore('name', COALESCE(tags -> 'operator', tags -> 'network'))
    )
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM poi_point.osm_ids))
      AND subclass = 'atm'
      AND name = ''
      AND COALESCE(tags -> 'operator', tags -> 'network') IS NOT NULL;

    -- Parcel locker without name 
    -- use either brand or operator and add ref if present
    -- (using name for parcel lockers is discouraged, see osm wiki)
    UPDATE osm_poi_point
    SET (name, tags) = (
        TRIM(CONCAT(COALESCE(tags -> 'brand', tags -> 'operator'), concat(' ', tags -> 'ref'))),
        tags || hstore('name', TRIM(CONCAT(COALESCE(tags -> 'brand', tags -> 'operator'), concat(' ', tags -> 'ref'))))
    )
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM poi_point.osm_ids))
      AND subclass IN ('parcel_locker', 'charging_station')
      AND name = ''
      AND COALESCE(tags -> 'brand', tags -> 'operator') IS NOT NULL;

    UPDATE osm_poi_point
    SET tags = update_tags(tags, geometry)
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM poi_point.osm_ids))
      AND COALESCE(tags->'name:latin', tags->'name:nonlatin', tags->'name_int') IS NULL
      AND tags != update_tags(tags, geometry);

END;
$$ LANGUAGE plpgsql;

SELECT update_osm_poi_point(TRUE);

-- etldoc:  osm_poi_stop_rank ->  osm_poi_point
CREATE OR REPLACE FUNCTION update_osm_poi_point_agg() RETURNS void AS
$$
BEGIN
    UPDATE osm_poi_point p
    SET
        agg_stop = CASE
            WHEN p.subclass IN ('bus_stop', 'bus_station', 'tram_stop', 'subway')
                THEN 1
        END
    WHERE
        agg_stop IS DISTINCT FROM CASE
            WHEN p.subclass IN ('bus_stop', 'bus_station', 'tram_stop', 'subway')
                THEN 1
        END;

    UPDATE osm_poi_point p
    SET
        agg_stop = (
        CASE
            WHEN p.subclass IN ('bus_stop', 'bus_station', 'tram_stop', 'subway')
                     AND (r.rk IS NULL OR r.rk = 1)
                THEN 1
        END)
    FROM osm_poi_stop_rank r
    WHERE p.osm_id = r.osm_id AND
        agg_stop IS DISTINCT FROM (
        CASE
            WHEN p.subclass IN ('bus_stop', 'bus_station', 'tram_stop', 'subway')
                     AND (r.rk IS NULL OR r.rk = 1)
                THEN 1
        END);

END;
$$ LANGUAGE plpgsql;

ALTER TABLE osm_poi_point
    ADD COLUMN IF NOT EXISTS agg_stop integer DEFAULT NULL;
SELECT update_osm_poi_point_agg();

-- Handle updates

CREATE OR REPLACE FUNCTION poi_point.store() RETURNS trigger AS
$$
BEGIN
    INSERT INTO poi_point.osm_ids VALUES (NEW.osm_id) ON CONFLICT (osm_id) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS poi_point.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION poi_point.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO poi_point.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION poi_point.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh poi_point';

    -- Analyze tracking and source tables before performing update
    ANALYZE poi_point.osm_ids;
    ANALYZE osm_poi_point;

    PERFORM update_osm_poi_point(FALSE);
    REFRESH MATERIALIZED VIEW osm_poi_stop_centroid;
    REFRESH MATERIALIZED VIEW osm_poi_stop_rank;
    PERFORM update_osm_poi_point_agg();
    -- noinspection SqlWithoutWhere
    DELETE FROM poi_point.osm_ids;
    -- noinspection SqlWithoutWhere
    DELETE FROM poi_point.updates;

    RAISE LOG 'Refresh poi_point done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE
    ON osm_poi_point
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE poi_point.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE
    ON osm_poi_point
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE poi_point.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON poi_point.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE poi_point.refresh();

-- Layer poi - ./poi.sql

-- etldoc: layer_poi[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="layer_poi | <z12> z12 | <z13> z13 | <z14_> z14+" ] ;

CREATE OR REPLACE FUNCTION layer_poi(bbox geometry, zoom_level integer, pixel_width numeric)
    RETURNS TABLE
            (
                osm_id   bigint,
                geometry geometry,
                name     text,
                name_en  text,
                name_de  text,
                tags     hstore,
                class    text,
                subclass text,
                agg_stop integer,
                layer    integer,
                level    integer,
                indoor   integer,
                "rank"   int
            )
AS
$$
SELECT osm_id_hash AS osm_id,
       geometry,
       NULLIF(name, '') AS name,
       COALESCE(NULLIF(name_en, ''), name) AS name_en,
       COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
       tags,
       poi_class(subclass, mapping_key) AS class,
       CASE
           WHEN subclass = 'information'
               THEN NULLIF(information, '')
           WHEN subclass = 'place_of_worship'
               THEN NULLIF(religion, '')
           WHEN subclass = 'pitch'
               THEN NULLIF(sport, '')
           ELSE subclass
           END AS subclass,
       agg_stop,
       NULLIF(layer, 0) AS layer,
       "level",
       CASE WHEN indoor = TRUE THEN 1 END AS indoor,
       row_number() OVER (
           PARTITION BY LabelGrid(geometry, 100 * pixel_width)
           ORDER BY CASE WHEN name = '' THEN 2000 ELSE poi_class_rank(poi_class(subclass, mapping_key)) END ASC
           )::int AS "rank"
FROM (
         -- etldoc: osm_poi_point ->  layer_poi:z12
         -- etldoc: osm_poi_point ->  layer_poi:z13
         SELECT *,
                osm_id * 10 AS osm_id_hash
         FROM osm_poi_point
         WHERE geometry && bbox
           AND zoom_level BETWEEN 12 AND 13
           AND ((subclass = 'station' AND mapping_key = 'railway')
             OR subclass IN ('halt', 'ferry_terminal'))

         UNION ALL

         -- etldoc: osm_poi_point ->  layer_poi:z14_
         SELECT *,
                osm_id * 10 AS osm_id_hash
         FROM osm_poi_point
         WHERE geometry && bbox
           AND zoom_level >= 14

         UNION ALL

         -- etldoc: osm_poi_polygon ->  layer_poi:z12
         -- etldoc: osm_poi_polygon ->  layer_poi:z13
         -- etldoc: osm_poi_polygon ->  layer_poi:z14_
         SELECT *,
                NULL::integer AS agg_stop,
                CASE
                    WHEN osm_id < 0 THEN -osm_id * 10 + 4
                    ELSE osm_id * 10 + 1
                    END AS osm_id_hash
         FROM osm_poi_polygon
         WHERE zoom_level > 9 AND geometry && bbox AND
           CASE
               WHEN zoom_level >= 14 THEN TRUE
               WHEN zoom_level >= 12 AND
                 ((subclass = 'station' AND mapping_key = 'railway')
                 OR subclass IN ('halt', 'ferry_terminal')) THEN TRUE 
               WHEN zoom_level BETWEEN 10 AND 14 THEN
                 subclass IN ('university', 'college') AND
                 POWER(4,zoom_level)
                 -- Compute percentage of the earth's surface covered by this feature (approximately)
                 -- The constant below is 111,842^2 * 180 * 180, where 111,842 is the length of one degree of latitude at the equator in meters.
                 * area / (405279708033600 * COS(ST_Y(ST_Transform(geometry,4326))*PI()/180))
                 -- Match features that are at least 10% of a tile at this zoom
                 > 0.10
               ELSE FALSE END
     ) AS poi_union
ORDER BY "rank"
$$ LANGUAGE SQL STABLE
                PARALLEL SAFE;
-- TODO: Check if the above can be made STRICT -- i.e. if pixel_width could be NULL

DO $$ BEGIN RAISE NOTICE 'Finished layer poi'; END$$;

DO $$ BEGIN RAISE NOTICE 'Processing layer aerodrome_label'; END$$;

-- Layer aerodrome_label - ./update_aerodrome_label_point.sql

DROP TRIGGER IF EXISTS trigger_flag ON osm_aerodrome_label_point;
DROP TRIGGER IF EXISTS trigger_store ON osm_aerodrome_label_point;
DROP TRIGGER IF EXISTS trigger_refresh ON aerodrome_label.updates;

-- Partial index for zoom 8/9 queries
CREATE INDEX IF NOT EXISTS osm_aerodrome_label_point_type_partial_idx
    ON osm_aerodrome_label_point USING gist (geometry)
    WHERE aerodrome_type = 'international'
      AND iata <> '';

CREATE SCHEMA IF NOT EXISTS aerodrome_label;

CREATE TABLE IF NOT EXISTS aerodrome_label.osm_ids
(
    osm_id bigint PRIMARY KEY
);

-- etldoc: osm_aerodrome_label_point -> osm_aerodrome_label_point
CREATE OR REPLACE FUNCTION update_aerodrome_label_point(full_update boolean) RETURNS void AS
$$
    UPDATE osm_aerodrome_label_point
    SET geometry = ST_Centroid(geometry)
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM aerodrome_label.osm_ids))
        AND ST_GeometryType(geometry) <> 'ST_Point';

    UPDATE osm_aerodrome_label_point
    SET tags = update_tags(tags, geometry)
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM aerodrome_label.osm_ids))
        AND COALESCE(tags->'name:latin', tags->'name:nonlatin', tags->'name_int') IS NULL
        AND tags != update_tags(tags, geometry);

    UPDATE osm_aerodrome_label_point
    SET aerodrome_type=
       CASE
	    WHEN "aerodrome" = 'international'
        OR "aerodrome_type" = 'international'
        THEN 'international'
    WHEN "aerodrome" = 'public'
        OR "aerodrome_type" = 'civil'
        OR "aerodrome_type" LIKE '%public%'
        THEN 'public'
    WHEN "aerodrome" = 'regional'
        OR "aerodrome_type" = 'regional'
        THEN 'regional'
    WHEN "aerodrome" = 'military'
        OR "aerodrome_type" LIKE '%military%'
        OR "military" = 'airfield'
        THEN 'military'
    WHEN "aerodrome" = 'private'
        OR "aerodrome_type" = 'private'
        THEN 'private'
	    ELSE 'other' END
    WHERE (full_update OR osm_id IN (SELECT osm_id FROM aerodrome_label.osm_ids))
    AND aerodrome_type !=
       CASE
	    WHEN "aerodrome" = 'international'
        OR "aerodrome_type" = 'international'
        THEN 'international'
    WHEN "aerodrome" = 'public'
        OR "aerodrome_type" = 'civil'
        OR "aerodrome_type" LIKE '%public%'
        THEN 'public'
    WHEN "aerodrome" = 'regional'
        OR "aerodrome_type" = 'regional'
        THEN 'regional'
    WHEN "aerodrome" = 'military'
        OR "aerodrome_type" LIKE '%military%'
        OR "military" = 'airfield'
        THEN 'military'
    WHEN "aerodrome" = 'private'
        OR "aerodrome_type" = 'private'
        THEN 'private'
	    ELSE 'other' END;
$$ LANGUAGE SQL;

SELECT update_aerodrome_label_point(true);

-- Handle updates

CREATE OR REPLACE FUNCTION aerodrome_label.store() RETURNS trigger AS
$$
BEGIN
    INSERT INTO aerodrome_label.osm_ids VALUES (NEW.osm_id) ON CONFLICT (osm_id) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS aerodrome_label.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION aerodrome_label.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO aerodrome_label.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION aerodrome_label.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh aerodrome_label';

    -- Analyze tracking and source tables before performing update
    ANALYZE aerodrome_label.osm_ids;
    ANALYZE osm_aerodrome_label_point;

    PERFORM update_aerodrome_label_point(false);
    -- noinspection SqlWithoutWhere
    DELETE FROM aerodrome_label.osm_ids;
    -- noinspection SqlWithoutWhere
    DELETE FROM aerodrome_label.updates;

    RAISE LOG 'Refresh aerodrome_label done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store
    AFTER INSERT OR UPDATE
    ON osm_aerodrome_label_point
    FOR EACH ROW
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE aerodrome_label.store();

CREATE TRIGGER trigger_flag
    AFTER INSERT OR UPDATE
    ON osm_aerodrome_label_point
    FOR EACH STATEMENT
    WHEN (pg_trigger_depth() < 1)
EXECUTE PROCEDURE aerodrome_label.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON aerodrome_label.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE aerodrome_label.refresh();

-- Layer aerodrome_label - ./aerodrome_label.sql


-- etldoc: layer_aerodrome_label[shape=record fillcolor=lightpink, style="rounded,filled", label="layer_aerodrome_label | <z8> z8 | <z9> z9 | <z10_> z10+" ] ;

CREATE OR REPLACE FUNCTION layer_aerodrome_label(bbox geometry,
                                                 zoom_level integer)
    RETURNS TABLE
            (
                id       bigint,
                geometry geometry,
                name     text,
                name_en  text,
                name_de  text,
                tags     hstore,
                class    text,
                iata     text,
                icao     text,
                ele      int,
                ele_ft   int
            )
AS
$$
SELECT
    -- etldoc: osm_aerodrome_label_point -> layer_aerodrome_label:z8
    -- etldoc: osm_aerodrome_label_point -> layer_aerodrome_label:z9
    ABS(osm_id) AS id, -- mvt feature IDs can't be negative
    geometry,
    name,
    COALESCE(NULLIF(name_en, ''), name) AS name_en,
    COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
    tags,
    aerodrome_type AS class,
    NULLIF(iata, '') AS iata,
    NULLIF(icao, '') AS icao,
    substring(ele FROM E'^(-?\\d+)(\\D|$)')::int AS ele,
    round(substring(ele FROM E'^(-?\\d+)(\\D|$)')::int * 3.2808399)::int AS ele_ft
FROM osm_aerodrome_label_point
WHERE geometry && bbox
  AND aerodrome_type = 'international'
  AND iata <> ''
  AND zoom_level BETWEEN 8 AND 9

UNION ALL

SELECT
    -- etldoc: osm_aerodrome_label_point -> layer_aerodrome_label:z10_
    ABS(osm_id) AS id, -- mvt feature IDs can't be negative
    geometry,
    name,
    COALESCE(NULLIF(name_en, ''), name) AS name_en,
    COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
    tags,
    aerodrome_type AS class,
    NULLIF(iata, '') AS iata,
    NULLIF(icao, '') AS icao,
    substring(ele FROM E'^(-?\\d+)(\\D|$)')::int AS ele,
    round(substring(ele FROM E'^(-?\\d+)(\\D|$)')::int * 3.2808399)::int AS ele_ft
FROM osm_aerodrome_label_point
WHERE geometry && bbox
  AND zoom_level >= 10;
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;

DO $$ BEGIN RAISE NOTICE 'Finished layer aerodrome_label'; END$$;

-- This SQL code should be executed last

