-- ALTER TABLE A RENAME COLUMN a to b;
-- timescaledbに変換したときにバグが出ないなら、UPDATABLE VIEWが絶対一番早いし、バグもなさそう
CREATE VIEW A_i AS
SELECT
  a_attributes,
  a AS b
FROM
  A;

CREATE OR REPLACE FUNCTION trigger_A_i()
  RETURNS TRIGGER
  AS $$
BEGIN
  IF(TG_OP = 'INSERT') THEN
    INSERT INTO A(a_attributes)
    -- NEW.b instead of NEW.a
      VALUES(NEW.*);
    RETURN NEW;
  ELSIF(TG_OP = 'UPDATE') THEN
    UPDATE
      A
    SET
      a_attributes = NEW.*, -- except column b
      a = NEW.b
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

