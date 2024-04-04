-- ALTER TABLE A ADD COLUMN a a_type;
CREATE TABLE A_i_col(
  time timestamptz NOT NULL,
  a a_type
);

CREATE VIEW A_i AS (
  SELECT
    a_i_attributes -[a],
    NULL AS a
  FROM
    A
  WHERE
    NOT EXISTS (
      SELECT
        *
      FROM
        A_i_col
      WHERE
        A_i_col.time = A.time))
UNION (
  SELECT
    a_i_attributes
  FROM
    A,
    A_i_col
  WHERE
    A.time = A_i_col.time);

CREATE OR REPLACE FUNCTION trigger_A_i()
  RETURNS TRIGGER
  AS $$
BEGIN
  IF(TG_OP = 'INSERT') THEN
    INSERT INTO A(a_attributes)
      VALUES(NEW.a_attributes);
    INSERT INTO A_i_col(time, a)
      VALUES(NEW.time, NEW.a);
    RETURN NEW;
  ELSIF(TG_OP = 'UPDATE') THEN
    UPDATE
      A
    SET
      a_attributes = NEW.a_attributes
    WHERE
      time = OLD.time;
    UPDATE
      A_i_col
    SET
      time = NEW.time,
      a = NEW.a
    WHERE
      time = OLD.time;
    RETURN NEW;
  ELSIF(TG_OP = 'DELETE') THEN
    DELETE FROM A
    WHERE time = OLD.time;
    DELETE FROM A_i_col
    WHERE time = OLD.time;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER trigger_A_i
  INSTEAD OF INSERT OR UPDATE OR DELETE ON A_i
  FOR EACH ROW
  EXECUTE FUNCTION trigger_A_i();

