-- ALTER TABLE A DROP COLUMN a;
CREATE VIEW A_i AS
SELECT
  a_attributes -- except a
FROM
  A;

CREATE OR REPLACE FUNCTION trigger_A_i()
  RETURNS TRIGGER
  AS $$
BEGIN
  IF(TG_OP = 'INSERT') THEN
    INSERT INTO A(a_attributes)
      VALUES(NEW.a_attributes);
    RETURN NEW;
  ELSIF(TG_OP = 'UPDATE') THEN
    UPDATE
      A
    SET
      * = NEW.*
    WHERE
      time = OLD.time;
    RETURN NEW;
  ELSIF(TG_OP = 'DELETE') THEN
    DELETE FROM A
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

