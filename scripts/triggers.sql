-- Проверка принадлежности имущества человеку
-- При добавлении пункта завещания проверяем, что имущество принадлежит завещателю
CREATE OR REPLACE FUNCTION chk_affiliation_of_property()
RETURNS TRIGGER AS $$
DECLARE
testator_id integer;
property_owner integer;
BEGIN
  -- Получаем ID завещателя из таблицы wills
  SELECT person_id INTO testator_id
  FROM wills
  WHERE id = NEW.will_id;

  -- Получаем ID владельца имущества
  SELECT person_id INTO property_owner
  FROM properties
  WHERE id = NEW.property_id;

  -- Если владелец имущества не совпадает с завещателем – ошибка
  IF (testator_id IS NULL OR property_owner IS NULL OR testator_id <> property_owner) THEN
    RAISE EXCEPTION 'Имущество с id = % не принадлежит завещателю (will_id = %)', NEW.property_id, NEW.will_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tr_affiliation
BEFORE INSERT ON will_entries
FOR EACH ROW EXECUTE PROCEDURE chk_affiliation_of_property();

-- Имеет ли смысл завещание, если удалили имущество
-- После удаления пункта завещания, если у завещания не осталось ни одного пункта – удаляем само завещание
CREATE OR REPLACE FUNCTION chk_meaninglessness_of_will()
RETURNS TRIGGER AS $$
BEGIN
  -- Если после удаления для данного will_id не осталось записей в will_entries
  IF NOT EXISTS (SELECT 1 FROM will_entries WHERE will_id = OLD.will_id) THEN
    DELETE FROM wills WHERE id = OLD.will_id;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tr_meaninglessness
AFTER DELETE ON will_entries
FOR EACH ROW EXECUTE PROCEDURE chk_meaninglessness_of_will();
