-- =====================================================
-- Скрипт: Создание сертификата качества на плавку
-- =====================================================

DO $$
DECLARE
    v_melting_id INTEGER;
    v_grade_id INTEGER;
BEGIN
    -- Получаем ID плавки, которую мы создали
    SELECT id, steel_grade_id INTO v_melting_id, v_grade_id
    FROM melting_order
    WHERE order_number = 'ПЛ-24/02-15';

    -- Обновляем статус плавки (она уже готова)
    UPDATE melting_order
    SET status = 'На контроле',
        actual_weight = 49.850 -- 50 тонн - угар 150 кг
    WHERE id = v_melting_id;

    -- Создаем сертификат качества
    INSERT INTO quality_certificate (
        certificate_number,
        melting_order_id,
        steel_grade_id,
        c_actual,
        si_actual,
        mn_actual,
        s_actual,
        p_actual,
        cr_actual,
        yield_strength,
        tensile_strength,
        elongation,
        conclusion,
        otk_stamp,
        created_by
    ) VALUES (
        'С-24/02-15/1',
        v_melting_id,
        v_grade_id,
        0.18,   -- C
        0.22,   -- Si
        0.52,   -- Mn
        0.025,  -- S (ниже нормы)
        0.018,  -- P
        0.05,   -- Cr
        255.0,  -- Текучесть
        420.0,  -- Прочность
        28.5,   -- Удлинение
        'Соответствует',
        true,   -- Штамп ОТК
        'Петрова ОТК'
    );

    RAISE NOTICE 'Сертификат С-24/02-15/1 создан для плавки %', v_melting_id;

    -- Меняем статус плавки на Годен
    UPDATE melting_order SET status = 'Годен' WHERE id = v_melting_id;
    RAISE NOTICE 'Статус плавки изменен на Годен';

END $$;

-- Проверка созданного сертификата
SELECT
    qc.certificate_number,
    mo.order_number as melt_number,
    sg.grade_name,
    qc.c_actual,
    qc.si_actual,
    qc.mn_actual,
    qc.conclusion,
    qc.created_at
FROM quality_certificate qc
JOIN melting_order mo ON qc.melting_order_id = mo.id
JOIN steel_grades sg ON qc.steel_grade_id = sg.id
ORDER BY qc.id DESC
LIMIT 5;