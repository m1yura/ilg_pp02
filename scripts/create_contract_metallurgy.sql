-- =====================================================
-- Скрипт: Создание договора поставки металлопроката
-- =====================================================

DO $$
DECLARE
    v_customer_id INTEGER;
    v_contract_id INTEGER;
    v_grade_st3_id INTEGER;
    v_grade_09g2s_id INTEGER;
BEGIN
    -- Получаем ID заказчика (которого добавили ранее)
    SELECT id INTO v_customer_id FROM customers WHERE inn = '6652012345' LIMIT 1;

    -- Получаем ID марок стали
    SELECT id INTO v_grade_st3_id FROM steel_grades WHERE grade_name = 'Ст3сп';
    SELECT id INTO v_grade_09g2s_id FROM steel_grades WHERE grade_name = '09Г2С';

    -- 1. Создаем договор
    INSERT INTO contracts (
        contract_number,
        contract_date,
        customer_id,
        contract_sum,
        start_date,
        end_date,
        status
    ) VALUES (
        'Д-24/135',
        '2024-02-01',
        v_customer_id,
        2500000.00,
        '2024-02-01',
        '2024-12-31',
        'Подписан'
    ) RETURNING id INTO v_contract_id;

    RAISE NOTICE 'Создан договор с ID: %', v_contract_id;

    -- 2. Создаем спецификации (позиции заказа)
    INSERT INTO contract_specifications (
        contract_id,
        position_number,
        steel_grade_id,
        profile_type,
        profile_size,
        quantity_ton,
        price_per_ton,
        total_amount,
        delivery_date
    ) VALUES
    (v_contract_id, 1, v_grade_st3_id, 'Лист горячекатаный', '4.0x1500x6000', 45.500, 65000.00, 2957500.00, '2024-03-15'),
    (v_contract_id, 2, v_grade_st3_id, 'Арматура рифленая', 'А400 12мм', 22.300, 68000.00, 1516400.00, '2024-03-20'),
    (v_contract_id, 3, v_grade_09g2s_id, 'Швеллер', '16П', 18.200, 72000.00, 1310400.00, '2024-03-25');

    RAISE NOTICE 'Добавлено 3 позиции спецификации';

    -- Обновляем общую сумму договора
    UPDATE contracts
    SET contract_sum = (
        SELECT SUM(total_amount)
        FROM contract_specifications
        WHERE contract_id = v_contract_id
    )
    WHERE id = v_contract_id;

    RAISE NOTICE 'Общая сумма договора обновлена';
END $$;

-- Проверка созданного договора
SELECT
    c.contract_number,
    c.contract_date,
    c.contract_sum,
    cust.full_name as customer,
    cs.position_number,
    sg.grade_name,
    cs.profile_type,
    cs.profile_size,
    cs.quantity_ton,
    cs.total_amount
FROM contracts c
JOIN customers cust ON c.customer_id = cust.id
LEFT JOIN contract_specifications cs ON c.id = cs.contract_id
LEFT JOIN steel_grades sg ON cs.steel_grade_id = sg.id
WHERE c.contract_number = 'Д-24/135'
ORDER BY cs.position_number;