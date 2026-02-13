-- =====================================================
-- Скрипт: Списание фактически использованных материалов
-- =====================================================

DO $$
DECLARE
    v_melting_id INTEGER;
    v_material_chugun INTEGER;
    v_material_lom INTEGER;
    v_material_marg INTEGER;
    v_material_sil INTEGER;
    v_material_izv INTEGER;
    v_price_chugun DECIMAL;
    v_price_lom DECIMAL;
    v_price_marg DECIMAL;
    v_price_sil DECIMAL;
    v_price_izv DECIMAL;
    v_total_cost DECIMAL := 0;
BEGIN
    -- Получаем ID плавки
    SELECT id INTO v_melting_id FROM melting_order WHERE order_number = 'ПЛ-24/02-15';

    -- Получаем ID и цены материалов
    SELECT id, price_per_ton INTO v_material_chugun, v_price_chugun FROM materials WHERE material_code = 'RM001';
    SELECT id, price_per_ton INTO v_material_lom, v_price_lom FROM materials WHERE material_code = 'RM002';
    SELECT id, price_per_ton INTO v_material_marg, v_price_marg FROM materials WHERE material_code = 'RM003';
    SELECT id, price_per_ton INTO v_material_sil, v_price_sil FROM materials WHERE material_code = 'RM004';
    SELECT id, price_per_ton INTO v_material_izv, v_price_izv FROM materials WHERE material_code = 'RM005';

    -- Списание чугуна (факт может немного отличаться от плана)
    INSERT INTO write_off_materials (
        write_off_number, melting_order_id, material_id, quantity, unit, price_per_unit, write_off_by
    ) VALUES
        ('СП-24/02-15/1', v_melting_id, v_material_chugun, 15.320, 'т', v_price_chugun, 'Смирнов А.П.'),
        ('СП-24/02-15/2', v_melting_id, v_material_lom, 32.150, 'т', v_price_lom, 'Смирнов А.П.'),
        ('СП-24/02-15/3', v_melting_id, v_material_marg, 0.820, 'т', v_price_marg, 'Смирнов А.П.'),
        ('СП-24/02-15/4', v_melting_id, v_material_sil, 0.380, 'т', v_price_sil, 'Смирнов А.П.'),
        ('СП-24/02-15/5', v_melting_id, v_material_izv, 1.150, 'т', v_price_izv, 'Смирнов А.П.');

    RAISE NOTICE 'Материалы списаны на плавку %', v_melting_id;

    -- Обновляем остатки на складе
    UPDATE materials
    SET stock_balance = stock_balance - 15.320
    WHERE id = v_material_chugun;

    UPDATE materials
    SET stock_balance = stock_balance - 32.150
    WHERE id = v_material_lom;

    -- и так далее для остальных...

    -- Считаем общую стоимость списанных материалов
    SELECT SUM(total_cost) INTO v_total_cost
    FROM write_off_materials
    WHERE melting_order_id = v_melting_id;

    RAISE NOTICE 'Общая стоимость списанных материалов: % руб.', v_total_cost;
END $$;

-- Отчет по списанию
SELECT
    wo.write_off_number,
    m.material_name,
    wo.quantity,
    wo.unit,
    wo.price_per_unit,
    wo.total_cost,
    wo.write_off_date
FROM write_off_materials wo
JOIN materials m ON wo.material_id = m.id
WHERE wo.melting_order_id = (SELECT id FROM melting_order WHERE order_number = 'ПЛ-24/02-15')
ORDER BY wo.id;