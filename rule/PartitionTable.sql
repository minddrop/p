-- PARTITION TABLE T INTO R WITH r_cond, S WITH s_cond
-- a=asterisk, m=minus, p=plus
CREATE TABLE S_p(
  LIKE T INCLUDING CONSTRAINTS
);

CREATE TABLE S_a(
  time timestamptz NOT NULL
);

INSERT INTO S_a(time)
SELECT
  time
FROM
  T
WHERE
  s_cond;

CREATE TABLE S_m(
  time timestamptz NOT NULL
);

INSERT INTO S_m(time)
SELECT
  time
FROM
  T
WHERE
  s_cond
  AND r_cond;

CREATE TABLE R_a(
  time timestamptz NOT NULL
);

INSERT INTO R_a(time)
SELECT
  time
FROM
  T
WHERE
  r_cond;

CREATE TABLE R_m(
  time timestamptz NOT NULL
);

INSERT INTO R_m(time)
SELECT
  time
FROM
  T
WHERE
  s_cond
  AND r_cond;

CREATE VIEW R AS (
  SELECT
    r_attributes
  FROM
    T
  WHERE
    r_cond
    AND NOT EXISTS (
      SELECT
        *
      FROM
        R_m
      WHERE
        R_m.time = T.time)
    UNION (
      SELECT
        r_attributes
      FROM
        T,
        R_a
      WHERE
        T.time = R_a.time));

CREATE VIEW S AS (
  SELECT
    s_attributes
  FROM
    T
  WHERE
    s_cond
    AND NOT EXISTS (
      SELECT
        *
      FROM
        S_m
      WHERE
        S_m.time = T.time)
      AND NOT EXISTS (
        SELECT
          *
        FROM
          S_p
        WHERE
          S_m.time = T.time))
  UNION (
    SELECT
      *
    FROM
      S_p)
UNION (
  SELECT
    s_attributes
  FROM
    T,
    S_a
  WHERE
    T.time = S_a.time
    AND NOT EXISTS (
      SELECT
        *
      FROM
        S_p
      WHERE
        S_p.time = T.time
        AND S_p.time = S_a.time));

CREATE OR REPLACE FUNCTION trigger_R()
  RETURNS TRIGGER
  AS $$
BEGIN
  IF(TG_OP = 'INSERT') THEN
    INSERT INTO T(*)
      VALUES(NEW.*);
    IF(NOT NEW.r_cond) THEN
      INSERT INTO R_a(time)
        VALUES(NEW.time);
    END IF;
    RETURN NEW;
  ELSIF(TG_OP = 'UPDATE') THEN
    IF(EXISTS(
      SELECT
        1
      FROM
        S_m
      WHERE
        time = OLD.time
      LIMIT 1)) THEN
      INSERT INTO S_p(*)
        VALUES(OLD.*);
    END IF;
    UPDATE
      T
    SET
      * = NEW.*
    WHERE
      time = OLD.time;
    IF(NOT NEW.r_cond) THEN
      INSERT INTO R_a(time)
        VALUES(NEW.time)
      ON CONFLICT(time)
        DO UPDATE SET
          time = NEW.time;
    END IF;
    RETURN NEW;
  ELSIF(TG_OP = 'DELETE') THEN
    IF(EXISTS(
      SELECT
        1
      FROM
        S_m
      WHERE
        time = OLD.time
      LIMIT 1)) THEN
      DELETE FROM S_m
      WHERE time = OLD.time;
      INSERT INTO S_p(*)
        VALUES(OLD.*);
    END IF;
    DELETE FROM T
    WHERE time = OLD.time;
    IF(NOT OLD.r_cond) THEN
      DELETE FROM R_a
      WHERE time = OLD.time
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_S()
  RETURNS TRIGGER
  AS $$
BEGIN
  IF(TG_OP = 'INSERT') THEN
    INSERT INTO T(*)
      VALUES(NEW.*);
    IF(NOT NEW.s_cond) THEN
      INSERT INTO S_a(time)
        VALUES(NEW.time);
    END IF;
    RETURN NEW;
  ELSIF(TG_OP = 'UPDATE') THEN
    IF(EXISTS(
      SELECT
        1
      FROM
        R_m
      WHERE
        time = OLD.time
      LIMIT 1)) THEN
      UPDATE
        S_p
      SET
        *= NEW.*
      WHERE
        time = OLD.time;
    END IF;
    IF(OLD.time NOT IN(
      SELECT
        time
      FROM
        R)) THEN
      UPDATE
        T
      SET
        * = NEW.*
      WHERE
        time = OLD.time;
    END IF;
    IF(NOT NEW.s_cond) THEN
      INSERT INTO S_a(time)
        VALUES(NEW.time);
      -- ON CONFLICT(time)
      --   DO UPDATE SET
      --     time = NEW.time;
    END IF;
    RETURN NEW;
  ELSIF(TG_OP = 'DELETE') THEN
    IF(EXISTS(
      SELECT
        1
      FROM
        R_m
      WHERE
        time = OLD.time
      LIMIT 1)) THEN
      DELETE FROM R_m
      WHERE time = OLD.time;
    END IF;
    IF(EXISTS(
      SELECT
        1
      FROM
        S_p
      WHERE
        time = OLD.time
      LIMIT 1)) THEN
      DELETE FROM S_p
      WHERE time = OLD.time;
    END IF;
    IF(EXISTS(
      SELECT
        1
      FROM
        R_m
      WHERE
        time = OLD.time
      LIMIT 1)) THEN
      DELETE FROM R_m
      WHERE time = OLD.time;
    END IF;
    IF(NOT EXISTS(
      SELECT
        1
      FROM
        R
      WHERE
        time = OLD.time
      LIMIT 1)) THEN
      DELETE FROM T
      WHERE time = OLD.time;
    END IF;
    IF(NOT OLD.s_cond) THEN
      DELETE FROM S_a
      WHERE time = OLD.time
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER trigger_R
  INSTEAD OF INSERT OR UPDATE OR DELETE ON R
  FOR EACH ROW
  EXECUTE FUNCTION trigger_R();

CREATE TRIGGER trigger_S
  INSTEAD OF INSERT OR UPDATE OR DELETE ON S
  FOR EACH ROW
  EXECUTE FUNCTION trigger_S();

