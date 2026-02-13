-- =====================================================
-- Скрипт: Добавление материалов в заявку (шихтовка)
-- =====================================================

DO $$
DECLARE
    v_request_id INTEGER;
    v_material_chugun INTEGER;
    v_material_lom INTEGER;
    v_material_marg INTEGER;
    v_material_sil INTEGER;
    v_material_izv INTEGER;
BEGIN
    -- Получаем ID материалов
    SELECT id INTO v_material_chugun FROM materials WHERE material_code = 'RM001'; -- Чугун
    SELECT id INTO v_material_lom FROM materials WHERE material_code = 'RM002'; -- Лом
    SELECT id INTO v_material_marg FROM materials WHERE material_code = 'RM003'; -- ФМн
    SELECT id INTO v_material_sil FROM materials WHERE material_code = 'RM004'; -- ФС
    SELECT id INTO v_material_izv FROM materials WHERE material_code = 'RM005'; -- Известь

    -- Получаем ID последней заявки (на плавку ПЛ-24/02-15)
    SELECT id INTO v_request_id
    FROM material_requests
    WHERE request_number = 'ЗМ-24/02-15'
    ORDER BY id DESC LIMIT 1;

    IF v_request_id IS NULL THEN
        RAISE EXCEPTION 'Заявка ЗМ-24/02-15 не найдена!';
    END IF;

    -- Добавляем строки заявки (шихтовка для стали Ст3сп, 50 тонн)
    INSERT INTO material_request_items (
        request_id,
        material_id,
        planned_quantity,
        unit,
        notes
    ) VALUES
    (v_request_id, v_material_chugun, 15.500, 'т', 'Чугун передельный, доля 31%'),
    (v_request_id, v_material_lom, 32.000, 'т', 'Лом стальной, доля 64%'),
    (v_request_id, v_material_marg, 0.850, 'т', 'Ферромарганец, 1.7%'),
    (v_request_id, v_material_sil, 0.400, 'т', 'Ферросилиций, 0.8%'),
    (v_request_id, v_material_izv, 1.200, 'т', 'Известь, флюс');

    RAISE NOTICE 'В заявку % добавлено 5 позиций материалов', v_request_id;

    -- Обновляем статус заявки
    UPDATE material_requests
    SET status = 'Утверждена',
        approved_by = 'Гл. технолог Иванов',
        approved_date = CURRENT_DATE
    WHERE id = v_request_id;

    RAISE NOTICE 'Заявка утверждена';
END $$;

-- Показать детали заявки
SELECT
    mr.request_number,
    m.material_name,
    mri.planned_quantity,
    mri.unit,
    mri.notes
FROM material_requests mr
JOIN material_request_items mri ON mr.id = mri.request_id
JOIN materials m ON mri.material_id = m.id
WHERE mr.request_number = 'ЗМ-24/02-15'
ORDER BY mri.id;