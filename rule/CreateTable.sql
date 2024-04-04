-- CREATE TABLE A (time, a_attributes)
CREATE TABLE A_d(
  time timestamptz NOT NULL,
  a_attributes
);

CREATE VIEW A AS
SELECT
  *
FROM
  A_d;

CREATE OR REPLACE FUNCTION trigger_A()
  RETURNS TRIGGER
  AS $$
BEGIN
  IF(TG_OP = 'INSERT') THEN
    INSERT INTO A_d(*)
      VALUES(NEW.*);
    RETURN NEW;
  ELSIF(TG_OP = 'UPDATE') THEN
    UPDATE
      A_d
    SET
      *= NEW.*
    WHERE
      time = OLD.time;
    RETURN NEW;
  ELSIF(TG_OP = 'DELETE') THEN
    DELETE FROM A_d
    WHERE time = OLD.time;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER trigger_A
  INSTEAD OF INSERT OR UPDATE OR DELETE ON A
  FOR EACH ROW
  EXECUTE FUNCTION trigger_A();

