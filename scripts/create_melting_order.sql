-- =====================================================
-- Скрипт: Создание заказа-наряда на плавку
-- =====================================================

DO $$
DECLARE
    v_spec_id INTEGER;
    v_grade_id INTEGER;
    v_order_id INTEGER;
BEGIN
    -- Берем первую позицию спецификации (лист 4мм)
    SELECT cs.id, cs.steel_grade_id
    INTO v_spec_id, v_grade_id
    FROM contract_specifications cs
    JOIN contracts c ON cs.contract_id = c.id
    WHERE c.contract_number = 'Д-24/135'
      AND cs.profile_type = 'Лист горячекатаный'
    LIMIT 1;

    -- Создаем заказ на плавку
    INSERT INTO melting_order (
        order_number,
        specification_id,
        steel_grade_id,
        target_weight,
        furnace_number,
        shift,
        master_name,
        status,
        start_time
    ) VALUES (
        'ПЛ-24/02-15', -- Номер плавки
        v_spec_id,
        v_grade_id,
        50.000, -- Цель: 50 тонн (чуть больше спецификации с учетом отходов)
        3, -- Третья печь
        2, -- Вторая смена
        'Смирнов А.П.',
        'Создан',
        '2024-02-15 08:00:00'
    ) RETURNING id INTO v_order_id;

    RAISE NOTICE 'Создан заказ на плавку: ПЛ-24/02-15, ID: %', v_order_id;

    -- Сразу создаем заявку на материалы для этой плавки
    INSERT INTO material_requests (
        request_number,
        melting_order_id,
        requested_by,
        status
    ) VALUES (
        'ЗМ-24/02-15',
        v_order_id,
        'Смирнов А.П.',
        'Новая'
    );

    RAISE NOTICE 'Создана заявка на материалы ЗМ-24/02-15';
END $$;

-- Проверка созданных заказов
SELECT
    mo.order_number,
    sg.grade_name,
    mo.target_weight,
    mo.status,
    mo.master_name,
    cs.profile_type,
    cs.profile_size,
    cs.quantity_ton as required_by_contract
FROM melting_order mo
JOIN steel_grades sg ON mo.steel_grade_id = sg.id
JOIN contract_specifications cs ON mo.specification_id = cs.id
ORDER BY mo.id DESC
LIMIT 5;