-- ALTER TABLE A RENAME TO B;
-- 多分 updatable viewとして単にview作るだけで行けると思う -> hypertableにしたあとは未確認 ()
CREATE VIEW B AS
SELECT
  *
FROM
  A;

CREATE OR REPLACE FUNCTION trigger_B()
  RETURNS TRIGGER
  AS $$
BEGIN
  IF(TG_OP = 'INSERT') THEN
    INSERT INTO A(*)
      VALUES(NEW.*);
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

CREATE TRIGGER trigger_B
  INSTEAD OF INSERT OR UPDATE OR DELETE ON B
  FOR EACH ROW
  EXECUTE FUNCTION trigger_B();

